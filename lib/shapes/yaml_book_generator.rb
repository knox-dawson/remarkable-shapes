# frozen_string_literal: true

require "fileutils"
require "pathname"
require "psych"
require "shellwords"

require_relative "../io/rm_page"
require_relative "../io/rmdoc_writer"
require_relative "yaml_shape_renderer"

module Remarkable
  # Builds multipage .rmdoc outputs from YAML page lists or item-driven templates.
  class YamlBookGenerator
    DEFAULT_PREFIX = "book"
    DEFAULT_RMCAT_COMMAND = "rmcat"

    class << self
      def parse_layout(layout)
        match = layout.to_s.match(/\A(\d+)x(\d+)\z/i)
        raise ArgumentError, "Layout must look like 3x5" unless match

        rows = match[1].to_i
        cols = match[2].to_i
        raise ArgumentError, "Layout dimensions must be positive" unless rows.positive? && cols.positive?

        [rows, cols]
      end

      def generate_from_yaml_list(list_path:, output_dir:, final_output:, concat_script_path: nil,
                                  rmcat_command: DEFAULT_RMCAT_COMMAND, run_concat: true)
        yaml_paths = load_yaml_list(list_path)
        generate_book_from_yaml_paths(
          yaml_paths:,
          output_dir:,
          final_output:,
          concat_script_path:,
          rmcat_command:,
          run_concat:
        )
      end

      def generate_from_template(template_yaml:, output_dir:, final_output:, cover_yaml: nil, items_yaml: nil,
                                 image_dir: nil, prefix: nil, concat_script_path: nil,
                                 rmcat_command: DEFAULT_RMCAT_COMMAND, run_concat: true)
        raise ArgumentError, "template_yaml is required" if template_yaml.nil? || template_yaml.strip.empty?
        raise ArgumentError, "provide either items_yaml or image_dir" if blank?(items_yaml) && blank?(image_dir)
        raise ArgumentError, "provide only one of items_yaml or image_dir" if present?(items_yaml) && present?(image_dir)

        template_path = File.expand_path(template_yaml)
        template_config = load_yaml_hash(template_path)
        items = items_yaml ? load_items(items_yaml) : load_items_from_image_dir(image_dir)
        prefix ||= File.basename(final_output, ".rmdoc")
        prefix = DEFAULT_PREFIX if prefix.nil? || prefix.strip.empty?

        yaml_dir = File.join(output_dir, "yaml")
        FileUtils.mkdir_p(yaml_dir)
        generated_yaml_paths = build_template_pages(template_config, items, template_path:, output_dir: yaml_dir, prefix:)

        yaml_paths = []
        yaml_paths << File.expand_path(cover_yaml) if present?(cover_yaml)
        yaml_paths.concat(generated_yaml_paths)

        generate_book_from_yaml_paths(
          yaml_paths:,
          output_dir:,
          final_output:,
          concat_script_path:,
          rmcat_command:,
          run_concat:
        ).merge(generated_yaml_paths:)
      end

      def generate_book_from_yaml_paths(yaml_paths:, output_dir:, final_output:, concat_script_path: nil,
                                        rmcat_command: DEFAULT_RMCAT_COMMAND, run_concat: true)
        raise ArgumentError, "yaml_paths must not be empty" if yaml_paths.nil? || yaml_paths.empty?

        rmdoc_dir = File.join(output_dir, "rmdoc")
        FileUtils.mkdir_p(rmdoc_dir)
        rmdoc_paths = yaml_paths.each_with_index.map do |yaml_path, index|
          basename = File.basename(yaml_path, File.extname(yaml_path))
          target = File.join(rmdoc_dir, format("%02d-%s.rmdoc", index, basename))
          render_yaml_to_rmdoc(yaml_path, target)
          target
        end

        final_output = File.expand_path(final_output)
        concat_script_path ||= File.join(output_dir, "#{File.basename(final_output, ".rmdoc")}-rmcat.sh")
        concat_script_path = File.expand_path(concat_script_path)
        write_concat_script(concat_script_path, final_output:, rmdoc_paths:, rmcat_command:)
        concat_ran = run_concat ? run_concat_script(concat_script_path, rmcat_command:) : false

        {
          yaml_paths: yaml_paths.map { |path| File.expand_path(path) },
          rmdoc_paths:,
          final_output:,
          concat_script_path:,
          concat_ran:
        }
      end

      def load_yaml_list(list_path)
        path = File.expand_path(list_path)
        base_dir = File.dirname(path)
        data = safe_load_yaml(path)
        pages = data.is_a?(Hash) ? stringify_keys(data).fetch("pages") { raise ArgumentError, "yaml list must contain pages" } : data
        raise ArgumentError, "yaml list pages must be an array" unless pages.is_a?(Array)

        pages.map do |entry|
          value = entry.is_a?(Hash) ? stringify_keys(entry).fetch("path") { raise ArgumentError, "yaml list entries must contain path" } : entry
          resolved = File.expand_path(value.to_s, base_dir)
          raise ArgumentError, "yaml page not found: #{value}" unless File.file?(resolved)

          resolved
        end
      end

      def load_items(items_path)
        path = File.expand_path(items_path)
        base_dir = File.dirname(path)
        data = safe_load_yaml(path)
        items = data.is_a?(Hash) ? stringify_keys(data).fetch("items") { raise ArgumentError, "items file must contain items" } : data
        raise ArgumentError, "items must be an array" unless items.is_a?(Array)

        items.map { |entry| normalize_item_entry(entry, base_dir) }
      end

      def load_items_from_image_dir(image_dir)
        dir = File.expand_path(image_dir)
        image_paths = Dir[File.join(dir, "*.png")].sort
        raise ArgumentError, "No PNG files found in #{dir}" if image_paths.empty?

        image_paths.map do |image_path|
          {
            "image" => image_path,
            "label" => File.basename(image_path, File.extname(image_path))
          }
        end
      end

      def build_template_pages(template_config, items, template_path:, output_dir:, prefix:)
        config = stringify_keys(template_config)
        canvas = config.fetch("canvas") { raise ArgumentError, "template yaml must contain canvas" }
        static_objects = config.fetch("objects", [])
        template_objects = config.fetch("template") { raise ArgumentError, "template yaml must contain template" }
        raise ArgumentError, "template must be an array" unless template_objects.is_a?(Array)
        per_page = template_page_capacity(canvas)

        template_dir = File.dirname(File.expand_path(template_path))
        items.each_slice(per_page).each_with_index.map do |page_items, page_index|
          page_objects = deep_copy(static_objects)
          page_items.each_with_index do |item, item_index|
            context = build_template_context(
              item:,
              page_number: page_index + 1,
              item_number: (page_index * per_page) + item_index + 1,
              cell_number: item_index + 1
            )
            template_objects.each do |template_object|
              page_objects << instantiate_template_object(template_object, context, output_dir, template_dir)
            end
          end

          page_config = {
            "canvas" => deep_copy(canvas),
            "objects" => page_objects
          }
          page_path = File.join(output_dir, format("%<prefix>s-%<page>02d.yml", prefix:, page: page_index + 1))
          File.write(page_path, Psych.dump(page_config))
          page_path
        end
      end

      def build_template_context(item:, page_number:, item_number:, cell_number:)
        stringify_keys(item).merge(
          "page_number" => page_number,
          "item_number" => item_number,
          "cell" => cell_number,
          "auto_cell" => cell_number
        )
      end

      def template_page_capacity(canvas)
        grid = stringify_keys(canvas.fetch("grid") { raise ArgumentError, "template canvas must contain grid" })
        rows, cols =
          if grid["size"]
            parse_layout(grid["size"])
          else
            [Integer(grid.fetch("rows")), Integer(grid.fetch("cols"))]
          end
        raise ArgumentError, "template grid must have positive rows and cols" unless rows.positive? && cols.positive?

        rows * cols
      rescue KeyError
        raise ArgumentError, "template grid must define size or rows and cols"
      end

      def instantiate_template_object(value, context, output_dir, template_dir, key = nil)
        case value
        when Hash
          stringify_keys(value).each_with_object({}) do |(child_key, child_value), result|
            result[child_key] = instantiate_template_object(child_value, context, output_dir, template_dir, child_key)
          end
        when Array
          value.map { |item| instantiate_template_object(item, context, output_dir, template_dir, key) }
        when String
          instantiate_template_string(value, context, output_dir, template_dir, key)
        else
          value
        end
      end

      def instantiate_template_string(value, context, output_dir, template_dir, key)
        return context.fetch("cell") if value == "auto" && key == "cell"

        exact = value.match(/\A\{\{([A-Za-z0-9_]+)\}\}\z/)
        if exact
          resolved = context.fetch(exact[1]) { raise ArgumentError, "unknown template placeholder: #{exact[1]}" }
          return relativize_path(resolved, output_dir, template_dir) if key == "path"

          return resolved
        end

        value.gsub(/\{\{([A-Za-z0-9_]+)\}\}/) do
          context.fetch(Regexp.last_match(1)) { raise ArgumentError, "unknown template placeholder: #{Regexp.last_match(1)}" }.to_s
        end
      end

      def relativize_path(value, output_dir, template_dir)
        path = File.expand_path(value.to_s, template_dir)
        Pathname.new(path).relative_path_from(Pathname.new(output_dir)).to_s
      end

      def normalize_item_entry(entry, base_dir)
        case entry
        when String
          entry_hash = { "image" => entry }
        when Hash
          entry_hash = stringify_keys(entry)
        else
          raise ArgumentError, "each item must be a string or hash"
        end

        image_value = entry_hash.fetch("image") { raise ArgumentError, "each item must include image" }
        image_path = File.expand_path(image_value.to_s, base_dir)
        raise ArgumentError, "image not found: #{image_value}" unless File.file?(image_path)

        entry_hash["image"] = image_path
        entry_hash["label"] ||= derive_item_label(image_path, entry_hash)
        entry_hash
      end

      def derive_item_label(image_path, entry)
        source = entry.fetch("label_source", image_path).to_s
        if entry["match"]
          regex = Regexp.new(entry["match"])
          if entry["replace"]
            replaced = source.sub(regex, entry["replace"].to_s)
            return replaced unless replaced == source
          elsif (matched = source.match(regex))
            return matched.captures.empty? ? matched[0] : matched.captures.join(" ")
          end
        end

        File.basename(image_path, File.extname(image_path))
      end

      def render_yaml_to_rmdoc(yaml_path, output_path)
        config = Remarkable::YamlShapeRenderer.load_file_config(yaml_path)
        layout = Remarkable::YamlShapeRenderer.resolve_canvas_layout(config.fetch("canvas", {}))
        page = Remarkable::RmPage.new(page_width: layout[:physical_width], page_height: layout[:physical_height])
        Remarkable::YamlShapeRenderer.render(page, config, base_dir: File.dirname(File.expand_path(yaml_path)))
        Remarkable::RmdocWriter.write(
          output_path,
          page.to_rm_bytes,
          page_width: page.page_width,
          page_height: page.page_height
        )
        output_path
      end

      def write_concat_script(path, final_output:, rmdoc_paths:, rmcat_command:)
        command = Shellwords.join([rmcat_command, "-o", final_output, *rmdoc_paths])
        File.write(path, "#!/usr/bin/env bash\nset -euo pipefail\n#{command}\n")
        FileUtils.chmod(0o755, path)
        path
      end

      def run_concat_script(script_path, rmcat_command:)
        return false unless command_available?(rmcat_command)

        system(script_path)
      end

      def command_available?(command)
        return File.executable?(command) if command.include?(File::SEPARATOR)

        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
          candidate = File.join(dir, command)
          File.file?(candidate) && File.executable?(candidate)
        end
      end

      def load_yaml_hash(path)
        data = safe_load_yaml(path)
        raise ArgumentError, "yaml file must contain a hash" unless data.is_a?(Hash)

        stringify_keys(data)
      end

      def safe_load_yaml(path)
        Psych.safe_load(File.read(path), permitted_classes: [], aliases: false) || {}
      end

      def stringify_keys(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, inner), result|
            result[key.to_s] = stringify_keys(inner)
          end
        when Array
          value.map { |item| stringify_keys(item) }
        else
          value
        end
      end

      def deep_copy(value)
        Marshal.load(Marshal.dump(value))
      end

      def blank?(value)
        value.nil? || value.to_s.strip.empty?
      end

      def present?(value)
        !blank?(value)
      end
    end
  end
end

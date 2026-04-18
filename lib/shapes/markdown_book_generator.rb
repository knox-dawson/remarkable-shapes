# frozen_string_literal: true

require "fileutils"
require "kramdown"
require "pathname"
require "psych"

require_relative "line_font"
require_relative "yaml_book_generator"

module Remarkable
  # Builds multipage .rmdoc books from markdown by generating intermediate YAML pages.
  class MarkdownBookGenerator
    DEFAULT_CONFIG_PATH = File.expand_path("../../config/markdown_defaults.yml", __dir__)
    DEFAULT_PREFIX = "markdown"

    DEFAULT_CONFIG = {
      "page" => {
        "tablet" => "rm2",
        "left" => 130.0,
        "top" => 130.0,
        "right" => 1270.0,
        "bottom" => 1740.0,
        "padding" => 40.0,
        "show_box" => false,
        "box" => {
          "stroke_width" => 4,
          "color" => "black"
        }
      },
      "styles" => {
        "body" => {
          "font" => "line_font",
          "size" => 28,
          "stroke_width" => 2,
          "line_spacing" => 1.25,
          "color" => "black"
        },
        "heading_1" => {
          "font" => "line_font",
          "size" => 56,
          "stroke_width" => 3,
          "line_spacing" => 1.1,
          "color" => "black"
        },
        "heading_2" => {
          "font" => "line_font",
          "size" => 46,
          "stroke_width" => 3,
          "line_spacing" => 1.15,
          "color" => "black"
        },
        "heading_3" => {
          "font" => "line_font",
          "size" => 40,
          "stroke_width" => 3,
          "line_spacing" => 1.15,
          "color" => "black"
        },
        "heading_4" => {
          "font" => "line_font",
          "size" => 34,
          "stroke_width" => 2.5,
          "line_spacing" => 1.2,
          "color" => "black"
        },
        "heading_5" => {
          "font" => "line_font",
          "size" => 30,
          "stroke_width" => 2.5,
          "line_spacing" => 1.2,
          "color" => "black"
        },
        "heading_6" => {
          "font" => "line_font",
          "size" => 28,
          "stroke_width" => 2,
          "line_spacing" => 1.2,
          "color" => "black"
        },
        "blockquote" => {
          "font" => "line_font_italic",
          "size" => 28,
          "stroke_width" => 2,
          "line_spacing" => 1.25,
          "color" => "grey"
        },
        "code" => {
          "font" => "line_font_mono",
          "size" => 24,
          "stroke_width" => 2,
          "line_spacing" => 1.2,
          "color" => "black"
        }
      },
      "elements" => {
        "paragraph" => {
          "style" => "body",
          "space_before" => 0,
          "space_after" => 28,
          "indent" => 0,
          "wrap" => true
        },
        "heading_1" => {
          "style" => "heading_1",
          "space_before" => 0,
          "space_after" => 34,
          "indent" => 0,
          "wrap" => true
        },
        "heading_2" => {
          "style" => "heading_2",
          "space_before" => 12,
          "space_after" => 28,
          "indent" => 0,
          "wrap" => true
        },
        "heading_3" => {
          "style" => "heading_3",
          "space_before" => 10,
          "space_after" => 24,
          "indent" => 0,
          "wrap" => true
        },
        "heading_4" => {
          "style" => "heading_4",
          "space_before" => 8,
          "space_after" => 20,
          "indent" => 0,
          "wrap" => true
        },
        "heading_5" => {
          "style" => "heading_5",
          "space_before" => 8,
          "space_after" => 18,
          "indent" => 0,
          "wrap" => true
        },
        "heading_6" => {
          "style" => "heading_6",
          "space_before" => 8,
          "space_after" => 16,
          "indent" => 0,
          "wrap" => true
        },
        "unordered_list_item" => {
          "style" => "body",
          "space_before" => 0,
          "space_after" => 10,
          "indent" => 28,
          "wrap" => true,
          "bullet" => "- "
        },
        "ordered_list_item" => {
          "style" => "body",
          "space_before" => 0,
          "space_after" => 10,
          "indent" => 28,
          "wrap" => true
        },
        "blockquote" => {
          "style" => "blockquote",
          "space_before" => 0,
          "space_after" => 22,
          "indent" => 36,
          "wrap" => true,
          "prefix" => "> "
        },
        "code_block" => {
          "style" => "code",
          "space_before" => 10,
          "space_after" => 24,
          "indent" => 24,
          "wrap" => true
        },
        "thematic_break" => {
          "space_before" => 14,
          "space_after" => 18,
          "stroke_width" => 3,
          "color" => "black"
        }
      }
    }.freeze

    TEXT_STYLE_KEYS = %w[
      font size stroke_width line_spacing color rgba brush style mono align valign
    ].freeze

    LINE_STYLE_KEYS = %w[
      stroke_width color rgba brush
    ].freeze

    class << self
      def generate_from_markdown(markdown_path:, output_dir:, final_output:, config_path: nil, prefix: nil,
                                 concat_script_path: nil,
                                 rmcat_command: YamlBookGenerator::DEFAULT_RMCAT_COMMAND, run_concat: true)
        markdown_path = File.expand_path(markdown_path)
        output_dir = File.expand_path(output_dir)
        final_output = File.expand_path(final_output)
        concat_script_path = concat_script_path ? File.expand_path(concat_script_path) : nil
        prefix ||= File.basename(final_output, ".rmdoc")
        prefix = DEFAULT_PREFIX if blank?(prefix)

        config = load_config(config_path)
        yaml_dir = File.join(output_dir, "yaml")
        FileUtils.mkdir_p(yaml_dir)

        generated_yaml_paths = build_markdown_pages(
          File.read(markdown_path),
          markdown_path:,
          output_dir: yaml_dir,
          prefix:,
          config:
        )

        YamlBookGenerator.generate_book_from_yaml_paths(
          yaml_paths: generated_yaml_paths,
          output_dir:,
          final_output:,
          concat_script_path:,
          rmcat_command:,
          run_concat:
        ).merge(generated_yaml_paths:, config:)
      end

      def write_default_config(path)
        target = File.expand_path(path)
        FileUtils.mkdir_p(File.dirname(target))
        File.write(target, Psych.dump(deep_copy(DEFAULT_CONFIG)))
        target
      end

      def load_config(config_path = nil)
        config = deep_copy(DEFAULT_CONFIG)
        merge_config_file!(config, DEFAULT_CONFIG_PATH)
        merge_config_file!(config, config_path) unless blank?(config_path)
        config
      end

      def build_markdown_pages(markdown, markdown_path:, output_dir:, prefix:, config:)
        blocks = markdown_blocks(markdown)
        page_spec = resolved_page_spec(config.fetch("page", {}))
        pages = paginate_blocks(blocks, config:, page_spec:)
        base_dir = File.dirname(File.expand_path(markdown_path))

        pages.each_with_index.map do |page_objects, index|
          page_config = {
            "canvas" => { "tablet" => page_spec.fetch("tablet") },
            "objects" => page_objects
          }
          path = File.join(output_dir, format("%<prefix>s-%<page>02d.yml", prefix:, page: index + 1))
          File.write(path, Psych.dump(relativize_paths(page_config, File.dirname(path), base_dir)))
          path
        end
      end

      def markdown_blocks(markdown)
        document = Kramdown::Document.new(normalize_markdown(markdown.to_s))
        blocks = []
        append_blocks(document.root.children, blocks)
        blocks
      end

      def normalize_markdown(markdown)
        lines = markdown.lines
        normalized = []
        in_fenced_code = false

        lines.each do |line|
          if line.match?(/\A```/)
            in_fenced_code = !in_fenced_code
            normalized << "\n"
            next
          end

          if in_fenced_code
            normalized << "    #{line}"
          else
            normalized << line
          end
        end

        normalized << "\n" if in_fenced_code
        normalized.join
      end

      def append_blocks(nodes, blocks, list_depth: 0, quote_depth: 0)
        nodes.each do |node|
          case node.type
          when :header
            text = plain_text(node).strip
            next if text.empty?

            blocks << text_block("heading_#{node.options[:level]}", text, extra_indent: quote_depth * 24)
          when :p
            text = plain_text(node).strip
            next if text.empty?

            key = quote_depth.positive? ? "blockquote" : "paragraph"
            prefix = quote_depth.positive? ? ("> " * quote_depth) : nil
            blocks << text_block(key, text, prefix:, extra_indent: quote_depth * 24)
          when :blockquote
            append_blocks(node.children, blocks, list_depth:, quote_depth: quote_depth + 1)
          when :ul
            append_list_blocks(node.children, blocks, ordered: false, list_depth:, quote_depth:)
          when :ol
            append_list_blocks(node.children, blocks, ordered: true, list_depth:, quote_depth:)
          when :codeblock
            text = node.value.to_s.rstrip
            next if text.empty?

            blocks << text_block("code_block", text, extra_indent: quote_depth * 24)
          when :hr
            blocks << { "kind" => "line", "element" => "thematic_break" }
          else
            append_blocks(node.children, blocks, list_depth:, quote_depth:) unless node.children.empty?
          end
        end
      end

      def append_list_blocks(items, blocks, ordered:, list_depth:, quote_depth:)
        items.each_with_index do |item, index|
          text_chunks = []
          nested_lists = []

          item.children.each do |child|
            if %i[ul ol].include?(child.type)
              nested_lists << child
            else
              chunk = plain_text(child).strip
              text_chunks << chunk unless chunk.empty?
            end
          end

          unless text_chunks.empty?
            key = ordered ? "ordered_list_item" : "unordered_list_item"
            prefix = ordered ? "#{index + 1}. " : nil
            blocks << text_block(
              key,
              text_chunks.join("\n\n"),
              prefix:,
              extra_indent: (list_depth * 32) + (quote_depth * 24)
            )
          end

          nested_lists.each do |child_list|
            append_blocks([child_list], blocks, list_depth: list_depth + 1, quote_depth:)
          end
        end
      end

      def text_block(element, text, prefix: nil, extra_indent: 0)
        {
          "kind" => "text",
          "element" => element,
          "text" => text,
          "prefix" => prefix,
          "extra_indent" => extra_indent
        }
      end

      def paginate_blocks(blocks, config:, page_spec:)
        pages = []
        current_objects = new_page_objects(config, page_spec)
        cursor_y = page_spec.fetch("content_top")

        blocks.each do |block|
          case block.fetch("kind")
          when "text"
            current_objects, cursor_y, new_pages =
              place_text_block(block, current_objects:, cursor_y:, config:, page_spec:)
            pages.concat(new_pages)
          when "line"
            current_objects, cursor_y, new_pages =
              place_line_block(block, current_objects:, cursor_y:, config:, page_spec:)
            pages.concat(new_pages)
          end
        end

        pages << current_objects unless current_objects.empty?
        pages
      end

      def place_text_block(block, current_objects:, cursor_y:, config:, page_spec:)
        pages = []
        element = element_config(config, block.fetch("element"))
        style = style_config(config, element.fetch("style", "body"))
        indent = element.fetch("indent", 0).to_f + block.fetch("extra_indent", 0).to_f
        width = page_spec.fetch("content_width") - indent
        raise ArgumentError, "text block width must be positive" unless width.positive?

        prefix = block.fetch("prefix", nil)
        prefix = element["prefix"] if prefix.nil? && element.key?("prefix")
        prefix = element["bullet"] if prefix.nil? && element.key?("bullet")
        raw_text = prefix.to_s + block.fetch("text")
        wrap = truthy?(element.fetch("wrap", true))
        lines = wrap ? wrap_text(raw_text, width, style) : raw_text.split("\n", -1)
        lines = [""] if lines.empty?
        line_height = style.fetch("line_spacing", 1.25).to_f * style.fetch("size", 28).to_f
        space_before = element.fetch("space_before", 0).to_f
        space_after = element.fetch("space_after", 0).to_f
        first_chunk = true

        until lines.empty?
          needed_before = first_chunk ? space_before : 0.0
          available_height = page_spec.fetch("content_bottom") - (cursor_y + needed_before)
          lines_fit = [(available_height / line_height).floor, 0].max

          if lines_fit.zero?
            pages << current_objects unless current_objects.empty?
            current_objects = new_page_objects(config, page_spec)
            cursor_y = page_spec.fetch("content_top")
            first_chunk = false
            next
          end

          chunk_size = [lines_fit, lines.length].min
          chunk = lines.shift(chunk_size)
          cursor_y += needed_before
          current_objects << build_text_object(
            text: chunk.join("\n"),
            x: page_spec.fetch("content_left") + indent,
            y: cursor_y,
            width: width,
            height: chunk.length * line_height,
            style:
          )
          cursor_y += chunk.length * line_height

          if lines.empty?
            cursor_y += space_after
          else
            pages << current_objects unless current_objects.empty?
            current_objects = new_page_objects(config, page_spec)
            cursor_y = page_spec.fetch("content_top")
          end

          first_chunk = false
        end

        [current_objects, cursor_y, pages]
      end

      def place_line_block(block, current_objects:, cursor_y:, config:, page_spec:)
        pages = []
        element = element_config(config, block.fetch("element"))
        stroke_width = element.fetch("stroke_width", 2).to_f
        space_before = element.fetch("space_before", 0).to_f
        space_after = element.fetch("space_after", 0).to_f
        total_height = space_before + stroke_width + space_after

        if cursor_y + total_height > page_spec.fetch("content_bottom") && !current_objects.empty?
          pages << current_objects
          current_objects = new_page_objects(config, page_spec)
          cursor_y = page_spec.fetch("content_top")
        end

        cursor_y += space_before
        y = cursor_y + (stroke_width / 2.0)
        current_objects << build_line_object(
          x1: page_spec.fetch("content_left"),
          y1: y,
          x2: page_spec.fetch("content_right"),
          y2: y,
          element:
        )
        cursor_y += stroke_width + space_after

        [current_objects, cursor_y, pages]
      end

      def build_text_object(text:, x:, y:, width:, height:, style:)
        {
          "type" => "text",
          "x" => round_number(x),
          "y" => round_number(y),
          "width" => round_number(width),
          "height" => round_number(height),
          "text" => text,
          "wrap" => false,
          "align" => "left",
          "valign" => "top"
        }.merge(filter_keys(style, TEXT_STYLE_KEYS))
      end

      def build_line_object(x1:, y1:, x2:, y2:, element:)
        {
          "type" => "line",
          "x1" => round_number(x1),
          "y1" => round_number(y1),
          "x2" => round_number(x2),
          "y2" => round_number(y2)
        }.merge(filter_keys(element, LINE_STYLE_KEYS))
      end

      def wrap_text(text, max_width, style)
        paragraphs = text.to_s.split("\n", -1)
        size = style.fetch("size", 28).to_f
        font = style.fetch("font", "line_font")
        style_name = style.fetch("style", "plain")
        mono = truthy?(style.fetch("mono", false))

        paragraphs.flat_map do |paragraph|
          if paragraph.empty?
            [""]
          else
            wrap_paragraph(paragraph, max_width, size:, font:, style_name:, mono:)
          end
        end
      end

      def wrap_paragraph(paragraph, max_width, size:, font:, style_name:, mono:)
        words = paragraph.split(/\s+/)
        return [""] if words.empty?

        lines = []
        current = words.shift

        words.each do |word|
          candidate = "#{current} #{word}"
          if LineFont.text_width(candidate, size:, font:, style: style_name, mono:) <= max_width || current.empty?
            current = candidate
          else
            lines << current
            current = word
          end
        end
        lines << current unless current.empty?
        lines
      end

      def plain_text(node)
        case node.type
        when :text, :codespan, :codeblock
          node.value.to_s
        when :entity
          node.value.to_s
        when :smart_quote
          node.value.to_s
        when :typographic_sym
          node.value.to_s
        when :line_break
          "\n"
        else
          node.children.map { |child| plain_text(child) }.join
        end
      end

      def resolved_page_spec(page_config)
        config = stringify_keys(page_config)
        left = config.fetch("left", 130).to_f
        top = config.fetch("top", 130).to_f
        right = config.fetch("right", 1270).to_f
        bottom = config.fetch("bottom", 1740).to_f
        padding = config.fetch("padding", 40).to_f

        {
          "tablet" => config.fetch("tablet", "rm2"),
          "left" => left,
          "top" => top,
          "right" => right,
          "bottom" => bottom,
          "padding" => padding,
          "content_left" => left + padding,
          "content_top" => top + padding,
          "content_right" => right - padding,
          "content_bottom" => bottom - padding,
          "content_width" => (right - left) - (padding * 2.0)
        }
      end

      def new_page_objects(config, page_spec)
        page = stringify_keys(config.fetch("page", {}))
        return [] unless truthy?(page.fetch("show_box", false))

        box = stringify_keys(page.fetch("box", {}))
        [{
          "type" => "rectangle_outline",
          "x" => round_number(page_spec.fetch("left")),
          "y" => round_number(page_spec.fetch("top")),
          "width" => round_number(page_spec.fetch("right") - page_spec.fetch("left")),
          "height" => round_number(page_spec.fetch("bottom") - page_spec.fetch("top"))
        }.merge(filter_keys(box, LINE_STYLE_KEYS))]
      end

      def element_config(config, key)
        stringify_keys(config.fetch("elements", {}).fetch(key) do
          raise ArgumentError, "missing markdown element config: #{key}"
        end)
      end

      def style_config(config, key)
        stringify_keys(config.fetch("styles", {}).fetch(key) do
          raise ArgumentError, "missing markdown style config: #{key}"
        end)
      end

      def relativize_paths(value, target_dir, base_dir)
        case value
        when Hash
          value.each_with_object({}) do |(key, inner), result|
            result[key] = relativize_paths(inner, target_dir, base_dir)
          end
        when Array
          value.map { |item| relativize_paths(item, target_dir, base_dir) }
        when String
          if value.start_with?(base_dir) && File.exist?(value)
            Pathname.new(value).relative_path_from(Pathname.new(target_dir)).to_s
          else
            value
          end
        else
          value
        end
      end

      def merge_config_file!(config, path)
        return config if blank?(path)

        expanded = File.expand_path(path)
        return config unless File.file?(expanded)

        data = safe_load_yaml(expanded)
        deep_merge!(config, stringify_keys(data))
      end

      def safe_load_yaml(path)
        Psych.safe_load(File.read(path), permitted_classes: [], aliases: false) || {}
      end

      def filter_keys(hash, keys)
        stringify_keys(hash).slice(*keys)
      end

      def deep_merge!(base, override)
        override.each do |key, value|
          if base[key].is_a?(Hash) && value.is_a?(Hash)
            deep_merge!(base[key], value)
          else
            base[key] = value
          end
        end
        base
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

      def truthy?(value)
        value == true || value.to_s.downcase == "true"
      end

      def round_number(value)
        value.to_f.round(5)
      end
    end
  end
end

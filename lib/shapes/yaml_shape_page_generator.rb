# frozen_string_literal: true

require "fileutils"
require "pathname"
require "chunky_png"

module Remarkable
  # Generates YAML page descriptions that render directories of PNGs in grids.
  class YamlShapePageGenerator
    PAGE_LEFT = 130.0
    PAGE_TOP = 130.0
    PAGE_RIGHT = 1270.0
    PAGE_BOTTOM = 1740.0
    DEFAULT_OUTER_PADDING = 40.0
    DEFAULT_CELL_GAP = 30.0
    DEFAULT_PIXEL_GAP = 0.0
    DEFAULT_BRUSH = RmPage::Pen::FINELINER_2

    BRUSH_NAMES = RmPage::Pen.constants(false).each_with_object({}) do |name, result|
      result[RmPage::Pen.const_get(name, false)] = name.to_s.downcase
    end.freeze

    class << self
      def parse_layout(layout)
        match = layout.match(/\A(\d+)x(\d+)\z/i)
        raise ArgumentError, "Layout must look like 3x5" unless match

        rows = match[1].to_i
        cols = match[2].to_i
        raise ArgumentError, "Layout dimensions must be positive" unless rows.positive? && cols.positive?

        [rows, cols]
      end

      def generate(image_dir:, layout:, output_dir:, prefix: nil,
                   outer_padding: DEFAULT_OUTER_PADDING,
                   cell_gap: DEFAULT_CELL_GAP,
                   pixel_gap: DEFAULT_PIXEL_GAP,
                   brush: DEFAULT_BRUSH)
        rows, cols = parse_layout(layout)
        image_paths = Dir[File.join(image_dir, "*.png")].sort
        raise ArgumentError, "No PNG files found in #{image_dir}" if image_paths.empty?

        FileUtils.mkdir_p(output_dir)
        prefix ||= File.basename(File.expand_path(image_dir))
        per_page = rows * cols

        image_paths.each_slice(per_page).each_with_index.map do |page_images, page_index|
          path = File.join(output_dir, format("%<prefix>s-%<page>02d.yml", prefix:, page: page_index + 1))
          File.write(
            path,
            build_page_file(
              path,
              page_images,
              rows:,
              cols:,
              outer_padding:,
              cell_gap:,
              pixel_gap:,
              brush:
            )
          )
          path
        end
      end

      def build_page_file(target_path, image_paths, rows:, cols:, outer_padding:, cell_gap:, pixel_gap:, brush:)
        inner_left = PAGE_LEFT + outer_padding
        inner_top = PAGE_TOP + outer_padding
        inner_right = PAGE_RIGHT - outer_padding
        inner_bottom = PAGE_BOTTOM - outer_padding
        cell_width = ((inner_right - inner_left) - (cell_gap * (cols - 1))) / cols.to_f
        cell_height = ((inner_bottom - inner_top) - (cell_gap * (rows - 1))) / rows.to_f
        target_dir = Pathname.new(File.dirname(target_path))

        lines = []
        lines << "canvas:"
        lines << "  tablet: rm2"
        lines << ""
        lines << "objects:"
        lines << "  - type: rectangle_outline"
        lines << "    x: #{format_number(PAGE_LEFT)}"
        lines << "    y: #{format_number(PAGE_TOP)}"
        lines << "    width: #{format_number(PAGE_RIGHT - PAGE_LEFT)}"
        lines << "    height: #{format_number(PAGE_BOTTOM - PAGE_TOP)}"
        lines << "    stroke_width: 4"
        lines << "    color: black"

        image_paths.each_with_index do |image_path, index|
          row = index / cols
          col = index % cols
          width, height = png_dimensions(image_path)
          pixel_size = [cell_width / width, cell_height / height].min
          render_width = width * pixel_size
          render_height = height * pixel_size
          x = inner_left + (col * (cell_width + cell_gap)) + ((cell_width - render_width) / 2.0)
          y = inner_top + (row * (cell_height + cell_gap)) + ((cell_height - render_height) / 2.0)
          relative = Pathname.new(image_path).relative_path_from(target_dir).to_s

          lines << ""
          lines << "  - type: image"
          lines << "    path: #{relative.inspect}"
          lines << "    x: #{format_number(x)}"
          lines << "    y: #{format_number(y)}"
          lines << "    width: #{format_number(render_width)}"
          lines << "    height: #{format_number(render_height)}"
          lines << "    brush: #{brush_name(brush)}"
          lines << "    gap: #{format_number(pixel_gap)}"
        end

        lines << ""
        lines.join("\n")
      end

      def png_dimensions(path)
        image = ChunkyPNG::Image.from_file(path)
        [image.width, image.height]
      end

      private

      def format_number(value)
        format("%.5f", value).sub(/\.?0+\z/, "")
      end

      def brush_name(brush)
        BRUSH_NAMES.fetch(brush) { raise ArgumentError, "Unsupported brush: #{brush}" }
      end
    end
  end
end

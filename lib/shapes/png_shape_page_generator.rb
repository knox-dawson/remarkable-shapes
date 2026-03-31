# frozen_string_literal: true

require "fileutils"
require "pathname"
require "chunky_png"

require_relative "shape_library"

module Remarkable
  # Generates local Ruby shape files that render directories of PNGs in grids.
  class PngShapePageGenerator
    PAGE_LEFT = 130.0
    PAGE_TOP = 130.0
    PAGE_RIGHT = 1270.0
    PAGE_BOTTOM = 1740.0
    DEFAULT_OUTER_PADDING = 40.0
    DEFAULT_CELL_GAP = 30.0
    DEFAULT_PIXEL_GAP = 0.0
    DEFAULT_BRUSH = RmPage::Pen::FINELINER_2

    # Parses a layout specification such as "3x5".
    #
    # @param layout [String]
    # @return [Array<Integer>] rows, columns
    def self.parse_layout(layout)
      match = layout.match(/\A(\d+)x(\d+)\z/i)
      raise ArgumentError, "Layout must look like 3x5" unless match

      rows = match[1].to_i
      cols = match[2].to_i
      raise ArgumentError, "Layout dimensions must be positive" unless rows.positive? && cols.positive?

      [rows, cols]
    end

    # Generates one local Ruby shape file per page of images.
    #
    # @param image_dir [String]
    # @param layout [String]
    # @param output_dir [String]
    # @param prefix [String, nil]
    # @param outer_padding [Numeric]
    # @param cell_gap [Numeric]
    # @param pixel_gap [Numeric]
    # @param brush [Integer]
    # @return [Array<String>] generated file paths
    def self.generate(image_dir:, layout:, output_dir:, prefix: nil,
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
        path = File.join(output_dir, format("%<prefix>s-%<page>02d.rb", prefix:, page: page_index + 1))
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

    # Builds the Ruby source for one generated page file.
    #
    # @param target_path [String]
    # @param image_paths [Array<String>]
    # @param rows [Integer]
    # @param cols [Integer]
    # @param outer_padding [Numeric]
    # @param cell_gap [Numeric]
    # @param pixel_gap [Numeric]
    # @param brush [Integer]
    # @return [String]
    def self.build_page_file(target_path, image_paths, rows:, cols:, outer_padding:, cell_gap:, pixel_gap:, brush:)
      inner_left = PAGE_LEFT + outer_padding
      inner_top = PAGE_TOP + outer_padding
      inner_right = PAGE_RIGHT - outer_padding
      inner_bottom = PAGE_BOTTOM - outer_padding
      cell_width = ((inner_right - inner_left) - (cell_gap * (cols - 1))) / cols.to_f
      cell_height = ((inner_bottom - inner_top) - (cell_gap * (rows - 1))) / rows.to_f
      target_dir = Pathname.new(File.dirname(target_path))

      lines = []
      lines << "# frozen_string_literal: true"
      lines << ""
      lines << "lambda do |page|"
      lines << "  Remarkable::Shapes.rm2_box(page, color: Remarkable::RmPage::Colour::BLACK)"

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
        lines << "  png_path = File.expand_path(#{relative.inspect}, __dir__)"
        lines << "  Remarkable::ShapeLibrary.draw_png_shape(page, png_path, #{format('%.3f', x)}, #{format('%.3f', y)}, #{format('%.5f', pixel_size)}, brush: #{brush}, gap: #{format('%.5f', pixel_gap)})"
      end

      lines << "end"
      lines << ""
      lines.join("\n")
    end

    # Returns the width and height of a PNG file.
    #
    # @param path [String]
    # @return [Array<Integer>]
    def self.png_dimensions(path)
      image = ChunkyPNG::Image.from_file(path)
      [image.width, image.height]
    end
  end
end

# frozen_string_literal: true

require_relative "../io/rm_page"
require_relative "shapes"

module Remarkable
  # Renders a single PNG image onto a page without drawing the standard box.
  module ImageGenerator
    # Left edge of the standard drawable page box.
    BOX_LEFT = 130.0
    # Top edge of the standard drawable page box.
    BOX_TOP = 130.0
    # Right edge of the standard drawable page box.
    BOX_RIGHT = 1270.0
    # Bottom edge of the standard drawable page box.
    BOX_BOTTOM = 1740.0

    # Default padding above the image.
    DEFAULT_TOP_PADDING = 40.0
    # Default padding on the left and right sides.
    DEFAULT_SIDE_PADDING = 20.0
    # Default padding below the image.
    DEFAULT_BOTTOM_PADDING = 20.0
    # Default brush used for PNG-backed image rendering.
    DEFAULT_BRUSH = RmPage::Pen::HIGHLIGHTER_2
    # Default gap between rendered pixel cells.
    DEFAULT_PIXEL_GAP = -3.0

    module_function

    # Computes placement for an image inside the standard page bounds.
    #
    # @return [Hash]
    def layout_for_image(image_width, image_height,
                         top_padding: DEFAULT_TOP_PADDING,
                         side_padding: DEFAULT_SIDE_PADDING,
                         bottom_padding: DEFAULT_BOTTOM_PADDING)
      raise ArgumentError, "image dimensions must be positive" if image_width.to_i <= 0 || image_height.to_i <= 0

      available_width = (BOX_RIGHT - BOX_LEFT) - (2.0 * side_padding.to_f)
      available_height = (BOX_BOTTOM - BOX_TOP) - top_padding.to_f - bottom_padding.to_f
      raise ArgumentError, "image padding leaves no usable space" if available_width <= 0 || available_height <= 0

      pixel_size = [
        available_width / image_width.to_f,
        available_height / image_height.to_f
      ].min
      raise ArgumentError, "image does not fit within page bounds" if pixel_size <= 0

      grid_width = image_width.to_f * pixel_size
      x = BOX_LEFT + side_padding.to_f + ((available_width - grid_width) / 2.0)
      y = BOX_TOP + top_padding.to_f

      {
        x:,
        y:,
        pixel_size:,
        width: grid_width,
        height: image_height.to_f * pixel_size
      }
    end

    # Draws one PNG image onto the page without the surrounding rm2 box.
    #
    # @return [Hash] layout information
    def draw_png(page, png_path,
                 top_padding: DEFAULT_TOP_PADDING,
                 side_padding: DEFAULT_SIDE_PADDING,
                 bottom_padding: DEFAULT_BOTTOM_PADDING,
                 brush: DEFAULT_BRUSH,
                 pixel_gap: DEFAULT_PIXEL_GAP)
      rgba_grid = Shapes.png_to_rgba_grid(png_path)
      image_height = rgba_grid.length
      image_width = rgba_grid.first&.length.to_i
      raise ArgumentError, "PNG grid must not be empty" if image_width <= 0

      layout = layout_for_image(
        image_width,
        image_height,
        top_padding:,
        side_padding:,
        bottom_padding:
      )

      Shapes.draw_rgba_grid(
        page,
        rgba_grid,
        layout[:x],
        layout[:y],
        layout[:pixel_size],
        gap: pixel_gap,
        brush:
      )

      layout
    end
  end
end

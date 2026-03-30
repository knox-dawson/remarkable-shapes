# frozen_string_literal: true

require_relative "../io/rm_page"

module Remarkable
  # Geometry and raster-like drawing helpers for {RmPage}.
  module Shapes
    DEFAULT_RGBA = 0xFF000000
    DEFAULT_COLOR = RmPage::Colour::RGBA
    DEFAULT_BRUSH = RmPage::Pen::FINELINER_2

    RIGHT = 0
    DOWN = Math::PI / 2
    LEFT = Math::PI
    UP = 3 * Math::PI / 2

    module_function

    # Draws the standard reMarkable page box used in this project.
    #
    # @param page [Remarkable::RmPage]
    # @param rgba [Integer, Array<Integer>, Hash] RGBA colour
    # @param color [Integer] tablet colour code
    # @param brush [Integer] tablet pen identifier
    # @return [void]
    def rm2_box(page, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      draw_box(page, 130, 130, 1270, 1740, 4, rgba:, color:, brush:)
    end

    # Draws a polyline box.
    #
    # @return [void]
    def draw_box(page, x1, y1, x2, y2, width, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      line = page.add_line
      apply_style(line, rgba:, color:, brush:)
      [[x1, y1], [x2, y1], [x2, y2], [x1, y2], [x1, y1]].each do |x, y|
        line.add_point(x, y).width = width
      end
    end

    # Draws a simple two-point line.
    #
    # @return [void]
    def draw_line(page, x1, y1, x2, y2, width, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      line = page.add_line
      apply_style(line, rgba:, color:, brush:)
      line.add_point(x1, y1).width = width
      line.add_point(x2, y2).width = width
    end

    # Draws a thick tapered rectangle-like stroke.
    #
    # @return [void]
    def rect(page, x1, y1, x2, y2, width, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      line = page.add_line
      apply_style(line, rgba:, color:, brush:)
      draw_tapered_segment(line, x1, y1, x2, y2, width)
    end

    # Draws a wide filled rectangle-like stroke with a separate outline stroke.
    #
    # This matches the old Java rectOutlined helper closely, while fitting the
    # current Ruby API style.
    #
    # @return [void]
    def rect_outlined(page, x1, y1, x2, y2, width, line_width,
                      rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH,
                      outline_rgba: DEFAULT_RGBA, outline_color: DEFAULT_COLOR, outline_brush: DEFAULT_BRUSH)
      rect(page, x1, y1, x2, y2, width, rgba:, color:, brush:)

      draw_box(
        page,
        x1,
        y1 - (width * 0.5),
        x2,
        y2 + (width * 0.5),
        line_width,
        rgba: outline_rgba,
        color: outline_color,
        brush: outline_brush
      )
    end

    # Compatibility wrapper for older Java-style translated generators.
    #
    # @return [void]
    def rectOutlined(page, x1, y1, x2, y2, width, color, line_width, line_color, brush, brush2)
      rect_outlined(
        page, x1, y1, x2, y2, width, line_width,
        color:,
        brush:,
        outline_color: line_color,
        outline_brush: brush2
      )
    end

    # Draws a wide rectangle-like stroke with a folded corner and outline.
    #
    # This matches the old Java rectCorner helper closely, while fitting the
    # current Ruby API style.
    #
    # @return [void]
    def rect_corner(page, x1, y1, x2, y2, width, corner, line_width,
                    rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH,
                    corner_rgba: DEFAULT_RGBA, corner_color: DEFAULT_COLOR,
                    outline_rgba: DEFAULT_RGBA, outline_color: DEFAULT_COLOR, outline_brush: DEFAULT_BRUSH,
                    corner_outline_rgba: DEFAULT_RGBA, corner_outline_color: DEFAULT_COLOR)
      c = corner

      rect(page, x1, y1, x2 - c, y2, width, rgba:, color:, brush:)
      rect(page, x2 - c, y2 + (c * 0.5), x2, y2 + (c * 0.5), width - c, rgba:, color:, brush:)

      hypotenuse = c * Math.sqrt(2)
      height = c / Math.sqrt(2)
      xprime = x2 - c
      yprime = y2 + (c * 0.5) - ((width - c) / 2.0)
      hprime = height / Math.sqrt(2)
      triangle(
        page,
        xprime,
        yprime,
        xprime + hprime,
        yprime - hprime,
        hypotenuse,
        rgba: corner_rgba,
        color: corner_color,
        brush:
      )

      xa = x2 - c
      ya = y2 - (width * 0.5)
      xb = x1
      yb = y1 - (width * 0.5)
      xc = x1
      yc = y1 + (width * 0.5)
      xd = x2
      yd = y2 + (width * 0.5)
      xe = x2
      ye = y2 + (c * 0.5) - ((width - c) * 0.5)

      line = page.add_line
      apply_style(line, rgba: outline_rgba, color: outline_color, brush: outline_brush)
      [[xa, ya], [xb, yb], [xc, yc], [xd, yd], [xe, ye]].each do |x, y|
        line.add_point(x, y).width = line_width
      end

      line2 = page.add_line
      apply_style(line2, rgba: corner_outline_rgba, color: corner_outline_color, brush: outline_brush)
      [[xa, ya], [xa, ye], [xe, ye], [xa, ya]].each do |x, y|
        line2.add_point(x, y).width = line_width
      end
    end

    # Compatibility wrapper for older Java-style translated generators.
    #
    # @return [void]
    def rectCorner(page, x1, y1, x2, y2, width, corner, color, corner_color, line_width, line_color, corner_line_color, brush, brush2)
      rect_corner(
        page, x1, y1, x2, y2, width, corner, line_width,
        color:,
        brush:,
        corner_color:,
        outline_color: line_color,
        outline_brush: brush2,
        corner_outline_color: corner_line_color
      )
    end

    # Draws a filled circle approximated by a very short wide line.
    #
    # @return [void]
    def circle(page, cx, cy, radius, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      line = page.add_line
      apply_style(line, rgba:, color:, brush:)
      line.add_point(cx, cy).width = radius * 2
      line.add_point(cx + 0.001, cy + 0.001).width = radius * 2
    end

    # Compatibility wrapper for older Java-style translated generators.
    #
    # @return [void]
    def circleShader(page, rgba, cx, cy, radius)
      circle(page, cx, cy, radius, rgba:, brush: RmPage::Pen::SHADER)
    end

    # Compatibility wrapper for older Java-style translated generators.
    #
    # @return [void]
    def rm2Box(page)
      rm2_box(page)
    end

    # Converts a PNG file into a 2D array of ARGB integers.
    #
    # @param path [String]
    # @return [Array<Array<Integer>>]
    def png_to_rgba_grid(path)
      require "chunky_png"

      image = ChunkyPNG::Image.from_file(path)
      Array.new(image.height) do |y|
        Array.new(image.width) do |x|
          pixel = image[x, y]
          rgba_int(
            ChunkyPNG::Color.r(pixel),
            ChunkyPNG::Color.g(pixel),
            ChunkyPNG::Color.b(pixel),
            ChunkyPNG::Color.a(pixel)
          )
        end
      end
    end

    # Draws a 2D array of RGBA values as a grid of tiny rectangles.
    #
    # @param page [Remarkable::RmPage]
    # @param rgba_grid [Array<Array<Integer, Array<Integer>, Hash>>]
    # @param x [Numeric] top-left x
    # @param y [Numeric] top-left y
    # @param pixel_size [Numeric] cell size in page units
    # @param gap [Numeric] empty space between cells
    # @param brush [Integer] tablet pen identifier
    # @return [void]
    def draw_rgba_grid(page, rgba_grid, x, y, pixel_size, gap: 0.0, brush: DEFAULT_BRUSH)
      raise ArgumentError, "rgba_grid must not be empty" if rgba_grid.nil? || rgba_grid.empty?

      draw_size = pixel_size - gap
      raise ArgumentError, "pixel_size must be greater than gap" if draw_size <= 0

      half = draw_size / 2.0
      rgba_grid.each_with_index do |row, row_index|
        row.each_with_index do |rgba, col_index|
          value = normalize_rgba(rgba)
          next if alpha_channel(value).zero?

          cx = x + (col_index * pixel_size) + (pixel_size / 2.0)
          cy = y + (row_index * pixel_size) + (pixel_size / 2.0)
          rect(page, cx - half, cy, cx + half, cy, draw_size, rgba: value, brush:)
        end
      end
    end

    # Draws a semicircle-like wide stroke in a given direction.
    #
    # @return [void]
    def semicircle(page, cx, cy, radius, angle, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      line = page.add_line
      apply_style(line, rgba:, color:, brush:)
      eps = 0.001
      dx = Math.cos(angle) * eps
      dy = Math.sin(angle) * eps
      line.add_point(cx - dx, cy - dy).width = 0
      line.add_point(cx + dx, cy + dy).width = radius * 2
    end

    # Draws a tapered isosceles triangle using a three-point stroke.
    #
    # @return [void]
    def triangle(page, ax, ay, bx, by, width, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      dx = bx - ax
      dy = by - ay
      len = Math.sqrt(dx * dx + dy * dy)
      return if len.zero?

      ux = dx / len
      uy = dy / len
      eps = 0.01
      px = bx + ux * eps
      py = by + uy * eps

      line = page.add_line
      apply_style(line, rgba:, color:, brush:)
      line.add_point(px, py).width = 0
      line.add_point(bx, by).width = width
      line.add_point(ax, ay).width = 0
    end

    # Draws the exact right-triangle construction based on two isosceles triangles.
    #
    # @return [void]
    def right_triangle(page, ax, ay, bx, by, cx, cy, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      dab = Math.hypot(ax - bx, ay - by)
      dbc = Math.hypot(cx - bx, cy - by)
      dac = Math.hypot(cx - ax, cy - ay)
      return if dac.zero?

      hx = cx - ax
      hy = cy - ay

      t1 = dab / dac
      p1x = ax + t1 * hx
      p1y = ay + t1 * hy
      m1x = (bx + p1x) / 2.0
      m1y = (by + p1y) / 2.0
      w1 = Math.hypot(p1x - bx, p1y - by)
      triangle(page, ax, ay, m1x, m1y, w1, rgba:, color:, brush:)

      t2 = 1.0 - (dbc / dac)
      p2x = ax + t2 * hx
      p2y = ay + t2 * hy
      m2x = (bx + p2x) / 2.0
      m2y = (by + p2y) / 2.0
      w2 = Math.hypot(p2x - bx, p2y - by)
      triangle(page, cx, cy, m2x, m2y, w2, rgba:, color:, brush:)
    end

    # Draws a multi-arm star as a collection of tapered strokes.
    #
    # @return [void]
    def stars(page, cx, cy, radius, points, wide_point_percent, width, rotation: 0, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      arms = generate_star_lines(cx, cy, radius, points, wide_point_percent, width, rotation)
      points.times do |arm|
        line = page.add_line
        apply_style(line, rgba:, color:, brush:)
        3.times do |index|
          line.add_point(arms[arm][index][0], arms[arm][index][1]).width = arms[arm][index][2]
        end
      end
    end

    # Generates the three control points for each star arm.
    #
    # @return [Array<Array<Array<Float>>>]
    def generate_star_lines(cx, cy, radius, points, wide_point_percent, width, rotation_degrees)
      result = Array.new(points) { Array.new(3) { Array.new(3, 0.0) } }
      t = wide_point_percent / 100.0
      r_wide = radius * t
      final_width = if width.negative?
                      2.0 * r_wide * Math.tan(Math::PI / points) * 1.005
                    else
                      width
                    end
      rotation = rotation_degrees * Math::PI / 180.0
      start_angle = (-90 * Math::PI / 180.0) + rotation

      points.times do |index|
        angle = start_angle + index * (2 * Math::PI / points)
        result[index][0] = [cx, cy, 0.0]
        result[index][1] = [cx + r_wide * Math.cos(angle), cy + r_wide * Math.sin(angle), final_width]
        result[index][2] = [cx + radius * Math.cos(angle), cy + radius * Math.sin(angle), 0.0]
      end
      result
    end

    # Draws a striped flag pattern using an array of colour or RGBA values.
    #
    # @param colors [Array<Integer, Array<Integer>, Hash>] stripe colours
    # @return [void]
    def striped_flag(page, x, y, width, height, direction, stripe_count, percentages = nil, colors:, brush: DEFAULT_BRUSH)
      raise ArgumentError, "stripe_count must be > 0" if stripe_count <= 0
      raise ArgumentError, "Not enough colors for stripes" if colors.nil? || colors.length < stripe_count

      total_length = direction == :left_to_right ? width : height
      stripe_lengths = Array.new(stripe_count, 0.0)

      used_fraction = 0.0
      provided = percentages.nil? ? 0 : [percentages.length, stripe_count].min
      provided.times do |index|
        stripe_lengths[index] = total_length * (percentages[index] / 100.0)
        used_fraction += percentages[index] / 100.0
      end

      remaining = stripe_count - provided
      if remaining.positive?
        each = total_length * (1.0 - used_fraction) / remaining
        provided.upto(stripe_count - 1) { |index| stripe_lengths[index] = each }
      end

      offset = 0.0
      stripe_count.times do |index|
        value = colors[index]
        unless value == -1
          style = style_options(value)
          if direction == :left_to_right
            cx1 = x + offset
            cx2 = cx1 + stripe_lengths[index]
            cy = y + height / 2.0
            rect(page, cx1, cy, cx2, cy, height, brush:, **style)
          else
            cy1 = y + offset
            cy2 = cy1 + stripe_lengths[index]
            cx = x + width / 2.0
            rect(page, cx, cy1, cx, cy2, width, brush:, **style)
          end
        end
        offset += stripe_lengths[index]
      end
    end

    # Builds a 32-bit ARGB integer from channels.
    #
    # @return [Integer]
    def rgba_int(r, g, b, a = 255)
      ((a & 0xFF) << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF)
    end

    # Normalizes an Integer, Array, or Hash into a 32-bit ARGB integer.
    #
    # @return [Integer]
    def normalize_rgba(rgba)
      case rgba
      when Integer
        rgba
      when Array
        raise ArgumentError, "RGBA array must have 4 elements" unless rgba.length == 4

        rgba_int(rgba[0], rgba[1], rgba[2], rgba[3])
      when Hash
        rgba_int(fetch_channel(rgba, :r), fetch_channel(rgba, :g), fetch_channel(rgba, :b), fetch_channel(rgba, :a))
      else
        raise ArgumentError, "Unsupported rgba value: #{rgba.inspect}"
      end
    end

    # Returns a normalized style hash for a colour code or RGBA input.
    #
    # @return [Hash]
    def style_options(value, default_rgba: DEFAULT_RGBA)
      if value.is_a?(Integer) && RmPage::Colour::VALUES.include?(value)
        { rgba: default_rgba, color: value }
      else
        { rgba: normalize_rgba(value), color: RmPage::Colour::RGBA }
      end
    end

    # Reads one channel from a symbol-keyed or string-keyed hash.
    #
    # @return [Integer]
    def fetch_channel(rgba, key)
      rgba.fetch(key) { rgba.fetch(key.to_s) }
    end

    # Returns the alpha byte from a normalized RGBA value.
    #
    # @return [Integer]
    def alpha_channel(rgba)
      (rgba >> 24) & 0xFF
    end

    # Applies brush and colour styling to a line.
    #
    # @return [void]
    def apply_style(line, rgba:, color:, brush:)
      line.brush_type = brush
      if color == RmPage::Colour::RGBA
        line.color = RmPage::Colour::RGBA
        line.rgba = normalize_rgba(rgba)
      else
        line.color = color
      end
    end

    # Draws the shared tapered four-point stroke shape.
    #
    # @return [void]
    def draw_tapered_segment(line, x1, y1, x2, y2, width)
      dx = x2 - x1
      dy = y2 - y1
      len = Math.sqrt(dx * dx + dy * dy)
      return if len.zero?

      ux = dx / len
      uy = dy / len
      eps = 0.01

      line.add_point(x1 - eps * ux, y1 - eps * uy).width = 0
      line.add_point(x1, y1).width = width
      line.add_point(x2, y2).width = width
      line.add_point(x2 + eps * ux, y2 + eps * uy).width = 0
    end
  end
end

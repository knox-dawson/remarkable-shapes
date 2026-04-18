# frozen_string_literal: true

require_relative "../io/rm_page"

module Remarkable
  # Geometry and raster-like drawing helpers for {RmPage}.
  module Shapes
    # Default opaque black RGBA colour.
    DEFAULT_RGBA = 0xFF000000
    # Default colour mode uses explicit RGBA.
    DEFAULT_COLOR = RmPage::Colour::RGBA
    # Default brush for most geometry helpers.
    DEFAULT_BRUSH = RmPage::Pen::FINELINER_2

    # Angle constant for the rightward direction.
    RIGHT = 0
    # Angle constant for the downward direction.
    DOWN = Math::PI / 2
    # Angle constant for the leftward direction.
    LEFT = Math::PI
    # Angle constant for the upward direction.
    UP = 3 * Math::PI / 2

    module_function

    # Draws the standard reMarkable page box used in this project.
    #
    # @param page [Remarkable::RmPage]
    # @param rgba [Integer, Array<Integer>, Hash] RGBA colour
    # @param color [Integer] tablet colour code
    # @param brush [Integer] tablet pen identifier
    # @example Ruby lambda
    #   Remarkable::Shapes.rm2_box(page, color: Remarkable::RmPage::Colour::BLACK)
    # @return [void]
    def rm2_box(page, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      draw_box(page, 130, 130, 1270, 1740, 4, rgba:, color:, brush:)
    end

    # Draws a polyline box.
    #
    # @example Ruby lambda
    #   Remarkable::Shapes.draw_box(page, 120, 120, 1280, 1740, 4, color: Remarkable::RmPage::Colour::GREY)
    # @return [void]
    def draw_box(page, x1, y1, x2, y2, width, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      line = page.add_line
      apply_style(line, rgba:, color:, brush:)
      line.thickness_scale = width.to_f
      [[x1, y1], [x2, y1], [x2, y2], [x1, y2], [x1, y1]].each do |x, y|
        line.add_point(x, y).width = width
      end
    end

    # Draws a simple two-point line.
    #
    # @example Ruby lambda
    #   Remarkable::Shapes.draw_line(page, 140, 240, 1240, 240, 8, rgba: 0xFF444444)
    # @return [void]
    def draw_line(page, x1, y1, x2, y2, width, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      line = page.add_line
      apply_style(line, rgba:, color:, brush:)
      line.thickness_scale = width.to_f
      line.add_point(x1, y1).width = width
      line.add_point(x2, y2).width = width
    end

    # Draws a multi-point polyline using a constant stroke width.
    #
    # @param points [Array<Array<Numeric>>]
    # @return [void]
    def draw_polyline(page, points, width, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      return if points.length < 2

      line = page.add_line
      apply_style(line, rgba:, color:, brush:)
      line.thickness_scale = width.to_f
      points.each do |x, y|
        line.add_point(x, y).width = width
      end
    end

    # Draws line-font text using the shared vector font renderer.
    #
    # @example Ruby lambda
    #   Remarkable::Shapes.text(page, "remarkable-shapes", 180, 260, size: 42, stroke_width: 3, color: Remarkable::RmPage::Colour::BLACK)
    # @return [Float] rendered width
    def text(page, string, x, baseline_y, size: 48.0, stroke_width: 2.0, style: :plain, font: :default, mono: false,
             rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      require_relative "line_font"

      LineFont.draw_text(
        page, string, x, baseline_y,
        size:,
        stroke_width:,
        style:,
        font:,
        mono:,
        rgba:,
        color:,
        brush:
      )
    end

    # Draws line-font text with a shadow pass followed by the main pass.
    #
    # @example Ruby lambda
    #   Remarkable::Shapes.shadow_text(page, "remarkable-shapes", 180, 260, shadow_dx: 6, shadow_dy: 6,
    #                                  shadow_color: Remarkable::RmPage::Colour::GREY,
    #                                  color: Remarkable::RmPage::Colour::BLACK)
    # @return [Float] rendered width including the horizontal shadow extent
    def shadow_text(page, string, x, baseline_y, size: 48.0, stroke_width: 2.0, style: :plain, font: :default, mono: false,
                    shadow_dx: 0.0, shadow_dy: 0.0,
                    shadow_rgba: DEFAULT_RGBA, shadow_color: DEFAULT_COLOR, shadow_brush: DEFAULT_BRUSH,
                    rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      text(
        page,
        string,
        x.to_f + shadow_dx.to_f,
        baseline_y.to_f + shadow_dy.to_f,
        size:,
        stroke_width:,
        style:,
        font:,
        mono:,
        rgba: shadow_rgba,
        color: shadow_color,
        brush: shadow_brush
      )

      width = text(
        page,
        string,
        x,
        baseline_y,
        size:,
        stroke_width:,
        style:,
        font:,
        mono:,
        rgba:,
        color:,
        brush:
      )

      width + shadow_dx.to_f.abs
    end

    # Draws a thick tapered rectangle-like stroke.
    #
    # @example Ruby lambda
    #   Remarkable::Shapes.rect(page, 220, 420, 1080, 420, 120, color: Remarkable::RmPage::Colour::YELLOW)
    # @return [void]
    def rect(page, x1, y1, x2, y2, width, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      line = page.add_line
      apply_style(line, rgba:, color:, brush:)
      if brush == RmPage::Pen::HIGHLIGHTER_2
        line.thickness_scale = width.to_f
        draw_constant_segment(line, x1, y1, x2, y2, width)
      else
        draw_tapered_segment(line, x1, y1, x2, y2, width)
      end
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

    # Draws a wide rectangle-like stroke with clipped ends.
    #
    # @return [void]
    def rect_corners(page, x1, y1, x2, y2, width, corner,
                     rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      line = page.add_line
      apply_style(line, rgba:, color:, brush:)
      widths = [0.0, width - (corner * 2.0), width.to_f, width.to_f, width - (corner * 2.0), 0.0]
      points = [
        [x1 - 0.01, y1],
        [x1, y1],
        [x1 + corner, y1],
        [x2 - corner, y2],
        [x2, y2],
        [x2 + 0.01, y2]
      ]
      points.each_with_index do |(x, y), index|
        line.add_point(x, y).width = widths[index]
      end
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

    # Compatibility wrapper for older Java-style translated generators.
    #
    # @return [void]
    def rectCorners(page, x1, y1, x2, y2, width, corner, color)
      rect_corners(page, x1, y1, x2, y2, width, corner, color:)
    end

    # Draws a filled circle approximated by a very short wide line.
    #
    # @example Ruby lambda
    #   Remarkable::Shapes.circle(page, 320, 320, 70, color: Remarkable::RmPage::Colour::RED)
    # @return [void]
    def circle(page, cx, cy, radius, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      diameter = radius.to_f * 2.0
      line = page.add_line
      apply_style(line, rgba:, color:, brush:)
      line.thickness_scale = diameter
      line.add_point(cx, cy).width = diameter
      line.add_point(cx + 0.001, cy + 0.001).width = diameter
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

    # Draws a box with clipped corners.
    #
    # @return [void]
    def draw_box_corners(page, x1, y1, x2, y2, width, corner,
                         rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      points = [
        [x1, y1 + corner],
        [x1 + corner, y1],
        [x2 - corner, y1],
        [x2, y1 + corner],
        [x2, y2 - corner],
        [x2 - corner, y2],
        [x1 + corner, y2],
        [x1, y2 - corner],
        [x1, y1 + corner]
      ]
      draw_polyline(page, points, width, rgba:, color:, brush:)
    end

    # Compatibility wrapper for older Java-style translated generators.
    #
    # @return [void]
    def drawBoxCorners(page, x1, y1, x2, y2, width, corner, color)
      draw_box_corners(page, x1, y1, x2, y2, width, corner, color:)
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

    # Builds a raster RGBA grid for a filled rectangle.
    #
    # @return [Array<Array<Integer>>]
    def rectangle_rgba_grid(width_pixels, height_pixels, rgba:, outline_rgba: nil, outline_width_pixels: 0,
                            antialias_samples: 4)
      raster_shape_rgba_grid(
        width_pixels,
        height_pixels,
        rgba:,
        outline_rgba:,
        outline_width_pixels:,
        antialias_samples:
      ) do |x, y, width, height|
        inside = x >= 0.0 && x <= width.to_f && y >= 0.0 && y <= height.to_f
        next [false, false] unless inside

        distance = [x, width.to_f - x, y, height.to_f - y].min
        [true, distance <= outline_width_pixels.to_f]
      end
    end

    # Builds a raster RGBA grid for a filled circle.
    #
    # @return [Array<Array<Integer>>]
    def circle_rgba_grid(diameter_pixels, rgba:, outline_rgba: nil, outline_width_pixels: 0, antialias_samples: 4)
      size = diameter_pixels.to_i
      raster_shape_rgba_grid(
        size,
        size,
        rgba:,
        outline_rgba:,
        outline_width_pixels:,
        antialias_samples:
      ) do |x, y, width, height|
        radius = [width, height].min / 2.0
        cx = width / 2.0
        cy = height / 2.0
        distance = Math.hypot(x - cx, y - cy)
        inside = distance <= radius
        [inside, inside && (radius - distance) <= outline_width_pixels.to_f]
      end
    end

    # Rasterizes one parametric shape into an RGBA grid with optional antialiasing.
    #
    # @return [Array<Array<Integer>>]
    def raster_shape_rgba_grid(width_pixels, height_pixels, rgba:, outline_rgba: nil, outline_width_pixels: 0,
                               antialias_samples: 4, &shape_fn)
      width = width_pixels.to_i
      height = height_pixels.to_i
      raise ArgumentError, "width_pixels must be positive" unless width.positive?
      raise ArgumentError, "height_pixels must be positive" unless height.positive?

      fill_value = normalize_rgba(rgba)
      outline_value = outline_rgba.nil? ? nil : normalize_rgba(outline_rgba)
      samples = [antialias_samples.to_i, 1].max
      total_samples = samples * samples

      Array.new(height) do |row|
        Array.new(width) do |col|
          fill_hits = 0
          outline_hits = 0
          samples.times do |sy|
            samples.times do |sx|
              sample_x = col + ((sx + 0.5) / samples.to_f)
              sample_y = row + ((sy + 0.5) / samples.to_f)
              inside, outline = shape_fn.call(sample_x, sample_y, width, height)
              next unless inside

              fill_hits += 1
              outline_hits += 1 if outline
            end
          end

          next 0x00000000 if fill_hits.zero?

          if outline_value && outline_width_pixels.to_f.positive? && outline_hits.positive?
            scale_rgba_alpha(outline_value, outline_hits.to_f / total_samples)
          else
            scale_rgba_alpha(fill_value, fill_hits.to_f / total_samples)
          end
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
    # @example Ruby lambda
    #   rgba_grid = Remarkable::Shapes.png_to_rgba_grid("examples/cat.png")
    #   Remarkable::Shapes.draw_rgba_grid(page, rgba_grid, 240, 260, 6.0, gap: -0.10, brush: Remarkable::RmPage::Pen::HIGHLIGHTER_2)
    # @return [void]
    def draw_rgba_grid(page, rgba_grid, x, y, pixel_size, gap: -3.0, brush: RmPage::Pen::HIGHLIGHTER_2)
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

    # Scales only the alpha channel of one RGBA value.
    #
    # @return [Integer]
    def scale_rgba_alpha(rgba, factor)
      value = normalize_rgba(rgba)
      alpha = [[((alpha_channel(value) * factor.to_f).round), 0].max, 255].min
      (value & 0x00FFFFFF) | (alpha << 24)
    end

    # Draws a semicircle-like wide stroke in a given direction.
    #
    # @example Ruby lambda
    #   Remarkable::Shapes.semicircle(page, 720, 280, 70, Remarkable::Shapes::RIGHT, color: Remarkable::RmPage::Colour::BLUE)
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
    # @example Ruby lambda
    #   Remarkable::Shapes.triangle(page, 180, 560, 360, 650, 120, color: Remarkable::RmPage::Colour::GREEN)
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
    # @example Ruby lambda
    #   Remarkable::Shapes.right_triangle(page, 520, 500, 520, 700, 760, 700, color: Remarkable::RmPage::Colour::MAGENTA)
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

    # Returns the corner points for an axis-aligned square.
    #
    # @return [Array<Array<Float>>]
    def generate_square_box(cx, cy, side)
      half = side / 2.0
      [
        [cx - half, cy - half],
        [cx + half, cy - half],
        [cx + half, cy + half],
        [cx - half, cy + half]
      ]
    end

    # Returns the three control points for the square-line fill trick.
    #
    # @return [Array<Array<Float>>]
    def generate_square_line(cx, cy, side)
      diag = side * Math.sqrt(2.0)
      half = side / 2.0
      [
        [cx - half, cy - half, 0.0],
        [cx, cy, diag],
        [cx + half, cy + half, 0.0]
      ]
    end

    # Draws a filled diamond-shaped square using one wide tapered line.
    #
    # @return [void]
    def draw_square_line(page, cx, cy, side, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      line = page.add_line
      apply_style(line, rgba:, color:, brush:)
      generate_square_line(cx, cy, side).each do |x, y, width|
        line.add_point(x, y).width = width
      end
    end

    # Compatibility wrapper for older Java-style translated generators.
    #
    # @return [void]
    def drawSquareLine(page, cx, cy, side, color)
      draw_square_line(page, cx, cy, side, color:)
    end

    # Draws an outlined square using four constant-width edges.
    #
    # @return [void]
    def draw_square_box(page, cx, cy, side, width, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      points = generate_square_box(cx, cy, side)
      4.times do |index|
        nx = (index + 1) % 4
        draw_line(page, points[index][0], points[index][1], points[nx][0], points[nx][1], width, rgba:, color:, brush:)
      end
    end

    # Compatibility wrapper for older Java-style translated generators.
    #
    # @return [void]
    def drawSquareBox(page, cx, cy, side, width, color)
      draw_square_box(page, cx, cy, side, width, color:)
    end

    # Draws a multi-arm star as a collection of tapered strokes.
    #
    # @example Ruby lambda
    #   Remarkable::Shapes.stars(page, 1020, 620, 120, 5, 31, -1, color: Remarkable::RmPage::Colour::BLACK)
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

    # Draws a multi-arm star with one or more alternating colours.
    #
    # @param colors [Array<Integer, Array<Integer>, Hash>]
    # @return [void]
    def stars_colored(page, cx, cy, radius, points, wide_point_percent, width, colors:, rotation: 0, brush: DEFAULT_BRUSH)
      raise ArgumentError, "colors must not be empty" if colors.nil? || colors.empty?

      arms = generate_star_lines(cx, cy, radius, points, wide_point_percent, width, rotation)
      points.times do |arm|
        style = style_options(colors[arm % colors.length])
        line = page.add_line
        apply_style(line, brush:, **style)
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

    # Returns the vertices of a regular polygon.
    #
    # @return [Array<Array<Float>>]
    def regular_polygon_points(cx, cy, radius, sides, rotation: 0)
      raise ArgumentError, "sides must be >= 3" if sides.to_i < 3

      start_angle = (-90.0 * Math::PI / 180.0) + (rotation.to_f * Math::PI / 180.0)
      Array.new(sides) do |index|
        angle = start_angle + index * (2.0 * Math::PI / sides.to_f)
        [cx + radius * Math.cos(angle), cy + radius * Math.sin(angle)]
      end
    end

    # Draws a freeform polygon outline.
    #
    # @param points [Array<Array<Numeric>>]
    # @example Ruby lambda
    #   Remarkable::Shapes.polygon_outline(page, [[120, 740], [340, 610], [450, 820], [250, 980]], 12, color: Remarkable::RmPage::Colour::GREEN)
    # @return [void]
    def polygon_outline(page, points, width, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      raise ArgumentError, "polygon requires at least 3 points" if points.length < 3

      closed = points + [points.first]
      draw_polyline(page, closed, width, rgba:, color:, brush:)
    end

    # Draws a filled convex polygon using a triangle fan from its centroid.
    #
    # @param points [Array<Array<Numeric>>]
    # @param colors [Array<Integer, Array<Integer>, Hash>]
    # @return [void]
    def polygon_fill(page, points, colors:, brush: DEFAULT_BRUSH)
      raise ArgumentError, "polygon requires at least 3 points" if points.length < 3
      raise ArgumentError, "colors must not be empty" if colors.nil? || colors.empty?

      centroid_x = points.sum { |point| point[0].to_f } / points.length.to_f
      centroid_y = points.sum { |point| point[1].to_f } / points.length.to_f

      points.length.times do |index|
        a = points[index]
        b = points[(index + 1) % points.length]
        mid_x = (a[0] + b[0]) / 2.0
        mid_y = (a[1] + b[1]) / 2.0
        width = Math.hypot(b[0] - a[0], b[1] - a[1])
        style = style_options(colors[index % colors.length])
        triangle(page, centroid_x, centroid_y, mid_x, mid_y, width, brush:, **style)
      end
    end

    # Draws a regular polygon outline.
    #
    # @example Ruby lambda
    #   Remarkable::Shapes.regular_polygon_outline(page, 670, 850, 140, 6, 12, color: Remarkable::RmPage::Colour::BLACK)
    # @return [void]
    def regular_polygon_outline(page, cx, cy, radius, sides, width, rotation: 0,
                                rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      polygon_outline(page, regular_polygon_points(cx, cy, radius, sides, rotation:), width, rgba:, color:, brush:)
    end

    # Draws a filled regular polygon using a triangle fan from the center.
    #
    # @param colors [Array<Integer, Array<Integer>, Hash>]
    # @example Ruby lambda
    #   Remarkable::Shapes.regular_polygon_fill(page, 1060, 850, 140, 6, colors: [0xFFFF6600, 0xFF00AAFF, 0xFF7A4DFF])
    # @return [void]
    def regular_polygon_fill(page, cx, cy, radius, sides, colors:, rotation: 0, brush: DEFAULT_BRUSH)
      raise ArgumentError, "colors must not be empty" if colors.nil? || colors.empty?

      vertices = regular_polygon_points(cx, cy, radius, sides, rotation:)
      polygon_fill(page, vertices, colors:, brush:)
    end

    # Draws a striped flag pattern using an array of colour or RGBA values.
    #
    # @param colors [Array<Integer, Array<Integer>, Hash>] stripe colours
    # @example Ruby lambda
    #   Remarkable::Shapes.striped_flag(page, 200, 200, 1000, 666, :top_to_bottom, 2, colors: [Remarkable::RmPage::Colour::WHITE, Remarkable::RmPage::Colour::RED])
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

    # Simple point struct used by parallelogram geometry helpers.
    Point = Struct.new(:x, :y, keyword_init: true)

    # Returns the midpoint between two points.
    #
    # @return [Point]
    def midpoint(a, b)
      Point.new(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
    end

    # Returns the Euclidean distance between two points.
    #
    # @return [Float]
    def distance(a, b)
      Math.hypot(a.x - b.x, a.y - b.y)
    end

    # Projects point q onto the line through a and b.
    #
    # @return [Point]
    def project(q, a, b)
      vx = b.x - a.x
      vy = b.y - a.y
      t = ((q.x - a.x) * vx + (q.y - a.y) * vy) / (vx * vx + vy * vy)
      Point.new(x: a.x + (t * vx), y: a.y + (t * vy))
    end

    # Draws a filled parallelogram using two right triangles and a center band.
    #
    # @param a [Point, Array<Numeric>]
    # @param b [Point, Array<Numeric>]
    # @param c [Point, Array<Numeric>]
    # @param d [Point, Array<Numeric>]
    # @example Ruby lambda
    #   Remarkable::Shapes.parallelogram(page, [150, 1120], [310, 1450], [620, 1450], [460, 1120], color: Remarkable::RmPage::Colour::CYAN)
    # @return [void]
    def parallelogram(page, a, b, c, d, rgba: DEFAULT_RGBA, color: DEFAULT_COLOR, brush: DEFAULT_BRUSH)
      a = to_point(a)
      b = to_point(b)
      c = to_point(c)
      d = to_point(d)

      p1 = project(b, a, d)
      p2 = project(d, b, c)
      m1 = midpoint(b, p1)
      m2 = midpoint(d, p2)
      band_width = distance(b, p1)

      right_triangle(page, a.x, a.y, p1.x, p1.y, b.x, b.y, rgba:, color:, brush:)
      right_triangle(page, c.x, c.y, p2.x, p2.y, d.x, d.y, rgba:, color:, brush:)
      rect(page, m1.x, m1.y, m2.x, m2.y, band_width, rgba:, color:, brush:)
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

    # Draws a shared constant-width two-point stroke shape.
    #
    # This is useful for highlighter-backed filled strokes where the tapered
    # zero-width endpoints are not needed and a clean rectangular end cap looks
    # better on-device and in export.
    #
    # @return [void]
    def draw_constant_segment(line, x1, y1, x2, y2, width)
      line.thickness_scale = width.to_f
      line.add_point(x1, y1).width = width
      line.add_point(x2, y2).width = width
    end

    # Converts a Point or two-value array into a Point.
    #
    # @return [Point]
    def to_point(value)
      return value if value.is_a?(Point)

      Point.new(x: value[0].to_f, y: value[1].to_f)
    end
  end
end

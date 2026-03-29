require_relative "../io/rm_page"

module Remarkable
  module Shapes
    RIGHT = 0
    DOWN = Math::PI / 2
    LEFT = Math::PI
    UP = 3 * Math::PI / 2

    module_function

    def rm2_box(page)
      draw_box(page, 130, 130, 1270, 1740, 4, Remarkable::IO::RmPage::Colour::BLACK)
    end

    def draw_box(page, x1, y1, x2, y2, width, color)
      line = page.add_line
      line.brush_type = Remarkable::IO::RmPage::Pen::FINELINER_2
      line.color = color
      [[x1, y1], [x2, y1], [x2, y2], [x1, y2], [x1, y1]].each do |x, y|
        line.add_point(x, y).width = width
      end
    end

    def draw_line(page, x1, y1, x2, y2, width, color)
      line = page.add_line
      line.brush_type = Remarkable::IO::RmPage::Pen::FINELINER_2
      line.color = color
      line.add_point(x1, y1).width = width
      line.add_point(x2, y2).width = width
    end

    def rect(page, x1, y1, x2, y2, width, color, brush = Remarkable::IO::RmPage::Pen::FINELINER_2)
      line = page.add_line
      line.brush_type = brush
      line.color = color

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

    def rect_pen(page, x1, y1, x2, y2, width, brush, color)
      rect(page, x1, y1, x2, y2, width, color, brush)
    end

    def circle(page, color, cx, cy, radius)
      line = page.add_line
      line.brush_type = Remarkable::IO::RmPage::Pen::FINELINER_2
      line.color = color
      line.add_point(cx, cy).width = radius * 2
      line.add_point(cx + 0.001, cy + 0.001).width = radius * 2
    end

    def circle_shader(page, rgba, cx, cy, radius)
      line = page.add_line
      line.brush_type = Remarkable::IO::RmPage::Pen::SHADER
      line.color = Remarkable::IO::RmPage::Colour::RGBA
      line.rgba = rgba
      line.add_point(cx, cy).width = radius * 2
      line.add_point(cx + 0.001, cy + 0.001).width = radius * 2
    end

    def semicircle(page, color, cx, cy, radius, angle)
      line = page.add_line
      line.brush_type = Remarkable::IO::RmPage::Pen::FINELINER_2
      line.color = color
      eps = 0.001
      dx = Math.cos(angle) * eps
      dy = Math.sin(angle) * eps
      line.add_point(cx - dx, cy - dy).width = 0
      line.add_point(cx + dx, cy + dy).width = radius * 2
    end

    def triangle(page, ax, ay, bx, by, width, color)
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
      line.brush_type = Remarkable::IO::RmPage::Pen::FINELINER_2
      line.color = color
      line.add_point(px, py).width = 0
      line.add_point(bx, by).width = width
      line.add_point(ax, ay).width = 0
    end

    def right_triangle(page, ax, ay, bx, by, cx, cy, color)
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
      triangle(page, ax, ay, m1x, m1y, w1, color)

      t2 = 1.0 - (dbc / dac)
      p2x = ax + t2 * hx
      p2y = ay + t2 * hy
      m2x = (bx + p2x) / 2.0
      m2y = (by + p2y) / 2.0
      w2 = Math.hypot(p2x - bx, p2y - by)
      triangle(page, cx, cy, m2x, m2y, w2, color)
    end

    def stars(page, colors, points, wide_point_percent, width, cx, cy, radius, rotation = 0, brush = Remarkable::IO::RmPage::Pen::FINELINER_2)
      arms = generate_star_lines(cx, cy, radius, points, wide_point_percent, width, rotation)
      points.times do |arm|
        line = page.add_line
        line.brush_type = brush
        line.color = colors[arm % colors.length]
        3.times do |p|
          line.add_point(arms[arm][p][0], arms[arm][p][1]).width = arms[arm][p][2]
        end
      end
    end

    def generate_star_lines(cx, cy, radius, points, wide_point_percent, width_at_wide_point, rotation_degrees)
      result = Array.new(points) { Array.new(3) { Array.new(3, 0.0) } }
      t = wide_point_percent / 100.0
      r_wide = radius * t
      final_width = if width_at_wide_point.negative?
                      2.0 * r_wide * Math.tan(Math::PI / points) * 1.005
                    else
                      width_at_wide_point
                    end
      rotation = rotation_degrees * Math::PI / 180.0
      start_angle = (-90 * Math::PI / 180.0) + rotation

      points.times do |i|
        angle = start_angle + i * (2 * Math::PI / points)
        result[i][0] = [cx, cy, 0.0]
        result[i][1] = [cx + r_wide * Math.cos(angle), cy + r_wide * Math.sin(angle), final_width]
        result[i][2] = [cx + radius * Math.cos(angle), cy + radius * Math.sin(angle), 0.0]
      end
      result
    end

    def striped_flag(page, x, y, width, height, direction, stripe_count, percentages, colors, brush = nil)
      raise ArgumentError, "stripe_count must be > 0" if stripe_count <= 0
      raise ArgumentError, "Not enough colors for stripes" if colors.nil? || colors.length < stripe_count

      brush ||= Remarkable::IO::RmPage::Pen::FINELINER_2
      total_length = direction == :left_to_right ? width : height
      stripe_lengths = Array.new(stripe_count, 0.0)

      used_fraction = 0.0
      provided = percentages.nil? ? 0 : [percentages.length, stripe_count].min
      provided.times do |i|
        stripe_lengths[i] = total_length * (percentages[i] / 100.0)
        used_fraction += percentages[i] / 100.0
      end

      remaining = stripe_count - provided
      if remaining.positive?
        each = total_length * (1.0 - used_fraction) / remaining
        provided.upto(stripe_count - 1) { |i| stripe_lengths[i] = each }
      end

      offset = 0.0
      stripe_count.times do |i|
        unless colors[i] == -1
          if direction == :left_to_right
            cx1 = x + offset
            cx2 = cx1 + stripe_lengths[i]
            cy = y + height / 2.0
            rect_pen(page, cx1, cy, cx2, cy, height, brush, colors[i])
          else
            cy1 = y + offset
            cy2 = cy1 + stripe_lengths[i]
            cx = x + width / 2.0
            rect_pen(page, cx, cy1, cx, cy2, width, brush, colors[i])
          end
        end
        offset += stripe_lengths[i]
      end
    end
  end
end

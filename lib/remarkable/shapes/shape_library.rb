require_relative "shapes"

module Remarkable
  module ShapeLibrary
    module_function

    TABLET_COLOURS = [
      IO::RmPage::Colour::BLACK,
      IO::RmPage::Colour::GREY,
      IO::RmPage::Colour::HIGHLIGHTER_YELLOW,
      IO::RmPage::Colour::HIGHLIGHTER_GREEN,
      IO::RmPage::Colour::HIGHLIGHTER_PINK,
      IO::RmPage::Colour::BLUE,
      IO::RmPage::Colour::RED,
      IO::RmPage::Colour::HIGHLIGHTER_GREY,
      IO::RmPage::Colour::GREEN,
      IO::RmPage::Colour::CYAN,
      IO::RmPage::Colour::MAGENTA,
      IO::RmPage::Colour::YELLOW
    ].freeze

    TABLET_SHADER_RGBAS = [
      1_075_912_220,
      1_295_010_528,
      1_718_932_200,
      1_724_002_610,
      1_945_823_001,
      1_946_071_552,
      2_157_042_289,
      2_160_099_282
    ].freeze

    RAINBOW_RGBAS = [
      0xFFFF0000,
      0xFFFF6600,
      0xFFFFCC00,
      0xFFCCFF00,
      0xFF66FF00,
      0xFF00FF66,
      0xFF00FFCC,
      0xFF00CCFF,
      0xFF0066FF,
      0xFF6600FF,
      0xFFCC00FF,
      0xFFFF0099
    ].freeze

    def draw_shape_sampler(page)
      Shapes.draw_box(page, 120, 120, 1280, 1740, 3, IO::RmPage::Colour::BLACK)
      Shapes.circle(page, IO::RmPage::Colour::RED, 280, 280, 70)
      Shapes.circle_shader(page, 0xFF223344, 500, 280, 70)
      Shapes.semicircle(page, IO::RmPage::Colour::BLUE, 720, 280, 70, Shapes::RIGHT)
      Shapes.rect(page, 880, 240, 1160, 240, 80, IO::RmPage::Colour::YELLOW)
      Shapes.triangle(page, 180, 560, 360, 650, 120, IO::RmPage::Colour::GREEN)
      Shapes.right_triangle(page, 520, 500, 520, 700, 760, 700, IO::RmPage::Colour::MAGENTA)
      Shapes.stars(page, [IO::RmPage::Colour::BLACK], 5, 31, -1, 1020, 620, 120, 0)
    end

    def draw_us_flag(page)
      Shapes.rm2_box(page)
      magic = 200
      w = 1270 + 130 - magic - magic
      ratio = 650.0 / 1235.0
      h = w * ratio

      Shapes.draw_box(page, magic, magic, magic + w, magic + h, 5, IO::RmPage::Colour::GREY)
      Shapes.striped_flag(
        page, magic, magic, w, h, :top_to_bottom, 13, nil,
        [
          IO::RmPage::Colour::RED, IO::RmPage::Colour::WHITE,
          IO::RmPage::Colour::RED, IO::RmPage::Colour::WHITE,
          IO::RmPage::Colour::RED, IO::RmPage::Colour::WHITE,
          IO::RmPage::Colour::RED, IO::RmPage::Colour::WHITE,
          IO::RmPage::Colour::RED, IO::RmPage::Colour::WHITE,
          IO::RmPage::Colour::RED, IO::RmPage::Colour::WHITE,
          IO::RmPage::Colour::RED
        ]
      )

      canton = h * 7.0 / 13.0
      cx2 = magic + (w * 0.20)
      cw = w * 0.40
      cy1 = magic
      cy2 = magic + canton
      Shapes.rect(page, cx2, cy1, cx2, cy2, cw, IO::RmPage::Colour::BLUE)

      dx = w * 0.06667
      dy = h * 0.10769
      star_radius = h * 0.030

      start_x_outer = magic + (w * 0.03333)
      start_y_outer = magic + (h * 0.05385)
      5.times do |row|
        6.times do |col|
          Shapes.stars(
            page, [IO::RmPage::Colour::WHITE], 5, 31, -1,
            start_x_outer + col * dx,
            start_y_outer + row * dy,
            star_radius
          )
        end
      end

      start_x_inner = magic + (w * 0.06667)
      start_y_inner = magic + (h * 0.10769)
      4.times do |row|
        5.times do |col|
          Shapes.stars(
            page, [IO::RmPage::Colour::WHITE], 5, 31, -1,
            start_x_inner + col * dx,
            start_y_inner + row * dy,
            star_radius
          )
        end
      end
    end

    def draw_greenland_flag(page)
      Shapes.rm2_box(page)
      magic = 200
      w = 1270 + 130 - magic - magic
      ratio = 600.0 / 900.0
      h = w * ratio

      Shapes.draw_box(page, magic, magic, magic + w, magic + h, 5, IO::RmPage::Colour::GREY)
      Shapes.striped_flag(
        page, magic, magic, w, h, :top_to_bottom, 2, nil,
        [IO::RmPage::Colour::WHITE, IO::RmPage::Colour::RED]
      )

      center_x = magic + (w / 3.0)
      center_y = magic + (h / 2.0)
      sc_radius = h / 3.0
      Shapes.semicircle(page, IO::RmPage::Colour::RED, center_x, center_y, sc_radius, Shapes::UP)
      Shapes.semicircle(page, IO::RmPage::Colour::WHITE, center_x, center_y, sc_radius, Shapes::DOWN)
    end

    def draw_color_sampler(page)
      Shapes.rm2_box(page)

      left_x = 170
      right_x = 725
      top_y = 185
      group_width = 470
      group_height = 475
      row_gap = 35

      draw_colour_group(page, left_x, top_y, group_width, group_height,
                        TABLET_COLOURS, IO::RmPage::Pen::FINELINER_2, false)
      draw_colour_group(page, right_x, top_y, group_width, group_height,
                        TABLET_COLOURS, IO::RmPage::Pen::HIGHLIGHTER_2, false)

      second_row_y = top_y + group_height + row_gap
      draw_colour_group(page, left_x, second_row_y, group_width, group_height,
                        TABLET_SHADER_RGBAS, IO::RmPage::Pen::SHADER, true)
      draw_colour_group(page, right_x, second_row_y, group_width, group_height,
                        RAINBOW_RGBAS, IO::RmPage::Pen::SHADER, true)

      third_row_y = second_row_y + group_height + row_gap
      draw_colour_group(page, left_x, third_row_y, group_width, group_height,
                        RAINBOW_RGBAS, IO::RmPage::Pen::FINELINER_2, true)
      draw_colour_group(page, right_x, third_row_y, group_width, group_height,
                        RAINBOW_RGBAS, IO::RmPage::Pen::HIGHLIGHTER_2, true)
    end

    def draw_colour_group(page, x, y, width, height, colours, brush, use_rgba)
      Shapes.draw_box(page, x, y, x + width, y + height, 2, IO::RmPage::Colour::GREY)

      line_count = colours.length
      top_margin = 18.0
      bottom_margin = 18.0
      line_length = width - 70.0
      x1 = x + 35.0
      x2 = x1 + line_length
      step = (height - top_margin - bottom_margin) / (line_count - 1).to_f
      stroke_width = brush == IO::RmPage::Pen::HIGHLIGHTER_2 ? 16.0 : 12.0

      colours.each_with_index do |value, index|
        y_pos = y + top_margin + (index * step)
        if use_rgba
          Shapes.draw_line_rgba(page, x1, y_pos, x2, y_pos, stroke_width, brush, value)
        else
          Shapes.draw_line_pen(page, x1, y_pos, x2, y_pos, stroke_width, brush, value)
        end
      end
    end
  end
end

require_relative "../shapes/shapes"

module Remarkable
  module Scenes
    module FlagScenes
      module_function

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
    end
  end
end


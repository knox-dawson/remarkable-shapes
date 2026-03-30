# frozen_string_literal: true

require_relative "shapes"

module Remarkable
  # Named output shapes built from the generic drawing helpers.
  module ShapeLibrary
    TABLET_COLOURS = [
      RmPage::Colour::BLACK,
      RmPage::Colour::GREY,
      RmPage::Colour::HIGHLIGHTER_YELLOW,
      RmPage::Colour::HIGHLIGHTER_GREEN,
      RmPage::Colour::HIGHLIGHTER_PINK,
      RmPage::Colour::BLUE,
      RmPage::Colour::RED,
      RmPage::Colour::HIGHLIGHTER_GREY,
      RmPage::Colour::GREEN,
      RmPage::Colour::CYAN,
      RmPage::Colour::MAGENTA,
      RmPage::Colour::YELLOW
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

    module_function

    # Draws the original shape sampler page.
    #
    # @param page [Remarkable::RmPage]
    # @return [void]
    def draw_shape_sampler(page)
      Shapes.draw_box(page, 120, 120, 1280, 1740, 3, color: RmPage::Colour::BLACK)
      Shapes.circle(page, 280, 280, 70, color: RmPage::Colour::RED)
      Shapes.circle(page, 500, 280, 70, rgba: 0xFF223344, brush: RmPage::Pen::SHADER)
      Shapes.semicircle(page, 720, 280, 70, Shapes::RIGHT, color: RmPage::Colour::BLUE)
      Shapes.rect(page, 880, 240, 1160, 240, 80, color: RmPage::Colour::YELLOW)
      Shapes.triangle(page, 180, 560, 360, 650, 120, color: RmPage::Colour::GREEN)
      Shapes.right_triangle(page, 520, 500, 520, 700, 760, 700, color: RmPage::Colour::MAGENTA)
      Shapes.stars(page, 1020, 620, 120, 5, 31, -1, color: RmPage::Colour::BLACK)
    end

    # Draws the United States flag.
    #
    # @param page [Remarkable::RmPage]
    # @return [void]
    def draw_us_flag(page)
      Shapes.rm2_box(page, color: RmPage::Colour::BLACK)
      magic = 200
      width = 1270 + 130 - magic - magic
      ratio = 650.0 / 1235.0
      height = width * ratio

      Shapes.draw_box(page, magic, magic, magic + width, magic + height, 5, color: RmPage::Colour::GREY)
      Shapes.striped_flag(
        page, magic, magic, width, height, :top_to_bottom, 13,
        colors: [
          RmPage::Colour::RED, RmPage::Colour::WHITE,
          RmPage::Colour::RED, RmPage::Colour::WHITE,
          RmPage::Colour::RED, RmPage::Colour::WHITE,
          RmPage::Colour::RED, RmPage::Colour::WHITE,
          RmPage::Colour::RED, RmPage::Colour::WHITE,
          RmPage::Colour::RED, RmPage::Colour::WHITE,
          RmPage::Colour::RED
        ]
      )

      canton = height * 7.0 / 13.0
      canton_x = magic + (width * 0.20)
      canton_width = width * 0.40
      Shapes.rect(page, canton_x, magic, canton_x, magic + canton, canton_width, color: RmPage::Colour::BLUE)

      dx = width * 0.06667
      dy = height * 0.10769
      star_radius = height * 0.030

      start_x_outer = magic + (width * 0.03333)
      start_y_outer = magic + (height * 0.05385)
      5.times do |row|
        6.times do |col|
          Shapes.stars(
            page,
            start_x_outer + (col * dx),
            start_y_outer + (row * dy),
            star_radius,
            5,
            31,
            -1,
            color: RmPage::Colour::WHITE
          )
        end
      end

      start_x_inner = magic + (width * 0.06667)
      start_y_inner = magic + (height * 0.10769)
      4.times do |row|
        5.times do |col|
          Shapes.stars(
            page,
            start_x_inner + (col * dx),
            start_y_inner + (row * dy),
            star_radius,
            5,
            31,
            -1,
            color: RmPage::Colour::WHITE
          )
        end
      end
    end

    # Draws the Greenland flag.
    #
    # @param page [Remarkable::RmPage]
    # @return [void]
    def draw_greenland_flag(page)
      Shapes.rm2_box(page, color: RmPage::Colour::BLACK)
      magic = 200
      width = 1270 + 130 - magic - magic
      ratio = 600.0 / 900.0
      height = width * ratio

      Shapes.draw_box(page, magic, magic, magic + width, magic + height, 5, color: RmPage::Colour::GREY)
      Shapes.striped_flag(
        page, magic, magic, width, height, :top_to_bottom, 2,
        colors: [RmPage::Colour::WHITE, RmPage::Colour::RED]
      )

      center_x = magic + (width / 3.0)
      center_y = magic + (height / 2.0)
      radius = height / 3.0
      Shapes.semicircle(page, center_x, center_y, radius, Shapes::UP, color: RmPage::Colour::RED)
      Shapes.semicircle(page, center_x, center_y, radius, Shapes::DOWN, color: RmPage::Colour::WHITE)
    end

    # Draws the colour capability sampler.
    #
    # @param page [Remarkable::RmPage]
    # @return [void]
    def draw_color_sampler(page)
      Shapes.rm2_box(page, color: RmPage::Colour::BLACK)

      left_x = 170
      right_x = 725
      top_y = 185
      group_width = 470
      group_height = 475
      row_gap = 35

      draw_colour_group(page, left_x, top_y, group_width, group_height, TABLET_COLOURS, RmPage::Pen::FINELINER_2, false)
      draw_colour_group(page, right_x, top_y, group_width, group_height, TABLET_COLOURS, RmPage::Pen::HIGHLIGHTER_2, false)

      second_row_y = top_y + group_height + row_gap
      draw_colour_group(page, left_x, second_row_y, group_width, group_height, TABLET_SHADER_RGBAS, RmPage::Pen::SHADER, true)
      draw_colour_group(page, right_x, second_row_y, group_width, group_height, RAINBOW_RGBAS, RmPage::Pen::SHADER, true)

      third_row_y = second_row_y + group_height + row_gap
      draw_colour_group(page, left_x, third_row_y, group_width, group_height, RAINBOW_RGBAS, RmPage::Pen::FINELINER_2, true)
      draw_colour_group(page, right_x, third_row_y, group_width, group_height, RAINBOW_RGBAS, RmPage::Pen::HIGHLIGHTER_2, true)
    end

    # Draws one grouped set of colour sample lines.
    #
    # @return [void]
    def draw_colour_group(page, x, y, width, height, colours, brush, use_rgba)
      Shapes.draw_box(page, x, y, x + width, y + height, 2, color: RmPage::Colour::GREY)

      line_count = colours.length
      top_margin = 18.0
      bottom_margin = 18.0
      line_length = width - 70.0
      x1 = x + 35.0
      x2 = x1 + line_length
      step = (height - top_margin - bottom_margin) / (line_count - 1).to_f
      stroke_width = brush == RmPage::Pen::HIGHLIGHTER_2 ? 16.0 : 12.0

      colours.each_with_index do |value, index|
        y_pos = y + top_margin + (index * step)
        style = use_rgba ? { rgba: value } : { color: value }
        Shapes.draw_line(page, x1, y_pos, x2, y_pos, stroke_width, brush:, **style)
      end
    end

    # Draws a PNG-backed RGBA grid at a chosen location and scale.
    #
    # @return [void]
    def draw_png_shape(page, png_path, x, y, pixel_size, brush: RmPage::Pen::FINELINER_2, gap: 0.0)
      rgba_grid = Shapes.png_to_rgba_grid(png_path)
      Shapes.draw_rgba_grid(page, rgba_grid, x, y, pixel_size, gap:, brush:)
    end

    # Draws the test cat PNG centered inside the standard page box.
    #
    # @param page [Remarkable::RmPage]
    # @return [void]
    def draw_cat_png(page)
      Shapes.rm2_box(page, color: RmPage::Colour::BLACK)

      png_path = File.expand_path("../../examples/cat.png", __dir__)
      rgba_grid = Shapes.png_to_rgba_grid(png_path)
      pixel_size = 6.0
      box_left = 130.0
      box_top = 130.0
      box_width = 1270.0 - 130.0
      box_height = 1740.0 - 130.0
      grid_width = rgba_grid.first.length * pixel_size
      grid_height = rgba_grid.length * pixel_size
      x = box_left + ((box_width - grid_width) / 2.0)
      y = box_top + ((box_height - grid_height) / 2.0)

      Shapes.draw_rgba_grid(page, rgba_grid, x, y, pixel_size, brush: RmPage::Pen::FINELINER_2)
    end
  end
end

# frozen_string_literal: true

lambda do |page|
  Remarkable::Shapes.rm2_box(page, color: Remarkable::RmPage::Colour::BLACK)
  magic = 200
  width = 1270 + 130 - magic - magic
  ratio = 650.0 / 1235.0
  height = width * ratio

  Remarkable::Shapes.draw_box(page, magic, magic, magic + width, magic + height, 5, color: Remarkable::RmPage::Colour::GREY)
  Remarkable::Shapes.striped_flag(
    page, magic, magic, width, height, :top_to_bottom, 13,
    colors: [
      Remarkable::RmPage::Colour::RED, Remarkable::RmPage::Colour::WHITE,
      Remarkable::RmPage::Colour::RED, Remarkable::RmPage::Colour::WHITE,
      Remarkable::RmPage::Colour::RED, Remarkable::RmPage::Colour::WHITE,
      Remarkable::RmPage::Colour::RED, Remarkable::RmPage::Colour::WHITE,
      Remarkable::RmPage::Colour::RED, Remarkable::RmPage::Colour::WHITE,
      Remarkable::RmPage::Colour::RED, Remarkable::RmPage::Colour::WHITE,
      Remarkable::RmPage::Colour::RED
    ]
  )

  canton = height * 7.0 / 13.0
  canton_x = magic + (width * 0.20)
  canton_width = width * 0.40
  Remarkable::Shapes.rect(page, canton_x, magic, canton_x, magic + canton, canton_width, color: Remarkable::RmPage::Colour::BLUE)

  dx = width * 0.06667
  dy = height * 0.10769
  star_radius = height * 0.030

  start_x_outer = magic + (width * 0.03333)
  start_y_outer = magic + (height * 0.05385)
  5.times do |row|
    6.times do |col|
      Remarkable::Shapes.stars(
        page,
        start_x_outer + (col * dx),
        start_y_outer + (row * dy),
        star_radius,
        5,
        31,
        -1,
        color: Remarkable::RmPage::Colour::WHITE
      )
    end
  end

  start_x_inner = magic + (width * 0.06667)
  start_y_inner = magic + (height * 0.10769)
  4.times do |row|
    5.times do |col|
      Remarkable::Shapes.stars(
        page,
        start_x_inner + (col * dx),
        start_y_inner + (row * dy),
        star_radius,
        5,
        31,
        -1,
        color: Remarkable::RmPage::Colour::WHITE
      )
    end
  end
end

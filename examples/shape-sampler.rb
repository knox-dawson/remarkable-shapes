# frozen_string_literal: true

lambda do |page|
  Remarkable::Shapes.draw_box(page, 120, 120, 1280, 1740, 3, color: Remarkable::RmPage::Colour::BLACK)
  Remarkable::Shapes.circle(page, 280, 280, 70, color: Remarkable::RmPage::Colour::RED)
  Remarkable::Shapes.circle(page, 500, 280, 70, rgba: 0xFF223344, brush: Remarkable::RmPage::Pen::SHADER)
  Remarkable::Shapes.semicircle(page, 720, 280, 70, Remarkable::Shapes::RIGHT, color: Remarkable::RmPage::Colour::BLUE)
  Remarkable::Shapes.rect(page, 880, 240, 1160, 240, 80, color: Remarkable::RmPage::Colour::YELLOW)
  Remarkable::Shapes.triangle(page, 180, 560, 360, 650, 120, color: Remarkable::RmPage::Colour::GREEN)
  Remarkable::Shapes.right_triangle(page, 520, 500, 520, 700, 760, 700, color: Remarkable::RmPage::Colour::MAGENTA)
  Remarkable::Shapes.stars(page, 1020, 620, 120, 5, 31, -1, color: Remarkable::RmPage::Colour::BLACK)
end

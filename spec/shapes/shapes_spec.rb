# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe Remarkable::Shapes do
  let(:page) { Remarkable::RmPage.new }

  it "stores RGBA styling when the default RGBA color mode is used" do
    described_class.circle(page, 10, 20, 5, rgba: 0xFF112233, brush: Remarkable::RmPage::Pen::SHADER)

    line = page.lines.first
    expect(line.brush_type).to eq(Remarkable::RmPage::Pen::SHADER)
    expect(line.color).to eq(Remarkable::RmPage::Colour::RGBA)
    expect(line.rgba).to eq(0xFF112233)
  end

  it "stores a tablet colour code when one is provided" do
    described_class.draw_line(page, 0, 0, 10, 10, 3, color: Remarkable::RmPage::Colour::RED)

    line = page.lines.first
    expect(line.color).to eq(Remarkable::RmPage::Colour::RED)
    expect(line.brush_type).to eq(Remarkable::RmPage::Pen::FINELINER_2)
  end

  it "skips fully transparent cells in an rgba grid" do
    grid = [
      [0x00000000, 0xFFFF0000],
      [0xFF00FF00, 0x00000000]
    ]

    described_class.draw_rgba_grid(page, grid, 100, 200, 10)

    expect(page.lines.length).to eq(2)
    expect(page.lines.map(&:rgba)).to contain_exactly(0xFFFF0000, 0xFF00FF00)
  end
end

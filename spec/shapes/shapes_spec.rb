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
    expect(line.thickness_scale).to eq(10.0)
    expect(line.points.map(&:width)).to eq([10.0, 10.0])
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

  it "uses -3.0 as the default rgba grid gap" do
    described_class.draw_rgba_grid(page, [[0xFFFFFFFF]], 100, 200, 10)

    expect(page.lines.length).to eq(1)
    expect(page.lines.first.points.map(&:width)).to eq([13.0, 13.0])
  end

  it "raises for an empty rgba grid" do
    expect do
      described_class.draw_rgba_grid(page, [], 100, 200, 10)
    end.to raise_error(ArgumentError, /must not be empty/)
  end

  it "raises when pixel_size is not greater than gap" do
    expect do
      described_class.draw_rgba_grid(page, [[0xFFFFFFFF]], 100, 200, 10, gap: 10)
    end.to raise_error(ArgumentError, /greater than gap/)
  end

  it "does not draw a polyline with fewer than two points" do
    described_class.draw_polyline(page, [[10, 20]], 3)

    expect(page.lines).to be_empty
  end

  it "builds an antialiased rgba grid for filled circles" do
    grid = described_class.circle_rgba_grid(7, rgba: 0xFFFF0000, antialias_samples: 4)

    expect(grid.length).to eq(7)
    expect(grid.first.length).to eq(7)
    expect(grid[3][3]).to eq(0xFFFF0000)
    expect(grid[0][0]).to eq(0x00000000)
  end

  it "builds an rgba grid for outlined rectangles" do
    grid = described_class.rectangle_rgba_grid(
      6,
      4,
      rgba: 0xFF00FF00,
      outline_rgba: 0xFFFF0000,
      outline_width_pixels: 1
    )

    expect(grid[0][0]).to eq(0xFFFF0000)
    expect(grid[2][2]).to eq(0xFF00FF00)
  end

  it "draws highlighter rectangles as constant-width two-point strokes with explicit thickness" do
    described_class.rect(page, 10, 20, 110, 20, 18, brush: Remarkable::RmPage::Pen::HIGHLIGHTER_2, rgba: 0xFF334455)

    line = page.lines.first
    expect(line.brush_type).to eq(Remarkable::RmPage::Pen::HIGHLIGHTER_2)
    expect(line.thickness_scale).to eq(18.0)
    expect(line.points.length).to eq(2)
    expect(line.points.map(&:width)).to eq([18, 18])
  end

  it "keeps tapered four-point rectangles for non-highlighter brushes" do
    described_class.rect(page, 10, 20, 110, 20, 18, brush: Remarkable::RmPage::Pen::FINELINER_2)

    line = page.lines.first
    expect(line.brush_type).to eq(Remarkable::RmPage::Pen::FINELINER_2)
    expect(line.thickness_scale).to eq(1.0)
    expect(line.points.length).to eq(4)
    expect(line.points.first.width).to eq(0)
    expect(line.points.last.width).to eq(0)
  end

  it "draws clipped-corner boxes as closed constant-width polylines" do
    described_class.draw_box_corners(page, 10, 20, 110, 120, 5, 12, color: Remarkable::RmPage::Colour::BLACK)

    line = page.lines.first
    expect(line.points.length).to eq(9)
    expect(line.thickness_scale).to eq(5.0)
  end

  it "draws alternating-colour stars" do
    described_class.stars_colored(page, 100, 100, 40, 5, 31, -1, colors: [Remarkable::RmPage::Colour::RED, Remarkable::RmPage::Colour::BLUE])

    expect(page.lines.length).to eq(5)
    expect(page.lines.map(&:color)).to eq([
      Remarkable::RmPage::Colour::RED,
      Remarkable::RmPage::Colour::BLUE,
      Remarkable::RmPage::Colour::RED,
      Remarkable::RmPage::Colour::BLUE,
      Remarkable::RmPage::Colour::RED
    ])
  end

  it "draws regular polygon outlines" do
    described_class.regular_polygon_outline(page, 100, 100, 40, 6, 4, color: Remarkable::RmPage::Colour::BLACK)

    line = page.lines.first
    expect(line.points.length).to eq(7)
    expect(line.thickness_scale).to eq(4.0)
  end

  it "draws filled regular polygons as triangle fans" do
    described_class.regular_polygon_fill(page, 100, 100, 40, 5, colors: [Remarkable::RmPage::Colour::RED, Remarkable::RmPage::Colour::BLUE])

    expect(page.lines.length).to eq(5)
    expect(page.lines.map(&:color)).to eq([
      Remarkable::RmPage::Colour::RED,
      Remarkable::RmPage::Colour::BLUE,
      Remarkable::RmPage::Colour::RED,
      Remarkable::RmPage::Colour::BLUE,
      Remarkable::RmPage::Colour::RED
    ])
  end

  it "draws parallelograms from four points" do
    described_class.parallelogram(page, [10, 20], [50, 50], [120, 50], [80, 20], color: Remarkable::RmPage::Colour::GREEN)

    expect(page.lines.length).to eq(5)
  end
end

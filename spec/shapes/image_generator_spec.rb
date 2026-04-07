# frozen_string_literal: true

require "tmpdir"

require_relative "../spec_helper"
require "shapes/image_generator"

RSpec.describe Remarkable::ImageGenerator do
  it "computes a layout inside the standard page bounds near the top" do
    layout = described_class.layout_for_image(100, 50)

    expect(layout[:x]).to be >= described_class::BOX_LEFT
    expect(layout[:y]).to eq(described_class::BOX_TOP + described_class::DEFAULT_TOP_PADDING)
    expect(layout[:x] + layout[:width]).to be <= described_class::BOX_RIGHT
    expect(layout[:y] + layout[:height]).to be <= described_class::BOX_BOTTOM
    expect(layout[:pixel_size]).to be > 0
  end

  it "raises for non-positive image dimensions" do
    expect do
      described_class.layout_for_image(0, 50)
    end.to raise_error(ArgumentError, /must be positive/)
  end

  it "draws a png onto the page without needing the rm2 box" do
    Dir.mktmpdir do |dir|
      png_path = File.join(dir, "tiny.png")
      image = ChunkyPNG::Image.new(2, 2, ChunkyPNG::Color::TRANSPARENT)
      image[0, 0] = ChunkyPNG::Color.rgba(255, 0, 0, 255)
      image[1, 1] = ChunkyPNG::Color.rgba(0, 0, 255, 255)
      image.save(png_path)

      page = Remarkable::RmPage.new
      layout = described_class.draw_png(page, png_path)

      expect(layout[:y]).to eq(described_class::BOX_TOP + described_class::DEFAULT_TOP_PADDING)
      expect(page.lines.length).to eq(2)
    end
  end

  it "uses -3.0 as the default pixel gap for png rendering" do
    Dir.mktmpdir do |dir|
      png_path = File.join(dir, "tiny.png")
      image = ChunkyPNG::Image.new(1, 1, ChunkyPNG::Color.rgba(255, 0, 0, 255))
      image.save(png_path)

      page = Remarkable::RmPage.new
      layout = described_class.draw_png(page, png_path)

      expected_width = layout[:pixel_size] - described_class::DEFAULT_PIXEL_GAP
      expect(described_class::DEFAULT_PIXEL_GAP).to eq(-3.0)
      expect(page.lines.first.points.map(&:width)).to eq([expected_width, expected_width])
    end
  end
end

# frozen_string_literal: true

require "tmpdir"

require_relative "../spec_helper"

RSpec.describe Remarkable::PngShapePageGenerator do
  it "parses row and column layouts" do
    expect(described_class.parse_layout("3x5")).to eq([3, 5])
  end

  it "generates one or more local shape files from a png directory" do
    Dir.mktmpdir do |dir|
      image_dir = File.join(dir, "images")
      output_dir = File.join(dir, "pages")
      Dir.mkdir(image_dir)

      2.times do |index|
        image = ChunkyPNG::Image.new(10 + index, 12 + index, ChunkyPNG::Color.rgba(255, 0, 0, 255))
        image.save(File.join(image_dir, "image-#{index + 1}.png"))
      end

      generated = described_class.generate(image_dir:, layout: "1x1", output_dir:, prefix: "emoji")

      expect(generated.length).to eq(2)
      expect(File.read(generated.first)).to include("Remarkable::ShapeLibrary.draw_png_shape")
    end
  end
end

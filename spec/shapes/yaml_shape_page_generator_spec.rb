# frozen_string_literal: true

require "tmpdir"

require_relative "../spec_helper"

RSpec.describe Remarkable::YamlShapePageGenerator do
  it "parses row and column layouts" do
    expect(described_class.parse_layout("3x5")).to eq([3, 5])
  end

  it "rejects malformed layouts" do
    expect do
      described_class.parse_layout("3-by-5")
    end.to raise_error(ArgumentError, /must look like 3x5/i)
  end

  it "rejects zero-sized layouts" do
    expect do
      described_class.parse_layout("0x5")
    end.to raise_error(ArgumentError, /must be positive/)
  end

  it "generates one or more yaml page files from a png directory" do
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
      expect(File.read(generated.first)).to include("type: image")
    end
  end

  it "raises when no png files are present" do
    Dir.mktmpdir do |dir|
      image_dir = File.join(dir, "images")
      output_dir = File.join(dir, "pages")
      Dir.mkdir(image_dir)

      expect do
        described_class.generate(image_dir:, layout: "1x1", output_dir:)
      end.to raise_error(ArgumentError, /No PNG files found/)
    end
  end

  it "builds page files with relative png paths and yaml image objects" do
    Dir.mktmpdir do |dir|
      images_dir = File.join(dir, "images")
      output_dir = File.join(dir, "pages")
      Dir.mkdir(images_dir)
      image_path = File.join(images_dir, "one.png")

      image = ChunkyPNG::Image.new(10, 12, ChunkyPNG::Color.rgba(255, 0, 0, 255))
      image.save(image_path)

      page_file = described_class.build_page_file(
        File.join(output_dir, "emoji-01.yml"),
        [image_path],
        rows: 1,
        cols: 1,
        outer_padding: 40,
        cell_gap: 30,
        pixel_gap: -0.10,
        brush: Remarkable::RmPage::Pen::SHADER
      )

      expect(page_file).to include('path: "../images/one.png"')
      expect(page_file).to include("brush: shader")
      expect(page_file).to include("gap: -0.1")
    end
  end
end

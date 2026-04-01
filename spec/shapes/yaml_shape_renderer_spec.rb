# frozen_string_literal: true

require "tmpdir"

require_relative "../spec_helper"
require "shapes/yaml_shape_renderer"

RSpec.describe Remarkable::YamlShapeRenderer do
  let(:page) { Remarkable::RmPage.new }

  it "resolves a top-placed canvas inside the standard page box" do
    layout = described_class.resolve_canvas_layout(
      "width" => 600,
      "height" => 400,
      "placement" => "top"
    )

    expect(layout[:x]).to be > 0
    expect(layout[:y]).to eq(0)
    expect(layout[:tablet]).to eq("rm2")
  end

  it "resolves the rmpro physical canvas preset" do
    layout = described_class.resolve_canvas_layout(
      "tablet" => "rmpro",
      "placement" => "top-left"
    )

    expect(layout[:width]).to eq(1620.0)
    expect(layout[:height]).to eq(2160.0)
    expect(layout[:physical_width]).to eq(1620.0)
    expect(layout[:physical_height]).to eq(2160.0)
    expect(layout[:x]).to eq(0.0)
    expect(layout[:y]).to eq(0.0)
  end

  it "allows a logical canvas larger than the physical tablet canvas" do
    layout = described_class.resolve_canvas_layout(
      "tablet" => "rm2",
      "width" => 2000,
      "height" => 2500,
      "placement" => "center"
    )

    expect(layout[:x]).to be < 0
    expect(layout[:y]).to be < 0
  end

  it "renders generic shape objects from a config hash" do
    config = {
      "canvas" => { "width" => 800, "height" => 500, "placement" => "center" },
      "objects" => [
        { "type" => "circle_fill", "x" => 20, "y" => 30, "width" => 100, "height" => 100, "color" => "red" },
        { "type" => "rectangle_outline", "x" => 150, "y" => 40, "width" => 180, "height" => 80, "stroke_width" => 5, "rgba" => "0xFF112233" },
        { "type" => "line", "x1" => 10, "y1" => 200, "x2" => 300, "y2" => 220, "stroke_width" => 6, "color" => "blue" }
      ]
    }

    described_class.render(page, config)

    expect(page.lines.length).to eq(3)
    expect(page.lines.map(&:brush_type).uniq).to eq([Remarkable::RmPage::Pen::FINELINER_2])
  end

  it "renders image objects relative to the yaml file location" do
    Dir.mktmpdir do |dir|
      png_path = File.join(dir, "tiny.png")
      image = ChunkyPNG::Image.new(2, 2, ChunkyPNG::Color::TRANSPARENT)
      image[0, 0] = ChunkyPNG::Color.rgba(255, 0, 0, 255)
      image.save(png_path)

      yaml_path = File.join(dir, "page.yml")
      File.write(
        yaml_path,
        <<~YAML
          canvas:
            width: 400
            height: 300
            placement: top-left
          objects:
            - type: image
              path: tiny.png
              x: 20
              y: 30
              width: 100
              height: 100
        YAML
      )

      described_class.render_file(page, yaml_path)

      expect(page.lines.length).to eq(1)
    end
  end

  it "rejects unsupported object types" do
    expect do
      described_class.render(page, { "objects" => [{ "type" => "triangle" }] })
    end.to raise_error(ArgumentError, /unsupported object type/)
  end

  it "renders star and regular polygon objects" do
    config = {
      "canvas" => { "width" => 900, "height" => 600, "placement" => "top-left" },
      "objects" => [
        { "type" => "star", "x" => 20, "y" => 20, "width" => 120, "height" => 120, "points" => 5, "colors" => ["red", "blue"] },
        { "type" => "regular_polygon_outline", "x" => 180, "y" => 20, "width" => 120, "height" => 120, "sides" => 6, "stroke_width" => 5, "color" => "black" },
        { "type" => "regular_polygon_fill", "x" => 340, "y" => 20, "width" => 120, "height" => 120, "sides" => 5, "colors" => ["0xFFFF0000", "0xFF0000FF"] }
      ]
    }

    described_class.render(page, config)

    expect(page.lines.length).to eq(11)
  end

  it "renders freeform polygon and parallelogram objects" do
    config = {
      "canvas" => { "width" => 900, "height" => 600, "placement" => "top-left" },
      "objects" => [
        { "type" => "polygon_outline", "points" => [[10, 10], [90, 10], [70, 80], [20, 60]], "stroke_width" => 4, "color" => "black" },
        { "type" => "parallelogram", "points" => [[140, 20], [180, 60], [280, 60], [240, 20]], "color" => "green" }
      ]
    }

    described_class.render(page, config)

    expect(page.lines.length).to eq(6)
  end
end

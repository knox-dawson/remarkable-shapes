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
        { "type" => "star", "x" => 20, "y" => 20, "width" => 120, "height" => 120, "point_count" => 5, "colors" => ["red", "blue"] },
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

  it "renders a nested yaml object scaled into its box" do
    Dir.mktmpdir do |dir|
      child_path = File.join(dir, "child.yml")
      File.write(
        child_path,
        <<~YAML
          canvas:
            width: 200
            height: 100
            placement: top-left
          objects:
            - type: rectangle_outline
              x: 0
              y: 0
              width: 200
              height: 100
              stroke_width: 4
              color: black
            - type: line
              x1: 0
              y1: 0
              x2: 200
              y2: 100
              stroke_width: 4
              color: red
        YAML
      )

      parent_path = File.join(dir, "parent.yml")
      File.write(
        parent_path,
        <<~YAML
          canvas:
            width: 400
            height: 300
            placement: top-left
          objects:
            - type: yaml
              path: child.yml
              x: 50
              y: 60
              width: 120
              height: 120
        YAML
      )

      described_class.render_file(page, parent_path)

      expect(page.lines.length).to eq(2)
      xs = page.lines.flat_map { |line| line.points.map(&:x) }
      ys = page.lines.flat_map { |line| line.points.map(&:y) }
      expect(xs.min).to be >= 50
      expect(ys.min).to be >= 60
      expect(xs.max).to be <= 170
      expect(ys.max).to be <= 180
    end
  end

  it "renders wrapped text inside a box" do
    config = {
      "canvas" => { "width" => 500, "height" => 300, "placement" => "top-left" },
      "objects" => [
        {
          "type" => "text",
          "x" => 20,
          "y" => 20,
          "width" => 180,
          "height" => 140,
          "text" => "This is a wrapped text example for the yaml renderer.",
          "size" => 24,
          "stroke_width" => 2,
          "wrap" => true,
          "align" => "left",
          "valign" => "top",
          "color" => "black"
        }
      ]
    }

    described_class.render(page, config)

    expect(page.lines).not_to be_empty
    ys = page.lines.flat_map { |line| line.points.map(&:y) }
    expect(ys.max - ys.min).to be > 24
  end

  it "uses pixel_gap for image pixel spacing" do
    Dir.mktmpdir do |dir|
      png_path = File.join(dir, "tiny.png")
      image = ChunkyPNG::Image.new(2, 1, ChunkyPNG::Color::TRANSPARENT)
      image[0, 0] = ChunkyPNG::Color.rgba(255, 0, 0, 255)
      image[1, 0] = ChunkyPNG::Color.rgba(0, 0, 255, 255)
      image.save(png_path)

      config = {
        "canvas" => { "width" => 300, "height" => 200, "placement" => "top-left" },
        "objects" => [
          {
            "type" => "image",
            "path" => png_path,
            "x" => 20,
            "y" => 20,
            "width" => 100,
            "height" => 100,
            "pixel_gap" => -0.2
          }
        ]
      }

      described_class.render(page, config)

      expect(page.lines.length).to eq(2)
    end
  end

  it "renders circles from center_x, center_y, and radius" do
    config = {
      "objects" => [
        {
          "type" => "circle_outline_fill",
          "center_x" => 200,
          "center_y" => 240,
          "radius" => 60,
          "stroke_width" => 6,
          "fill_color" => "yellow",
          "outline_color" => "black"
        }
      ]
    }

    described_class.render(page, config)

    expect(page.lines.length).to eq(2)
  end

  it "renders semicircles from rotation as an alternative to direction" do
    config = {
      "objects" => [
        {
          "type" => "semicircle_fill",
          "center_x" => 300,
          "center_y" => 320,
          "radius" => 50,
          "rotation" => 90,
          "color" => "blue"
        }
      ]
    }

    described_class.render(page, config)

    expect(page.lines.length).to eq(1)
    expect(page.lines.first.points.length).to eq(2)
  end

  it "renders box-based and outline triangle variants" do
    config = {
      "canvas" => { "width" => 900, "height" => 600, "placement" => "top-left" },
      "objects" => [
        {
          "type" => "isosceles_triangle_fill",
          "x" => 20,
          "y" => 20,
          "width" => 120,
          "height" => 100,
          "direction" => "right",
          "color" => "green"
        },
        {
          "type" => "isosceles_triangle_outline_fill",
          "x" => 180,
          "y" => 20,
          "width" => 120,
          "height" => 100,
          "direction" => "down",
          "stroke_width" => 5,
          "fill_color" => "yellow",
          "outline_color" => "black"
        },
        {
          "type" => "right_triangle_outline_fill",
          "x" => 340,
          "y" => 20,
          "width" => 120,
          "height" => 100,
          "rotation" => 90,
          "stroke_width" => 5,
          "fill_color" => "cyan",
          "outline_color" => "blue"
        }
      ]
    }

    described_class.render(page, config)

    expect(page.lines.length).to eq(11)
  end

  it "renders regular_polygon_outline_fill with direction and alternating fill colors" do
    config = {
      "canvas" => { "width" => 600, "height" => 400, "placement" => "top-left" },
      "objects" => [
        {
          "type" => "regular_polygon_outline_fill",
          "x" => 40,
          "y" => 40,
          "width" => 140,
          "height" => 140,
          "sides" => 6,
          "direction" => "horizontal",
          "stroke_width" => 6,
          "colors" => ["red", "blue"],
          "outline_color" => "black"
        }
      ]
    }

    described_class.render(page, config)

    expect(page.lines.length).to eq(7)
  end

  it "allows the expanded pen list through brush names" do
    config = {
      "objects" => [
        {
          "type" => "rectangle_fill",
          "x" => 20,
          "y" => 20,
          "width" => 120,
          "height" => 60,
          "color" => "red",
          "brush" => "ballpoint_2"
        }
      ]
    }

    described_class.render(page, config)

    expect(page.lines.length).to eq(1)
    expect(page.lines.first.brush_type).to eq(Remarkable::RmPage::Pen::BALLPOINT_2)
  end
end

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

  it "resolves grid metadata inside a margined canvas" do
    layout = described_class.resolve_canvas_layout(
      "tablet" => "rm2",
      "margin" => 40,
      "grid" => {
        "size" => "2x2",
        "cell_padding" => 12,
        "gutter" => 20
      }
    )

    expect(layout[:content_x]).to eq(40.0)
    expect(layout[:content_y]).to eq(40.0)
    expect(layout[:content_width]).to eq(1324.0)
    expect(layout[:content_height]).to eq(1792.0)
    expect(layout[:grid][:rows]).to eq(2)
    expect(layout[:grid][:cols]).to eq(2)
    expect(layout[:grid][:cell_padding]).to eq(12.0)
    expect(layout[:grid][:gutter]).to eq(20.0)
  end

  it "resolves percentage-based grid row_sizes and column_sizes" do
    layout = described_class.resolve_canvas_layout(
      "width" => 400,
      "height" => 300,
      "placement" => "top-left",
      "grid" => {
        "size" => "2x2",
        "row_sizes" => "10% 90%",
        "column_sizes" => "25% 75%"
      }
    )

    expect(layout[:grid][:column_widths]).to eq([100.0, 300.0])
    expect(layout[:grid][:row_heights]).to eq([30.0, 270.0])
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

  it "uses -3.0 as the default pixel_gap for image objects" do
    Dir.mktmpdir do |dir|
      png_path = File.join(dir, "tiny.png")
      image = ChunkyPNG::Image.new(1, 1, ChunkyPNG::Color.rgba(255, 0, 0, 255))
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
            "height" => 100
          }
        ]
      }

      described_class.render(page, config)

      expect(page.lines.length).to eq(1)
      expect(page.lines.first.brush_type).to eq(Remarkable::RmPage::Pen::HIGHLIGHTER_2)
      expect(page.lines.first.points.map(&:width).max).to eq(103.0)
    end
  end

  it "raises a clear error when a non-cell object omits box geometry" do
    config = {
      "objects" => [
        {
          "type" => "rectangle_fill",
          "color" => "red"
        }
      ]
    }

    expect do
      described_class.render(page, config)
    end.to raise_error(ArgumentError, /not placed in a grid cell must provide x, y, width, and height/)
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

    expect(page.lines.length).to eq(6)
  end

  it "fits rotated box-based right triangles inside their target box" do
    box = { x: 100.0, y: 200.0, width: 120.0, height: 80.0, center_x: 160.0, center_y: 240.0 }

    points = described_class.box_triangle_points(box, mode: :right, rotation: 90)

    expect(points).to match_array([[220.0, 200.0], [100.0, 200.0], [100.0, 280.0]])
  end

  it "supports named directions for box-based right triangles" do
    config = {
      "canvas" => { "width" => 400, "height" => 300, "placement" => "top-left" },
      "objects" => [
        {
          "type" => "right_triangle_outline",
          "x" => 100,
          "y" => 80,
          "width" => 120,
          "height" => 100,
          "direction" => "upper-right",
          "stroke_width" => 5,
          "color" => "black"
        }
      ]
    }

    described_class.render(page, config)

    points = page.lines.first.points.map { |point| [point.x.round(6), point.y.round(6)] }.uniq
    expect(points).to include([220.0, 80.0])
    expect(points).to include([100.0, 80.0])
    expect(points).to include([220.0, 180.0])
  end

  it "fits downward box-based isosceles triangles inside their target box" do
    box = { x: 300.0, y: 400.0, width: 120.0, height: 100.0, center_x: 360.0, center_y: 450.0 }

    points = described_class.box_triangle_points(box, mode: :isosceles, rotation: 180)

    expect(points).to match_array([[360.0, 500.0], [300.0, 400.0], [420.0, 400.0]])
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

  it "draws one border box per grid cell when a grid border is configured" do
    config = {
      "canvas" => {
        "grid" => {
          "size" => "2x2",
          "border" => {
            "stroke_width" => 5,
            "color" => "black"
          }
        }
      },
      "objects" => []
    }

    described_class.render(page, config)

    expect(page.lines.length).to eq(4)
  end

  it "draws annotation borders and text for each grid cell" do
    config = {
      "canvas" => {
        "width" => 300,
        "height" => 220,
        "placement" => "top-left",
        "grid" => {
          "size" => "2x2",
          "annotations" => {
            "border" => {
              "stroke_width" => 5,
              "color" => "black"
            },
            "text" => {
              "size" => 12,
              "stroke_width" => 1,
              "color" => "grey",
              "padding" => 6
            }
          }
        }
      },
      "objects" => []
    }

    described_class.render(page, config)

    expect(page.lines.length).to be > 4
    expect(page.lines.first.points.length).to eq(5)
    expect(page.lines.first.thickness_scale).to eq(5.0)
  end

  it "does not draw annotations when show is false" do
    config = {
      "canvas" => {
        "width" => 300,
        "height" => 220,
        "placement" => "top-left",
        "grid" => {
          "size" => "2x2",
          "annotations" => {
            "show" => false,
            "border" => {
              "stroke_width" => 5,
              "color" => "black"
            },
            "text" => {
              "size" => 12,
              "stroke_width" => 1,
              "color" => "grey",
              "padding" => 6
            }
          }
        }
      },
      "objects" => []
    }

    described_class.render(page, config)

    expect(page.lines).to be_empty
  end

  it "places box-capable objects into grid cells" do
    config = {
      "canvas" => {
        "margin" => 40,
        "grid" => {
          "size" => "2x2",
          "cell_padding" => 10,
          "gutter" => 20
        }
      },
      "objects" => [
        {
          "type" => "circle_fill",
          "cell" => "cell1",
          "placement" => "top-left",
          "color" => "red"
        },
        {
          "type" => "rectangle_outline",
          "cell" => "r2c2",
          "stroke_width" => 6,
          "color" => "black"
        }
      ]
    }

    described_class.render(page, config)

    expect(page.lines.length).to eq(2)
    xs = page.lines.flat_map { |line| line.points.map(&:x) }
    ys = page.lines.flat_map { |line| line.points.map(&:y) }
    expect(xs.min).to be >= 50
    expect(ys.min).to be >= 50
  end

  it "defaults cell-based text objects to wrap" do
    config = {
      "canvas" => {
        "width" => 300,
        "height" => 220,
        "placement" => "top-left",
        "grid" => "1x1"
      },
      "objects" => [
        {
          "type" => "text",
          "cell" => 1,
          "text" => "This is a wrapped text example for a narrow grid cell.",
          "size" => 24,
          "stroke_width" => 2,
          "color" => "black"
        }
      ]
    }

    described_class.render(page, config)

    ys = page.lines.flat_map { |line| line.points.map(&:y) }
    expect(ys.max - ys.min).to be > 24
  end

  it "rejects duplicate cell assignments" do
    config = {
      "canvas" => { "grid" => "2x2" },
      "objects" => [
        { "type" => "rectangle_fill", "cell" => 1, "color" => "red" },
        { "type" => "circle_fill", "cell" => "cell1", "color" => "blue" }
      ]
    }

    expect do
      described_class.render(page, config)
    end.to raise_error(ArgumentError, /already used/)
  end

  it "rejects mixing cell placement with explicit geometry" do
    config = {
      "canvas" => { "grid" => "2x2" },
      "objects" => [
        { "type" => "rectangle_fill", "cell" => 1, "x" => 20, "color" => "red" }
      ]
    }

    expect do
      described_class.render(page, config)
    end.to raise_error(ArgumentError, /cannot be combined/)
  end
end

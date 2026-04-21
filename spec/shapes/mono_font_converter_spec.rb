# frozen_string_literal: true

require "json"
require "tmpdir"

require_relative "../spec_helper"
require "shapes/mono_font_converter"

RSpec.describe Remarkable::MonoFontConverter do
  it "normalizes glyphs into a fixed mono cell and centers narrow glyphs" do
    Dir.mktmpdir do |dir|
      input_path = File.join(dir, "plain.json")
      output_path = File.join(dir, "mono.json")

      File.write(
        input_path,
        JSON.pretty_generate(
          "W" => {
            "width" => 1.0,
            "strokes" => [
              [[0.0, 0.0], [1.0, 0.0]]
            ]
          },
          "i" => {
            "width" => 0.2,
            "strokes" => [
              [[0.1, 0.0], [0.1, 1.0]]
            ]
          },
          " " => {
            "width" => 0.5,
            "strokes" => []
          }
        )
      )

      described_class.new(input_path, output_path, target_width: 0.85).convert
      output = JSON.parse(File.read(output_path))

      expect(output["W"]["width"]).to eq(0.85)
      expect(output["W"]["strokes"].flatten(1).map(&:first)).to all(be_between(0.0, 0.85))
      expect(output["i"]["width"]).to eq(0.85)
      expect(output["i"]["strokes"].flatten(1).map(&:first).uniq).to eq([0.425])
      expect(output[" "]["width"]).to eq(0.85)
      expect(output[" "]["strokes"]).to eq([])
    end
  end

  it "supports per-glyph width caps and optical centering offsets" do
    Dir.mktmpdir do |dir|
      input_path = File.join(dir, "plain.json")
      output_path = File.join(dir, "mono.json")

      File.write(
        input_path,
        JSON.pretty_generate(
          "W" => {
            "width" => 1.0,
            "strokes" => [
              [[0.0, 0.0], [1.0, 0.0]]
            ]
          },
          "1" => {
            "width" => 1.0,
            "strokes" => [
              [[0.4, 0.0], [0.4, 1.0]]
            ]
          }
        )
      )

      described_class.new(
        input_path,
        output_path,
        target_width: 0.85,
        adjustments: {
          "W" => { max_width: 0.6 },
          "1" => { x_offset: -0.1 }
        }
      ).convert
      output = JSON.parse(File.read(output_path))

      expect(output["W"]["strokes"].flatten(1).map(&:first)).to eq([0.125, 0.725])
      expect(output["1"]["strokes"].flatten(1).map(&:first).uniq).to eq([0.325])
    end
  end
end

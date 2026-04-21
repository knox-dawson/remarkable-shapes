# frozen_string_literal: true

require "fileutils"
require "json"

module Remarkable
  # Converts a stroke font JSON file into a monospaced variant.
  class MonoFontConverter
    DEFAULT_TARGET_WIDTH = 0.85
    DEFAULT_ROUND_DIGITS = 6

    def initialize(input_path, output_path, target_width: DEFAULT_TARGET_WIDTH, round_digits: DEFAULT_ROUND_DIGITS)
      @input_path = File.expand_path(input_path)
      @output_path = File.expand_path(output_path)
      @target_width = target_width.to_f
      @round_digits = [round_digits.to_i, 0].max
    end

    def convert
      source = JSON.parse(File.read(@input_path))
      converted = source.each_with_object({}) do |(char, glyph), result|
        result[char] = convert_glyph(glyph)
      end

      FileUtils.mkdir_p(File.dirname(@output_path))
      File.write(@output_path, JSON.pretty_generate(converted))
    end

    private

    def convert_glyph(glyph)
      strokes = Array(glyph.fetch("strokes", []))
      bounds = x_bounds(strokes)

      if bounds.nil?
        return {
          "width" => round_float(@target_width),
          "strokes" => strokes
        }
      end

      xmin, xmax = bounds
      width = xmax - xmin
      scale = width <= 0.0 ? 1.0 : [@target_width / width, 1.0].min
      scaled_width = width * scale
      offset = (@target_width - scaled_width) / 2.0

      {
        "width" => round_float(@target_width),
        "strokes" => strokes.map { |stroke| transform_stroke(stroke, xmin, scale, offset) }
      }
    end

    def transform_stroke(stroke, xmin, scale, offset)
      Array(stroke).map do |point|
        x, y = point
        [
          round_float(((x.to_f - xmin) * scale) + offset),
          round_float(y.to_f)
        ]
      end
    end

    def x_bounds(strokes)
      xs = Array(strokes).flat_map { |stroke| Array(stroke).map { |point| point[0].to_f } }
      return nil if xs.empty?

      [xs.min, xs.max]
    end

    def round_float(value)
      value.round(@round_digits)
    end
  end
end

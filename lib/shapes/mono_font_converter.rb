# frozen_string_literal: true

require "fileutils"
require "json"

module Remarkable
  # Converts a stroke font JSON file into a monospaced variant.
  class MonoFontConverter
    DEFAULT_TARGET_WIDTH = 0.60
    DEFAULT_ROUND_DIGITS = 6
    GLYPH_ADJUSTMENTS = {
      "line_font/plain.json" => {
        "A" => { max_width: 0.46 },
        "M" => { max_width: 0.46 },
        "V" => { max_width: 0.46 },
        "W" => { max_width: 0.54 },
        "m" => { max_width: 0.58 },
        "w" => { max_width: 0.46 },
        "I" => { x_offset: -0.0025 },
        "J" => { x_offset: -0.0075 },
        "i" => { x_offset: -0.0025 },
        "j" => { x_offset: -0.0075 },
        "r" => { x_offset: -0.005 },
        "1" => { x_offset: -0.005 }
      },
      "relief_singleline/plain.json" => {
        "A" => { max_width: 0.5 },
        "M" => { max_width: 0.5 },
        "V" => { max_width: 0.47 },
        "W" => { max_width: 0.56 },
        "m" => { max_width: 0.54 },
        "w" => { max_width: 0.56 },
        "I" => { x_offset: -0.0025 },
        "J" => { x_offset: -0.00625 },
        "i" => { x_offset: -0.0025 },
        "j" => { x_offset: -0.00625 },
        "r" => { x_offset: -0.0045 },
        "1" => { x_offset: -0.0045 }
      }
    }.freeze

    def initialize(input_path, output_path, target_width: DEFAULT_TARGET_WIDTH, round_digits: DEFAULT_ROUND_DIGITS,
                   adjustments: nil)
      @input_path = File.expand_path(input_path)
      @output_path = File.expand_path(output_path)
      @target_width = target_width.to_f
      @round_digits = [round_digits.to_i, 0].max
      @adjustments = adjustments || GLYPH_ADJUSTMENTS.fetch(relative_input_key, {})
    end

    def convert
      source = JSON.parse(File.read(@input_path))
      converted = source.each_with_object({}) do |(char, glyph), result|
        result[char] = convert_glyph(char, glyph)
      end

      FileUtils.mkdir_p(File.dirname(@output_path))
      File.write(@output_path, JSON.pretty_generate(converted))
    end

    private

    def convert_glyph(char, glyph)
      strokes = Array(glyph.fetch("strokes", []))
      bounds = x_bounds(strokes)
      adjustment = @adjustments.fetch(char, {})

      if bounds.nil?
        return {
          "width" => round_float(@target_width),
          "strokes" => strokes
        }
      end

      xmin, xmax = bounds
      width = xmax - xmin
      max_width = [adjustment.fetch(:max_width, @target_width).to_f, @target_width].min
      scale = width <= 0.0 ? 1.0 : [max_width / width, 1.0].min
      scaled_width = width * scale
      centered_offset = (@target_width - scaled_width) / 2.0
      offset = centered_offset + adjustment.fetch(:x_offset, 0.0).to_f
      offset = [[offset, 0.0].max, @target_width - scaled_width].min

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

    def relative_input_key
      input_parts = @input_path.split(File::SEPARATOR)
      data_index = input_parts.rindex("data")
      return "" if data_index.nil?

      input_parts[(data_index + 1)..].join("/")
    end
  end
end

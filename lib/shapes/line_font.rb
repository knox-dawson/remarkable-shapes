# frozen_string_literal: true

require "json"

require_relative "shapes"

module Remarkable
  # Hershey-style vector line font renderer backed by imported glyph stroke data.
  module LineFont
    # Default rendered glyph size.
    DEFAULT_SIZE = 48.0
    # Default stroke width for rendered glyph paths.
    DEFAULT_STROKE_WIDTH = 2.0
    # Default font family.
    DEFAULT_FONT = :default
    # Alias for the built-in line_font directory.
    LINE_FONT_ALIAS = :line_font
    # Flattened built-in cursive family.
    LINE_FONT_CURSIVE = :line_font_cursive
    # Flattened built-in synthetic italic family.
    LINE_FONT_ITALIC = :line_font_italic
    # Flattened built-in mono family.
    LINE_FONT_MONO = :line_font_mono
    # Fallback monospaced advance as a fraction of glyph size.
    DEFAULT_MONO_ADVANCE_FACTOR = 0.85
    # Fallback advance as a fraction of glyph size for unsupported characters.
    FALLBACK_ADVANCE_FACTOR = 0.5

    DATA_ROOT = File.expand_path("../../data", __dir__)
    DEFAULT_DATA_ROOT = File.join(DATA_ROOT, "line_font")
    ROOT_DATA_FILES = {
      plain: File.join(DEFAULT_DATA_ROOT, "plain.json"),
    }.freeze
    # Pair-specific spacing tweaks for the generated synthetic italic family.
    ITALIC_PAIR_ADJUSTMENTS = {
      "ST" => 0.018,
      "UV" => 0.028,
      "VW" => 0.022,
      "XY" => 0.016,
      "ef" => 0.014,
      "st" => 0.022,
      "TU" => -0.018,
      "WX" => -0.018,
      "YZ" => -0.018,
      "12" => -0.024,
      "78" => -0.014,
      "ij" => -0.03,
      "wx" => -0.024
    }.freeze

    module_function

    # Draws a text string directly as reMarkable line strokes.
    #
    # @param page [Remarkable::RmPage]
    # @param text [String]
    # @param x [Numeric] left edge
    # @param baseline_y [Numeric] text baseline
    # @param size [Numeric] glyph scale
    # @param stroke_width [Numeric] line stroke width in page units
    # @param font [Symbol, String] font family key
    # @param rgba [Integer, Array<Integer>, Hash]
    # @param color [Integer]
    # @param brush [Integer]
    # @return [Float] rendered width
    def draw_text(page, text, x, baseline_y, size: DEFAULT_SIZE, stroke_width: DEFAULT_STROKE_WIDTH,
                  font: DEFAULT_FONT,
                  rgba: Shapes::DEFAULT_RGBA, color: Shapes::DEFAULT_COLOR, brush: Shapes::DEFAULT_BRUSH)
      cursor_x = x.to_f
      chars = text.each_char.to_a
      chars.each_with_index do |char, index|
        cursor_x += draw_character(
          page, char, cursor_x, baseline_y,
          size:, stroke_width:, font:, rgba:, color:, brush:
        )
        next_char = chars[index + 1]
        cursor_x += pair_spacing_adjustment(char, next_char, size:, font:) unless next_char.nil?
      end
      cursor_x - x.to_f
    end

    # Returns the width of a text string without drawing it.
    #
    # @return [Float]
    def text_width(text, size: DEFAULT_SIZE, font: DEFAULT_FONT)
      chars = text.each_char.to_a
      chars.each_with_index.sum do |char, index|
        advance = character_advance(char, size:, font:)
        next_char = chars[index + 1]
        advance + (next_char.nil? ? 0.0 : pair_spacing_adjustment(char, next_char, size:, font:))
      end
    end

    # Returns true when the glyph exists in the imported font data.
    #
    # @return [Boolean]
    def available?(char, font: DEFAULT_FONT)
      !glyph_for(char, font:).nil?
    end

    # Returns the glyph data for a character.
    #
    # @return [Hash, nil]
    def glyph_for(char, font: DEFAULT_FONT)
      char = char.to_s
      family = effective_font(font)
      glyph = glyph_data(family)&.[](char)
      return glyph unless glyph.nil?

      return nil if family == DEFAULT_FONT

      glyph_for(char, font: DEFAULT_FONT)
    end

    # Returns the monospaced glyph advance.
    #
    # @return [Float]
    def mono_advance(size, font: LINE_FONT_MONO)
      size.to_f * mono_width(font)
    end

    # Returns the baseline-to-top offset
    #
    # @return [Float]
    def baseline_to_top(size)
      -25.0 / 32.0 * size.to_f
    end

    # Draws one character and returns its advance width.
    #
    # @return [Float]
    def draw_character(page, char, x, baseline_y, size:, stroke_width:, font:, rgba:, color:, brush:)
      glyph = glyph_for(char, font:)
      family = effective_font(font)
      return fallback_advance(size, mono: mono_font?(family), font: family) if glyph.nil?

      glyph_width = size.to_f * glyph.fetch("width", 0.0).to_f
      x_offset = mono_font?(family) ? (mono_advance(size, font: family) - glyph_width) / 2.0 : 0.0
      glyph.fetch("strokes", []).each do |stroke|
        points = stroke.map do |px, py|
          [x + x_offset + (px.to_f * size.to_f), baseline_y + (py.to_f * size.to_f)]
        end
        Shapes.draw_polyline(page, points, stroke_width, rgba:, color:, brush:) if points.length >= 2
      end

      mono_font?(family) ? mono_advance(size, font: family) : glyph_width
    end

    # Returns the advance width for one character.
    #
    # @return [Float]
    def character_advance(char, size:, font:)
      glyph = glyph_for(char, font:)
      family = effective_font(font)
      return fallback_advance(size, mono: mono_font?(family), font: family) if glyph.nil?

      mono_font?(family) ? mono_advance(size, font: family) : (size.to_f * glyph.fetch("width", 0.0).to_f)
    end

    # Returns registered font families found under data/.
    #
    # @return [Array<Symbol>]
    def available_fonts
      families = Dir.children(DATA_ROOT)
                    .select { |entry| File.directory?(File.join(DATA_ROOT, entry)) }
                    .reject { |entry| entry == "line_font" }
                    .map { |entry| entry.to_sym }
                    .sort
      [DEFAULT_FONT, LINE_FONT_ALIAS, *families].uniq
    end

    # Loads glyph data for a family.
    #
    # @return [Hash, nil]
    def glyph_data(font)
      @glyph_data ||= {}
      key = normalize_font(font)
      return @glyph_data[key] if @glyph_data.key?(key)

      path = data_file_for(key)
      @glyph_data[key] = path && File.file?(path) ? JSON.parse(File.read(path)) : nil
    end

    def data_file_for(font)
      if [DEFAULT_FONT, LINE_FONT_ALIAS].include?(normalize_font(font))
        ROOT_DATA_FILES[:plain]
      elsif normalize_font(font) == LINE_FONT_CURSIVE
        File.join(DATA_ROOT, LINE_FONT_CURSIVE.to_s, "cursive.json")
      elsif normalize_font(font) == LINE_FONT_ITALIC
        File.join(DATA_ROOT, LINE_FONT_ITALIC.to_s, "italic.json")
      elsif mono_font?(normalize_font(font))
        mono_path = File.join(DATA_ROOT, normalize_font(font).to_s, "mono.json")
        return mono_path if File.file?(mono_path)

        File.join(DATA_ROOT, normalize_font(font).to_s, "plain.json")
      else
        File.join(DATA_ROOT, normalize_font(font).to_s, "plain.json")
      end
    end

    def normalize_font(font)
      value = font.to_s.strip
      return DEFAULT_FONT if value.empty?

      normalized = value.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
      return DEFAULT_FONT if normalized.empty?
      return LINE_FONT_ALIAS if normalized == "line_font"
      return LINE_FONT_CURSIVE if normalized == "line_font_cursive"
      return LINE_FONT_ITALIC if normalized == "line_font_italic"
      return LINE_FONT_MONO if normalized == "line_font_mono"
      normalized.to_sym
    end

    def effective_font(font)
      family = normalize_font(font)
      return LINE_FONT_ALIAS if [DEFAULT_FONT, LINE_FONT_ALIAS].include?(family)

      family
    end

    def mono_font?(font)
      normalize_font(font).to_s.end_with?("_mono")
    end

    def mono_width(font)
      normalized_font = normalize_font(font)
      @mono_widths ||= {}
      return @mono_widths[normalized_font] if @mono_widths.key?(normalized_font)

      widths = glyph_data(normalized_font)&.values&.map { |glyph| glyph.fetch("width", 0.0).to_f }&.select(&:positive?)
      @mono_widths[normalized_font] = widths&.max || DEFAULT_MONO_ADVANCE_FACTOR
    end

    def pair_spacing_adjustment(left_char, right_char, size:, font:)
      return 0.0 if left_char.nil? || right_char.nil?
      return 0.0 unless effective_font(font) == LINE_FONT_ITALIC

      size.to_f * ITALIC_PAIR_ADJUSTMENTS.fetch("#{left_char}#{right_char}", 0.0)
    end

    # Returns the fallback advance for unsupported characters.
    #
    # @return [Float]
    def fallback_advance(size, mono:, font: LINE_FONT_MONO)
      mono ? mono_advance(size, font:) : (size.to_f * FALLBACK_ADVANCE_FACTOR)
    end
  end
end

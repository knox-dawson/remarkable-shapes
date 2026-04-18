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
    # Flattened built-in mono family.
    LINE_FONT_MONO = :line_font_mono
    # Default glyph style.
    DEFAULT_STYLE = :plain
    # Monospaced advance as a fraction of glyph size.
    MONO_ADVANCE_FACTOR = 0.75
    # Fallback advance as a fraction of glyph size for unsupported characters.
    FALLBACK_ADVANCE_FACTOR = 0.5

    DATA_ROOT = File.expand_path("../../data", __dir__)
    DEFAULT_DATA_ROOT = File.join(DATA_ROOT, "line_font")
    ROOT_DATA_FILES = {
      plain: File.join(DEFAULT_DATA_ROOT, "plain.json")
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
    # @param style [Symbol] compatibility option; plain is preferred
    # @param font [Symbol, String] font family key
    # @param mono [Boolean] compatibility option; prefer font: :line_font_mono
    # @param rgba [Integer, Array<Integer>, Hash]
    # @param color [Integer]
    # @param brush [Integer]
    # @return [Float] rendered width
    def draw_text(page, text, x, baseline_y, size: DEFAULT_SIZE, stroke_width: DEFAULT_STROKE_WIDTH,
                  style: DEFAULT_STYLE, font: DEFAULT_FONT, mono: false,
                  rgba: Shapes::DEFAULT_RGBA, color: Shapes::DEFAULT_COLOR, brush: Shapes::DEFAULT_BRUSH)
      cursor_x = x.to_f
      text.each_char do |char|
        cursor_x += draw_character(
          page, char, cursor_x, baseline_y,
          size:, stroke_width:, style:, font:, mono:, rgba:, color:, brush:
        )
      end
      cursor_x - x.to_f
    end

    # Returns the width of a text string without drawing it.
    #
    # @return [Float]
    def text_width(text, size: DEFAULT_SIZE, style: DEFAULT_STYLE, font: DEFAULT_FONT, mono: false)
      text.each_char.sum { |char| character_advance(char, size:, style:, font:, mono:) }
    end

    # Returns true when the glyph exists in the imported font data.
    #
    # @return [Boolean]
    def available?(char, style: DEFAULT_STYLE, font: DEFAULT_FONT, mono: false)
      !glyph_for(char, style:, font:, mono:).nil?
    end

    # Returns the glyph data for a character.
    #
    # @return [Hash, nil]
    def glyph_for(char, style: DEFAULT_STYLE, font: DEFAULT_FONT, mono: false)
      char = char.to_s
      family = effective_font(font, style:, mono:)
      glyph = glyph_data(family)&.[](char)
      return glyph unless glyph.nil?

      return nil if family == DEFAULT_FONT

      glyph_for(char, font: DEFAULT_FONT)
    end

    # Returns the monospaced glyph advance.
    #
    # @return [Float]
    def mono_advance(size)
      size.to_f * MONO_ADVANCE_FACTOR
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
    def draw_character(page, char, x, baseline_y, size:, stroke_width:, style:, font:, mono:, rgba:, color:, brush:)
      glyph = glyph_for(char, style:, font:, mono:)
      return fallback_advance(size, mono: effective_mono?(font, style:, mono:)) if glyph.nil?

      glyph_width = size.to_f * glyph.fetch("width", 0.0).to_f
      x_offset = effective_mono?(font, style:, mono:) ? (mono_advance(size) - glyph_width) / 2.0 : 0.0
      glyph.fetch("strokes", []).each do |stroke|
        points = stroke.map do |px, py|
          [x + x_offset + (px.to_f * size.to_f), baseline_y + (py.to_f * size.to_f)]
        end
        Shapes.draw_polyline(page, points, stroke_width, rgba:, color:, brush:) if points.length >= 2
      end

      mono ? mono_advance(size) : glyph_width
    end

    # Returns the advance width for one character.
    #
    # @return [Float]
    def character_advance(char, size:, style:, font:, mono:)
      glyph = glyph_for(char, style:, font:, mono:)
      return fallback_advance(size, mono: effective_mono?(font, style:, mono:)) if glyph.nil?

      effective_mono?(font, style:, mono:) ? mono_advance(size) : (size.to_f * glyph.fetch("width", 0.0).to_f)
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
      elsif normalize_font(font) == LINE_FONT_MONO
        File.join(DATA_ROOT, LINE_FONT_MONO.to_s, "mono.json")
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
      return LINE_FONT_MONO if normalized == "line_font_mono"

      normalized.to_sym
    end

    def effective_font(font, style:, mono:)
      family = normalize_font(font)
      # TODO: Remove style/mono compatibility after the next beta release.
      return LINE_FONT_MONO if mono && [DEFAULT_FONT, LINE_FONT_ALIAS].include?(family)

      if [DEFAULT_FONT, LINE_FONT_ALIAS].include?(family)
        return LINE_FONT_CURSIVE if %i[cursive italic].include?(style.to_sym)
        return LINE_FONT_ALIAS
      end

      family
    end

    def effective_mono?(font, style:, mono:)
      effective_font(font, style:, mono:) == LINE_FONT_MONO
    end

    # Returns the fallback advance for unsupported characters.
    #
    # @return [Float]
    def fallback_advance(size, mono:)
      mono ? mono_advance(size) : (size.to_f * FALLBACK_ADVANCE_FACTOR)
    end
  end
end

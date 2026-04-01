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
    # Default glyph style.
    DEFAULT_STYLE = :plain
    # Monospaced advance as a fraction of glyph size.
    MONO_ADVANCE_FACTOR = 0.75
    # Fallback advance as a fraction of glyph size for unsupported characters.
    FALLBACK_ADVANCE_FACTOR = 0.5

    # Imported glyph data files by style.
    DATA_FILES = {
      plain: File.expand_path("../../data/line_font/plain.json", __dir__),
      italic: File.expand_path("../../data/line_font/italic.json", __dir__),
      mono: File.expand_path("../../data/line_font/mono.json", __dir__)
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
    # @param style [Symbol] :plain or :italic
    # @param mono [Boolean] use monospaced advance and overrides
    # @param rgba [Integer, Array<Integer>, Hash]
    # @param color [Integer]
    # @param brush [Integer]
    # @return [Float] rendered width
    def draw_text(page, text, x, baseline_y, size: DEFAULT_SIZE, stroke_width: DEFAULT_STROKE_WIDTH,
                  style: DEFAULT_STYLE, mono: false,
                  rgba: Shapes::DEFAULT_RGBA, color: Shapes::DEFAULT_COLOR, brush: Shapes::DEFAULT_BRUSH)
      cursor_x = x.to_f
      text.each_char do |char|
        cursor_x += draw_character(
          page, char, cursor_x, baseline_y,
          size:, stroke_width:, style:, mono:, rgba:, color:, brush:
        )
      end
      cursor_x - x.to_f
    end

    # Returns the width of a text string without drawing it.
    #
    # @return [Float]
    def text_width(text, size: DEFAULT_SIZE, style: DEFAULT_STYLE, mono: false)
      text.each_char.sum { |char| character_advance(char, size:, style:, mono:) }
    end

    # Returns true when the glyph exists in the imported font data.
    #
    # @return [Boolean]
    def available?(char, style: DEFAULT_STYLE, mono: false)
      !glyph_for(char, style:, mono:).nil?
    end

    # Returns the glyph data for a character.
    #
    # @return [Hash, nil]
    def glyph_for(char, style: DEFAULT_STYLE, mono: false)
      char = char.to_s
      if mono
        glyph = glyph_data(:mono)[char]
        return glyph unless glyph.nil?
      end

      style_key = style.to_sym
      glyph = glyph_data(style_key)[char] unless style_key == :plain
      return glyph unless glyph.nil?

      glyph_data(:plain)[char]
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
    def draw_character(page, char, x, baseline_y, size:, stroke_width:, style:, mono:, rgba:, color:, brush:)
      glyph = glyph_for(char, style:, mono:)
      return fallback_advance(size, mono:) if glyph.nil?

      glyph_width = size.to_f * glyph.fetch("width", 0.0).to_f
      x_offset = mono ? (mono_advance(size) - glyph_width) / 2.0 : 0.0
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
    def character_advance(char, size:, style:, mono:)
      glyph = glyph_for(char, style:, mono:)
      return fallback_advance(size, mono:) if glyph.nil?

      mono ? mono_advance(size) : (size.to_f * glyph.fetch("width", 0.0).to_f)
    end

    # Loads glyph data for a style.
    #
    # @return [Hash]
    def glyph_data(style)
      @glyph_data ||= {}
      @glyph_data[style] ||= JSON.parse(File.read(DATA_FILES.fetch(style)))
    end

    # Returns the fallback advance for unsupported characters.
    #
    # @return [Float]
    def fallback_advance(size, mono:)
      mono ? mono_advance(size) : (size.to_f * FALLBACK_ADVANCE_FACTOR)
    end
  end
end

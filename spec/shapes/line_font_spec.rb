# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe Remarkable::LineFont do
  let(:page) { Remarkable::RmPage.new }

  it "loads imported plain glyphs" do
    glyph = described_class.glyph_for("A")

    expect(glyph).not_to be_nil
    expect(glyph["width"]).to be > 0
    expect(glyph["strokes"]).not_to be_empty
  end

  it "draws text as line strokes on the page" do
    width = described_class.draw_text(page, "ABC", 100, 200, size: 40, stroke_width: 3)

    expect(width).to be > 0
    expect(page.lines.length).to be > 0
    expect(page.lines.all? { |line| line.points.length >= 2 }).to be(true)
  end

  it "supports flattened cursive, italic, mono, Noto outline, Noto filled, and Relief families" do
    cursive_width = described_class.text_width("Hello", size: 20, font: :line_font_cursive)
    italic_width = described_class.text_width("Hello", size: 20, font: :line_font_italic)
    mono_width = described_class.text_width("mm", size: 20, font: :line_font_mono)
    noto_width = described_class.text_width("Noto", size: 20, font: :noto_lines_mono)
    noto_filled_width = described_class.text_width("Noto", size: 20, font: :noto_lines_mono_filled)
    relief_italic_width = described_class.text_width("Relief", size: 20, font: :relief_singleline_italic)
    relief_mono_width = described_class.text_width("Relief", size: 20, font: :relief_singleline_mono)

    expect(cursive_width).to be > 0
    expect(italic_width).to be > 0
    expect(mono_width).to eq(described_class.mono_advance(20) * 2)
    expect(noto_width).to eq(described_class.mono_advance(20, font: :noto_lines_mono) * 4)
    expect(noto_filled_width).to eq(described_class.mono_advance(20, font: :noto_lines_mono_filled) * 4)
    expect(relief_italic_width).to be > 0
    expect(relief_mono_width).to be > 0
  end

  it "derives mono advance from the loaded mono family data" do
    original_mono_widths = described_class.instance_variable_get(:@mono_widths)
    begin
      described_class.instance_variable_set(:@mono_widths, {})
      allow(described_class).to receive(:glyph_data).and_call_original
      allow(described_class).to receive(:glyph_data).with(:line_font_mono).and_return(
        "A" => { "width" => 1.0, "strokes" => [] }
      )

      expect(described_class.mono_advance(10, font: :line_font_mono)).to eq(10.0)
    ensure
      described_class.instance_variable_set(:@mono_widths, original_mono_widths)
    end
  end

  it "uses mono advance while drawing explicit mono families" do
    width = described_class.draw_text(page, "ABC", 100, 200, size: 40, stroke_width: 3, font: :noto_lines_mono)

    expect(width).to be_within(0.000001).of(described_class.mono_advance(40, font: :noto_lines_mono) * 3)
    expect(page.lines).not_to be_empty
  end

  it "supports flattened font families explicitly" do
    relief_width = described_class.text_width("Relief", size: 20, font: "Relief-SingleLine")
    alias_width = described_class.text_width("Hello", size: 20, font: :line_font)

    expect(described_class.available_fonts).to include(:default, :line_font, :line_font_cursive, :line_font_italic, :line_font_mono, :noto_lines_mono, :noto_lines_mono_filled, :relief_singleline, :relief_singleline_italic, :relief_singleline_mono)
    expect(relief_width).to be > 0
    expect(alias_width).to eq(described_class.text_width("Hello", size: 20))
    expect(described_class.glyph_for("é", font: :relief_singleline)).not_to be_nil
    expect(described_class.glyph_for("é", font: :relief_singleline_italic)).not_to be_nil
    expect(described_class.glyph_for("é", font: :relief_singleline_mono)).not_to be_nil
  end

  it "applies pair-specific spacing tweaks for the synthetic italic family" do
    base_pair_width = described_class.character_advance("S", size: 20, font: :line_font_italic) +
                      described_class.character_advance("T", size: 20, font: :line_font_italic)
    tightened_pair_width = described_class.character_advance("T", size: 20, font: :line_font_italic) +
                           described_class.character_advance("U", size: 20, font: :line_font_italic)

    expect(described_class.text_width("ST", size: 20, font: :line_font_italic)).to be > base_pair_width
    expect(described_class.text_width("TU", size: 20, font: :line_font_italic)).to be < tightened_pair_width
  end
end

RSpec.describe Remarkable::Shapes do
  it "draws text through the shared shapes helper" do
    page = Remarkable::RmPage.new

    width = described_class.text(page, "Hello", 100, 200, size: 32, stroke_width: 2)

    expect(width).to be > 0
    expect(page.lines).not_to be_empty
  end

  it "draws shadow text and returns width including shadow extent" do
    page = Remarkable::RmPage.new

    width = described_class.shadow_text(page, "Hello", 100, 200, size: 32, stroke_width: 2, shadow_dx: 6, shadow_dy: 4)

    expect(width).to eq(described_class.text(page, "Hello", 100, 200, size: 32, stroke_width: 2) + 6)
    expect(page.lines).not_to be_empty
  end

  it "draws text through the shared helper with a selected font family" do
    page = Remarkable::RmPage.new

    width = described_class.text(page, "Relief", 100, 200, size: 32, stroke_width: 2, font: :relief_singleline)

    expect(width).to be > 0
    expect(page.lines).not_to be_empty
  end

  it "draws text through the shared helper with the synthetic Relief italic family" do
    page = Remarkable::RmPage.new

    width = described_class.text(page, "Relief", 100, 200, size: 32, stroke_width: 2, font: :relief_singleline_italic)

    expect(width).to be > 0
    expect(page.lines).not_to be_empty
  end
end

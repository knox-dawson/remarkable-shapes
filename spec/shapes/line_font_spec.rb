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

  it "supports italic and mono lookup paths" do
    italic_width = described_class.text_width("Hello", size: 20, style: :italic)
    mono_width = described_class.text_width("mm", size: 20, mono: true)

    expect(italic_width).to be > 0
    expect(mono_width).to eq(described_class.mono_advance(20) * 2)
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
end

# frozen_string_literal: true

require_relative "../spec_helper"
require "shapes/image_generator"

RSpec.describe Remarkable::ImageGenerator do
  it "computes a layout inside the standard page bounds near the top" do
    layout = described_class.layout_for_image(100, 50)

    expect(layout[:x]).to be >= described_class::BOX_LEFT
    expect(layout[:y]).to eq(described_class::BOX_TOP + described_class::DEFAULT_TOP_PADDING)
    expect(layout[:x] + layout[:width]).to be <= described_class::BOX_RIGHT
    expect(layout[:y] + layout[:height]).to be <= described_class::BOX_BOTTOM
    expect(layout[:pixel_size]).to be > 0
  end
end

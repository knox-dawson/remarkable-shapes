# frozen_string_literal: true

require "json"
require "tmpdir"

require_relative "../spec_helper"

RSpec.describe Remarkable::RmdocWriter do
  it "writes a zip-based rmdoc file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "test.rmdoc")
      described_class.write(path, "abc".b)

      data = File.binread(path)
      expect(File.exist?(path)).to be(true)
      expect(data.start_with?("PK\x03\x04".b)).to be(true)
    end
  end

  it "creates metadata with the visible name" do
    metadata = JSON.parse(described_class.create_metadata("demo"))
    expect(metadata["visibleName"]).to eq("demo")
    expect(metadata["type"]).to eq("DocumentType")
  end

  it "writes content metadata for the requested page size" do
    content = JSON.parse(described_class.create_content("notebook-id", "page-id", page_width: 1620, page_height: 2160))

    expect(content["customZoomPageWidth"]).to eq(1620)
    expect(content["customZoomPageHeight"]).to eq(2160)
    expect(content["customZoomCenterY"]).to eq(1080)
  end
end

# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe Remarkable::RmPage do
  def read_varuint(bytes, offset)
    shift = 0
    value = 0

    loop do
      byte = bytes.getbyte(offset)
      raise "unexpected end of data" unless byte

      offset += 1
      value |= (byte & 0x7F) << shift
      break if (byte & 0x80).zero?

      shift += 7
    end

    [value, offset]
  end

  def parse_tag(bytes, offset)
    value, offset = read_varuint(bytes, offset)
    [{ index: value >> 4, type: value & 0x0F }, offset]
  end

  def parse_blocks(bytes)
    offset = Remarkable::RmPage::HEADER_V6.bytesize
    blocks = []

    while offset < bytes.bytesize
      size = bytes.byteslice(offset, 4).unpack1("V")
      block = {
        size: size,
        reserved: bytes.getbyte(offset + 4),
        min_version: bytes.getbyte(offset + 5),
        current_version: bytes.getbyte(offset + 6),
        block_type: bytes.getbyte(offset + 7),
        data: bytes.byteslice(offset + 8, size)
      }
      blocks << block
      offset += 8 + size
    end

    blocks
  end

  def parse_subblock(bytes, offset, expected_index:)
    tag, offset = parse_tag(bytes, offset)
    expect(tag).to eq(index: expected_index, type: 0x0C)

    size = bytes.byteslice(offset, 4).unpack1("V")
    offset += 4

    [bytes.byteslice(offset, size), offset + size]
  end

  def skip_tagged_value(bytes, offset, expected_index:, expected_type:)
    tag, offset = parse_tag(bytes, offset)
    expect(tag).to eq(index: expected_index, type: expected_type)

    case expected_type
    when 0x0F
      _author, offset = bytes.unpack1("@#{offset}C"), offset + 1
      _value, offset = read_varuint(bytes, offset)
      offset
    when 0x04
      offset + 4
    else
      raise "unsupported tag type #{expected_type}"
    end
  end

  def read_tagged_id(bytes, offset, expected_index:)
    tag, offset = parse_tag(bytes, offset)
    expect(tag).to eq(index: expected_index, type: 0x0F)
    author = bytes.getbyte(offset)
    value, offset = read_varuint(bytes, offset + 1)
    [{ author:, value: }, offset]
  end

  def line_value_data(line_block)
    block_data = line_block[:data]
    offset = 0
    offset = skip_tagged_value(block_data, offset, expected_index: 1, expected_type: 0x0F)
    offset = skip_tagged_value(block_data, offset, expected_index: 2, expected_type: 0x0F)
    offset = skip_tagged_value(block_data, offset, expected_index: 3, expected_type: 0x0F)
    offset = skip_tagged_value(block_data, offset, expected_index: 4, expected_type: 0x0F)
    offset = skip_tagged_value(block_data, offset, expected_index: 5, expected_type: 0x04)

    value_data, = parse_subblock(block_data, offset, expected_index: 6)
    expect(value_data.getbyte(0)).to eq(0x03)
    value_data.byteslice(1..)
  end

  def scene_item_value_data(item_block, expected_value_type:)
    block_data = item_block[:data]
    offset = 0
    offset = skip_tagged_value(block_data, offset, expected_index: 1, expected_type: 0x0F)
    offset = skip_tagged_value(block_data, offset, expected_index: 2, expected_type: 0x0F)
    offset = skip_tagged_value(block_data, offset, expected_index: 3, expected_type: 0x0F)
    offset = skip_tagged_value(block_data, offset, expected_index: 4, expected_type: 0x0F)
    offset = skip_tagged_value(block_data, offset, expected_index: 5, expected_type: 0x04)

    value_data, = parse_subblock(block_data, offset, expected_index: 6)
    expect(value_data.getbyte(0)).to eq(expected_value_type)
    value_data.byteslice(1..)
  end

  it "writes the expected lines v6 header and top-level block sequence" do
    page = described_class.new
    line = page.add_line
    line.add_point(100, 200)

    bytes = page.to_rm_bytes
    blocks = parse_blocks(bytes)

    expect(bytes.start_with?(described_class::HEADER_V6)).to be(true)
    expect(blocks.map { |block| block[:block_type] }).to eq([0x09, 0x00, 0x0A, 0x01, 0x02, 0x02, 0x04, 0x05])
    expect(blocks.map { |block| [block[:min_version], block[:current_version]] }).to eq(
      [[1, 1], [1, 1], [0, 1], [1, 1], [1, 1], [1, 1], [1, 1], [2, 2]]
    )
    expect(blocks.all? { |block| block[:reserved] == 0 }).to be(true)
  end

  it "encodes point data with scene-space x coordinates and v2 point size" do
    page = described_class.new
    line = page.add_line
    line.add_point(100, 200)
    line.add_point(120, 220)

    bytes = page.to_rm_bytes
    line_block = parse_blocks(bytes).last
    value_data = line_value_data(line_block)

    _brush_tag, offset = parse_tag(value_data, 0)
    offset += 4
    _color_tag, offset = parse_tag(value_data, offset)
    offset += 4
    _thickness_tag, offset = parse_tag(value_data, offset)
    offset += 8
    _starting_length_tag, offset = parse_tag(value_data, offset)
    offset += 4

    points_data, offset = parse_subblock(value_data, offset, expected_index: 5)

    expect(points_data.bytesize).to eq(28)

    first_x, first_y = points_data.byteslice(0, 8).unpack("e2")
    second_x, second_y = points_data.byteslice(14, 8).unpack("e2")
    first_speed, first_width, first_direction, first_pressure = points_data.byteslice(8, 6).unpack("v v C C")

    expect(first_x).to eq(-602.0)
    expect(first_y).to eq(200.0)
    expect(second_x).to eq(-582.0)
    expect(second_y).to eq(220.0)
    expect(first_speed).to eq(0)
    expect(first_width).to eq(8)
    expect(first_direction).to eq(0)
    expect(first_pressure).to eq(255)

    timestamp_tag, = parse_tag(value_data, offset)
    expect(timestamp_tag).to eq(index: 6, type: 0x0F)
  end

  it "writes rgba tag 8 only for RGBA-colored lines" do
    page = described_class.new

    black_line = page.add_line
    black_line.add_point(100, 200)

    rgba_line = page.add_line
    rgba_line.color = described_class::Colour::RGBA
    rgba_line.rgba = 0xFF112233
    rgba_line.add_point(140, 240)

    blocks = parse_blocks(page.to_rm_bytes).select { |block| block[:block_type] == 0x05 }
    black_value = line_value_data(blocks[0])
    rgba_value = line_value_data(blocks[1])

    expect(black_value).not_to include([8 << 4 | 0x04].pack("C"))
    expect(rgba_value).to include([8 << 4 | 0x04].pack("C"))
    expect(rgba_value).to include([0xFF112233].pack("V"))
  end

  it "writes image info and native image item blocks" do
    page = described_class.new
    page.add_png_image(
      file_name: "image.png",
      uuid: "00112233-4455-6677-8899-aabbccddeeff",
      x: 130,
      y: 140,
      width: 200,
      height: 100
    )

    blocks = parse_blocks(page.to_rm_bytes)
    expect(blocks.map { |block| block[:block_type] }).to eq([0x09, 0x00, 0x0A, 0x0E, 0x01, 0x02, 0x02, 0x04, 0x0F])
    expect(blocks[3].values_at(:min_version, :current_version)).to eq([3, 3])
    expect(blocks.last.values_at(:min_version, :current_version)).to eq([2, 2])

    image_info_data, = parse_subblock(blocks[3][:data], 0, expected_index: 1)
    image_count, offset = read_varuint(image_info_data, 0)
    expect(image_count).to eq(1)

    entry_data, = parse_subblock(image_info_data, offset, expected_index: 0)
    expect(entry_data.byteslice(0, 16)).to eq(["00112233445566778899aabbccddeeff"].pack("H*"))

    image_value = scene_item_value_data(blocks.last, expected_value_type: 0x07)
    image_ref_data, offset = parse_subblock(image_value, 0, expected_index: 1)
    timestamp, image_ref_offset = read_tagged_id(image_ref_data, 0, expected_index: 1)
    expect(timestamp).to eq(author: 1, value: 16)
    uuid_data, = parse_subblock(image_ref_data, image_ref_offset, expected_index: 2)
    expect(uuid_data).to eq(["00112233445566778899aabbccddeeff"].pack("H*"))

    bounds_timestamp, offset = read_tagged_id(image_value, offset, expected_index: 2)
    expect(bounds_timestamp).to eq(author: 1, value: 15)

    vertices_data, = parse_subblock(image_value, offset, expected_index: 3)
    vertex_count, vertex_offset = read_varuint(vertices_data, 0)
    expect(vertex_count).to eq(16)
    expect(vertices_data.byteslice(vertex_offset, 64).unpack("e16")).to eq(
      [-572.0, 140.0, 0.0, 0.0, -372.0, 140.0, 1.0, 0.0,
       -372.0, 240.0, 1.0, 1.0, -572.0, 240.0, 0.0, 1.0]
    )
  end
end

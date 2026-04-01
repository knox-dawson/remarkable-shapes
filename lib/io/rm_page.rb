# frozen_string_literal: true

# Core namespaces for the reMarkable lines v6 writing and shape-rendering tools.
module Remarkable
  # Low-level writer for reMarkable lines v6 pages.
  class RmPage
    # Binary file header used by reMarkable lines v6.
    HEADER_V6 = "reMarkable .lines file, version=6          ".b
    # Page width in tablet units.
    PAGE_WIDTH = 1404.0
    # Empirical scale factor needed for lines v6 widths.
    WIDTH_SCALE = 4.0

    # Tablet colour codes used by the built-in palette.
    module Colour
      # Built-in black.
      BLACK = 0
      # Built-in grey.
      GREY = 1
      # Built-in white.
      WHITE = 2
      # Built-in yellow highlighter.
      HIGHLIGHTER_YELLOW = 3
      # Built-in green highlighter.
      HIGHLIGHTER_GREEN = 4
      # Built-in pink highlighter.
      HIGHLIGHTER_PINK = 5
      # Built-in blue.
      BLUE = 6
      # Built-in red.
      RED = 7
      # Built-in grey highlighter.
      HIGHLIGHTER_GREY = 8
      # Custom RGBA stroke colour.
      RGBA = 9
      # Built-in green.
      GREEN = 10
      # Built-in cyan.
      CYAN = 11
      # Built-in magenta.
      MAGENTA = 12
      # Built-in yellow.
      YELLOW = 13

      # All supported built-in colour codes.
      VALUES = [
        BLACK, GREY, WHITE, HIGHLIGHTER_YELLOW, HIGHLIGHTER_GREEN,
        HIGHLIGHTER_PINK, BLUE, RED, HIGHLIGHTER_GREY, RGBA,
        GREEN, CYAN, MAGENTA, YELLOW
      ].freeze
    end

    # Pen identifiers used by the tablet.
    module Pen
      # Tilt pencil brush.
      PENCIL_TILT = 1
      # Fineliner brush.
      FINELINER_2 = 17
      # Highlighter brush.
      HIGHLIGHTER_2 = 18
      # Shader brush.
      SHADER = 23
    end

    # A single point in a stroke.
    Point = Struct.new(:x, :y, :speed, :direction, :width, :pressure, keyword_init: true)

    # A single stroke line in the page.
    class Line
      # @return [Integer] the tablet pen identifier
      attr_accessor :brush_type
      # @return [Integer] the tablet colour code
      attr_accessor :color
      # @return [Integer] the ARGB colour when {Colour::RGBA} is used
      attr_accessor :rgba
      # @return [Float] thickness scale written to the file
      attr_accessor :thickness_scale
      # @return [Float] starting length written to the file
      attr_accessor :starting_length
      # @return [Array<Point>] points belonging to this line
      attr_reader :points

      # Creates a line with sensible defaults for this project.
      def initialize
        @brush_type = Pen::FINELINER_2
        @color = Colour::BLACK
        @rgba = 0xFF000000
        @thickness_scale = 1.0
        @starting_length = 0.0
        @points = []
      end

      # Adds a point to the line.
      #
      # @param x [Numeric] point x coordinate
      # @param y [Numeric] point y coordinate
      # @return [Point]
      def add_point(x, y)
        point = Point.new(x: x.to_f, y: y.to_f, speed: 0.1, direction: 0.0, width: 2.0, pressure: 1.0)
        @points << point
        point
      end
    end

    # @return [Array<Line>] lines currently added to the page
    attr_reader :lines

    # Creates an empty page.
    def initialize
      @lines = []
    end

    # Adds a new stroke line to the page.
    #
    # @return [Line]
    def add_line
      line = Line.new
      @lines << line
      line
    end

    # Serializes the page to a lines v6 byte string.
    #
    # @return [String]
    def to_rm_bytes
      out = +"".b
      out << HEADER_V6
      out << write_author_ids_block
      out << write_migration_info_block
      out << write_page_info_block
      out << write_scene_tree_block
      out << write_tree_node_block(0, 1, "", 12)
      out << write_tree_node_block(0, 11, "Layer 1", 14)
      out << write_scene_group_item_block(0, 1, 0, 13, 0, 0, 0, 11)
      out << write_line_blocks
      out
    end

    private

    # Encodes the author-id block.
    #
    # @return [String]
    def write_author_ids_block
      block = +"".b
      block << write_varuint(1)
      sub = +"".b
      author_bytes_le = [
        0x9F, 0xA5, 0x5B, 0x49, 0x43, 0xC9, 0x5C, 0x2B,
        0xB4, 0x55, 0x36, 0x82, 0xF6, 0x94, 0x89, 0x06
      ].pack("C*")
      sub << write_varuint(author_bytes_le.bytesize)
      sub << author_bytes_le
      sub << [1].pack("v")
      block << write_subblock(0, sub)
      write_block(0x09, 1, 1, block)
    end

    # Encodes the migration-info block.
    #
    # @return [String]
    def write_migration_info_block
      block = +"".b
      block << write_tagged_id(1, 1, 1)
      block << write_tagged_bool(2, true)
      write_block(0x00, 1, 1, block)
    end

    # Encodes the page-info block.
    #
    # @return [String]
    def write_page_info_block
      block = +"".b
      block << write_tagged_int(1, 1)
      block << write_tagged_int(2, 0)
      block << write_tagged_int(3, 0)
      block << write_tagged_int(4, 0)
      write_block(0x0A, 0, 1, block)
    end

    # Encodes the scene-tree block required by lines v6.
    #
    # @return [String]
    def write_scene_tree_block
      block = +"".b
      block << write_tagged_id(1, 0, 11)
      block << write_tagged_id(2, 0, 0)
      block << write_tagged_bool(3, true)
      block << write_subblock(4, write_tagged_id(1, 0, 1))
      write_block(0x01, 1, 1, block)
    end

    # Encodes a tree-node block.
    #
    # @param node_author [Integer]
    # @param node_id [Integer]
    # @param label [String]
    # @param label_timestamp [Integer]
    # @return [String]
    def write_tree_node_block(node_author, node_id, label, label_timestamp)
      block = +"".b
      block << write_tagged_id(1, node_author, node_id)
      block << write_lww_string(2, 0, label_timestamp, label)
      block << write_lww_bool(3, 0, label_timestamp, true)
      write_block(0x02, 1, 1, block)
    end

    # Encodes a scene group item block for a layer item.
    #
    # @return [String]
    def write_scene_group_item_block(parent_author, parent_id, item_author, item_id, left_author, left_id, value_author, value_id)
      block = +"".b
      block << write_tagged_id(1, parent_author, parent_id)
      block << write_tagged_id(2, item_author, item_id)
      block << write_tagged_id(3, left_author, left_id)
      block << write_tagged_id(4, 0, 0)
      block << write_tagged_int(5, 0)
      value = +"\x02".b
      value << write_tagged_id(2, value_author, value_id)
      block << write_subblock(6, value)
      write_block(0x04, 1, 1, block)
    end

    # Encodes every line block in insertion order.
    #
    # @return [String]
    def write_line_blocks
      out = +"".b
      previous_item_id = 0
      item_id = 14
      @lines.each do |line|
        out << write_line_block(line, item_id, previous_item_id)
        previous_item_id = item_id
        item_id += 1
      end
      out
    end

    # Encodes one line block.
    #
    # @param line [Line]
    # @param item_id [Integer]
    # @param left_id [Integer]
    # @return [String]
    def write_line_block(line, item_id, left_id)
      block = +"".b
      block << write_tagged_id(1, 0, 11)
      block << write_tagged_id(2, 1, item_id)
      block << write_tagged_id(3, left_id.zero? ? 0 : 1, left_id)
      block << write_tagged_id(4, 0, 0)
      block << write_tagged_int(5, 0)
      block << write_subblock(6, line_value_bytes(line))
      write_block(0x05, 2, 2, block)
    end

    # Encodes the value payload for one line.
    #
    # @param line [Line]
    # @return [String]
    def line_value_bytes(line)
      out = +"\x03".b
      out << write_tagged_int(1, line.brush_type)
      out << write_tagged_int(2, line.color)
      out << write_tagged_double(3, line.thickness_scale)
      out << write_tagged_float(4, line.starting_length)
      out << write_subblock(5, point_bytes(line))
      out << write_tagged_id(6, 0, 1)
      out << write_tagged_int(8, line.rgba) if line.color == Colour::RGBA
      out
    end

    # Encodes every point in a line.
    #
    # @param line [Line]
    # @return [String]
    def point_bytes(line)
      out = +"".b
      line.points.each do |point|
        out << [scene_x(point.x)].pack("e")
        out << [point.y].pack("e")
        out << [[[point.speed.round, 0].max, 0xFFFF].min].pack("v")
        out << [[[scaled_width(point.width).round, 0].max, 0xFFFF].min].pack("v")
        out << [[[point.direction.round, 0].max, 0xFF].min].pack("C")
        out << [[[(point.pressure * 255).round, 0].max, 0xFF].min].pack("C")
      end
      out
    end

    # Converts page-space x to scene-space x.
    #
    # @param x [Numeric]
    # @return [Float]
    def scene_x(x)
      x - (PAGE_WIDTH / 2.0)
    end

    # Applies the empirical width scale for lines v6.
    #
    # @param width [Numeric]
    # @return [Float]
    def scaled_width(width)
      width.to_f * WIDTH_SCALE
    end

    # Encodes a top-level block.
    #
    # @return [String]
    def write_block(block_type, min_version, current_version, block_data)
      [block_data.bytesize].pack("V") + [0, min_version, current_version, block_type].pack("C*") + block_data
    end

    # Encodes a tagged subblock.
    #
    # @return [String]
    def write_subblock(index, data)
      write_tag(index, 0x0C) + [data.bytesize].pack("V") + data
    end

    # Encodes a last-write-wins boolean wrapper.
    #
    # @return [String]
    def write_lww_bool(index, author, value_id, value)
      write_subblock(index, write_tagged_id(1, author, value_id) + write_tagged_bool(2, value))
    end

    # Encodes a last-write-wins string wrapper.
    #
    # @return [String]
    def write_lww_string(index, author, value_id, value)
      write_subblock(index, write_tagged_id(1, author, value_id) + write_tagged_string(2, value))
    end

    # Encodes a UTF-8 string value.
    #
    # @return [String]
    def write_tagged_string(index, value)
      data = +"".b
      bytes = value.encode(Encoding::UTF_8)
      data << write_varuint(bytes.bytesize)
      data << [1].pack("C")
      data << bytes
      write_subblock(index, data)
    end

    # Encodes a boolean tag.
    #
    # @return [String]
    def write_tagged_bool(index, value)
      write_tag(index, 0x01) + [value ? 1 : 0].pack("C")
    end

    # Encodes an identifier tag.
    #
    # @return [String]
    def write_tagged_id(index, author, value)
      write_tag(index, 0x0F) + [author].pack("C") + write_varuint(value)
    end

    # Encodes an integer tag.
    #
    # @return [String]
    def write_tagged_int(index, value)
      write_tag(index, 0x04) + [value].pack("V")
    end

    # Encodes a float tag.
    #
    # @return [String]
    def write_tagged_float(index, value)
      write_tag(index, 0x04) + [value].pack("e")
    end

    # Encodes a double tag.
    #
    # @return [String]
    def write_tagged_double(index, value)
      write_tag(index, 0x08) + [value].pack("E")
    end

    # Encodes a protobuf-style tag header.
    #
    # @return [String]
    def write_tag(index, tag_type)
      write_varuint((index << 4) | tag_type)
    end

    # Encodes an unsigned varint.
    #
    # @param value [Integer]
    # @return [String]
    def write_varuint(value)
      out = +"".b
      remaining = value
      loop do
        byte = remaining & 0x7F
        remaining >>= 7
        if remaining != 0
          out << [(byte | 0x80)].pack("C")
        else
          out << [byte].pack("C")
          break
        end
      end
      out
    end
  end
end

# frozen_string_literal: true

module Remarkable
  # Shared helpers for native PNG/JPEG image assets.
  module NativeImage
    module_function

    # Reads native image dimensions without fully decoding the image.
    #
    # @return [Array(Integer, Integer)]
    def dimensions(path)
      case File.extname(path).downcase
      when ".png"
        png_dimensions(path)
      when ".jpg", ".jpeg"
        jpeg_dimensions(path)
      else
        raise ArgumentError, "native image only supports PNG or JPEG input: #{path}"
      end
    end

    # Returns the normalized file extension to use inside the rmdoc.
    #
    # @return [String]
    def extension(path)
      ext = File.extname(path).downcase
      ext == ".jpeg" ? ".jpg" : ext
    end

    # Returns whether the path extension is a native-image input type.
    #
    # @return [Boolean]
    def supported_path?(path)
      %w[.png .jpg .jpeg].include?(File.extname(path).downcase)
    end

    # Reads PNG dimensions without fully decoding the image.
    #
    # @return [Array(Integer, Integer)]
    def png_dimensions(path)
      File.open(path, "rb") do |file|
        signature = file.read(8)
        raise ArgumentError, "not a PNG file: #{path}" unless signature == "\x89PNG\r\n\x1A\n".b

        length = file.read(4)&.unpack1("N")
        chunk_type = file.read(4)
        raise ArgumentError, "PNG missing IHDR chunk: #{path}" unless length == 13 && chunk_type == "IHDR"

        file.read(8).unpack("N2")
      end
    end

    # Reads JPEG dimensions from a Start Of Frame segment.
    #
    # @return [Array(Integer, Integer)]
    def jpeg_dimensions(path)
      File.open(path, "rb") do |file|
        raise ArgumentError, "not a JPEG file: #{path}" unless file.read(2) == "\xFF\xD8".b

        loop do
          marker = next_jpeg_marker(file)
          break if marker.nil? || marker == 0xD9

          raise ArgumentError, "JPEG missing segment length: #{path}" if [0x01, *0xD0..0xD7].include?(marker)

          length_bytes = file.read(2)
          raise ArgumentError, "JPEG missing segment length: #{path}" unless length_bytes&.bytesize == 2

          length = length_bytes.unpack1("n")
          raise ArgumentError, "invalid JPEG segment length: #{path}" if length < 2

          if jpeg_sof_marker?(marker)
            data = file.read(length - 2)
            raise ArgumentError, "truncated JPEG SOF segment: #{path}" unless data&.bytesize == length - 2

            height, width = data.byteslice(1, 4).unpack("n2")
            return [width, height]
          end

          file.seek(length - 2, IO::SEEK_CUR)
        end
      end

      raise ArgumentError, "JPEG dimensions not found: #{path}"
    end

    # Returns the next JPEG marker byte.
    #
    # @return [Integer, nil]
    def next_jpeg_marker(file)
      loop do
        byte = file.read(1)&.ord
        return nil if byte.nil?
        break if byte == 0xFF
      end

      marker = file.read(1)&.ord
      marker = file.read(1)&.ord while marker == 0xFF
      marker
    end

    # Returns whether a marker is a Start Of Frame segment with dimensions.
    #
    # @return [Boolean]
    def jpeg_sof_marker?(marker)
      (0xC0..0xCF).include?(marker) && ![0xC4, 0xC8, 0xCC].include?(marker)
    end
  end
end

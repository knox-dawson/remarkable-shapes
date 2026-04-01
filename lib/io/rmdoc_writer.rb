# frozen_string_literal: true

require "securerandom"
require "zlib"

module Remarkable
  # Packs one page of lines bytes into an uploadable .rmdoc notebook.
  class RmdocWriter
    # Default rm2 page width for notebook metadata.
    DEFAULT_PAGE_WIDTH = 1404
    # Default rm2 page height for notebook metadata.
    DEFAULT_PAGE_HEIGHT = 1872

    # Writes a .rmdoc file to disk.
    #
    # @param path [String] output file path
    # @param rm_bytes [String] serialized lines v6 page bytes
    # @param page_width [Numeric] physical page width for notebook metadata
    # @param page_height [Numeric] physical page height for notebook metadata
    # @return [void]
    def self.write(path, rm_bytes, page_width: DEFAULT_PAGE_WIDTH, page_height: DEFAULT_PAGE_HEIGHT)
      notebook_id = SecureRandom.uuid
      page_id = SecureRandom.uuid
      visible_name = File.basename(path, ".rmdoc")
      content = create_content(notebook_id, page_id, page_width:, page_height:)
      metadata = create_metadata(visible_name)

      entries = [
        ["#{notebook_id}.content", content],
        ["#{notebook_id}.metadata", metadata],
        ["#{notebook_id}/#{page_id}.rm", rm_bytes]
      ]

      write_zip(path, entries)
    end

    # Creates the .content JSON payload.
    #
    # @param notebook_id [String]
    # @param page_id [String]
    # @param page_width [Numeric]
    # @param page_height [Numeric]
    # @return [String]
    def self.create_content(notebook_id, page_id, page_width: DEFAULT_PAGE_WIDTH, page_height: DEFAULT_PAGE_HEIGHT)
      page_width = page_width.to_i
      page_height = page_height.to_i
      zoom_center_y = page_height / 2
      <<~JSON
        {
            "cPages": {
                "lastOpened": {
                    "timestamp": "1:1",
                    "value": "#{page_id}"
                },
                "original": {
                    "timestamp": "1:1",
                    "value": -1
                },
                "pages": [
                    {
                        "id": "#{page_id}",
                        "idx": {
                            "timestamp": "1:2",
                            "value": "ba"
                        },
                        "template": {
                            "timestamp": "1:2",
                            "value": "Blank"
                        }
                    }
                ],
                "uuids": [
                    {
                        "first": "#{notebook_id}",
                        "second": 1
                    }
                ]
            },
            "coverPageNumber": -1,
            "customZoomCenterX": 0,
            "customZoomCenterY": #{zoom_center_y},
            "customZoomOrientation": "portrait",
            "customZoomPageHeight": #{page_height},
            "customZoomPageWidth": #{page_width},
            "customZoomScale": 1,
            "documentMetadata": {
            },
            "extraMetadata": {
                "LastBallpointv2Color": "Black",
                "LastBallpointv2Size": "2",
                "LastEraserColor": "Black",
                "LastEraserSize": "2",
                "LastEraserTool": "Eraser",
                "LastPen": "Ballpointv2",
                "LastTool": "Ballpointv2"
            },
            "fileType": "notebook",
            "fontName": "",
            "formatVersion": 2,
            "lineHeight": -1,
            "margins": 125,
            "orientation": "portrait",
            "pageCount": 1,
            "pageTags": [
            ],
            "sizeInBytes": "0",
            "tags": [
            ],
            "textAlignment": "justify",
            "textScale": 1,
            "zoomMode": "bestFit"
        }
      JSON
    end

    # Creates the .metadata JSON payload.
    #
    # @param visible_name [String]
    # @return [String]
    def self.create_metadata(visible_name)
      time = (Time.now.to_f * 1000).to_i
      <<~JSON
        {
            "createdTime": "#{time}",
            "lastModified": "#{time}",
            "lastOpened": "#{time}",
            "lastOpenedPage": 0,
            "parent": "",
            "pinned": false,
            "type": "DocumentType",
            "visibleName": "#{visible_name}"
        }
      JSON
    end

    # Writes an uncompressed ZIP file containing the .rmdoc entries.
    #
    # @param path [String]
    # @param entries [Array<Array(String, String)>]
    # @return [void]
    def self.write_zip(path, entries)
      File.binwrite(path, zip_bytes(entries))
    end

    # Builds uncompressed ZIP bytes for the given entries.
    #
    # @param entries [Array<Array(String, String)>]
    # @return [String]
    def self.zip_bytes(entries)
      out = +"".b
      central = +"".b
      offset = 0

      entries.each do |name, data|
        name_bytes = name.b
        data_bytes = data.is_a?(String) ? data.b : data
        crc = Zlib.crc32(data_bytes)
        size = data_bytes.bytesize

        local_header = [
          0x04034b50, 20, 0, 0, 0, 0, crc, size, size, name_bytes.bytesize, 0
        ].pack("VvvvvvVVVvv")
        out << local_header
        out << name_bytes
        out << data_bytes

        central << [
          0x02014b50, 20, 20, 0, 0, 0, 0, crc, size, size,
          name_bytes.bytesize, 0, 0, 0, 0, 0, offset
        ].pack("VvvvvvvVVVvvvvvVV")
        central << name_bytes

        offset = out.bytesize
      end

      central_offset = out.bytesize
      out << central
      out << [
        0x06054b50, 0, 0, entries.length, entries.length, central.bytesize, central_offset, 0
      ].pack("VvvvvVVv")
      out
    end
  end
end

require "zlib"
require "securerandom"

module Remarkable
  module IO
    class RmdocWriter
      def self.write(path, rm_bytes)
        notebook_id = SecureRandom.uuid
        page_id = SecureRandom.uuid
        visible_name = File.basename(path, ".rmdoc")
        content = create_content(page_id)
        metadata = create_metadata(visible_name)

        entries = [
          ["#{notebook_id}.content", content],
          ["#{notebook_id}.metadata", metadata],
          ["#{notebook_id}/#{page_id}.rm", rm_bytes]
        ]

        write_zip(path, entries)
      end

      def self.create_content(page_id)
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
                        "first": "25248a5b-7602-5a83-b6b8-885ee4e4f813",
                        "second": 1
                    }
                ]
            },
            "coverPageNumber": -1,
            "customZoomCenterX": 0,
            "customZoomCenterY": 936,
            "customZoomOrientation": "portrait",
            "customZoomPageHeight": 1872,
            "customZoomPageWidth": 1404,
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

      def self.write_zip(path, entries)
        File.binwrite(path, zip_bytes(entries))
      end

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
end

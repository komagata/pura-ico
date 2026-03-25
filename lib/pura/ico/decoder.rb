# frozen_string_literal: true

module Pura
  module Ico
    class DecodeError < StandardError; end

    class Decoder
      ICO_TYPE = 1
      CUR_TYPE = 2

      PNG_SIGNATURE = [137, 80, 78, 71, 13, 10, 26, 10].pack("C8").freeze

      def self.decode(input)
        data = if input.is_a?(String) && !input.include?("\x00") && input.bytesize < 4096 && File.exist?(input)
                 File.binread(input)
               else
                 input.b
               end
        new(data).decode
      end

      def initialize(data)
        @data = data
        @pos = 0
      end

      def decode
        # Parse ICO header
        read_uint16
        type = read_uint16
        count = read_uint16

        raise DecodeError, "Not an ICO/CUR file (type=#{type})" unless [ICO_TYPE, CUR_TYPE].include?(type)

        raise DecodeError, "No images in ICO file" if count.zero?

        # Parse directory entries
        entries = Array.new(count) { read_directory_entry(type) }

        # Find the largest image (by pixel area)
        best = entries.max_by { |e| e[:width] * e[:height] }

        decode_entry(best)
      end

      private

      def read_directory_entry(type)
        w = read_uint8
        h = read_uint8
        color_count = read_uint8
        _reserved = read_uint8

        if type == CUR_TYPE
          hotspot_x = read_uint16
          hotspot_y = read_uint16
        else
          planes = read_uint16
          bpp = read_uint16
        end

        data_size = read_uint32
        data_offset = read_uint32

        # Width/height of 0 means 256
        w = 256 if w.zero?
        h = 256 if h.zero?

        entry = {
          width: w,
          height: h,
          color_count: color_count,
          data_size: data_size,
          data_offset: data_offset
        }
        entry[:planes] = planes if type == ICO_TYPE
        entry[:bpp] = bpp if type == ICO_TYPE
        entry[:hotspot_x] = hotspot_x if type == CUR_TYPE
        entry[:hotspot_y] = hotspot_y if type == CUR_TYPE
        entry
      end

      def decode_entry(entry)
        offset = entry[:data_offset]
        size = entry[:data_size]
        entry_data = @data.byteslice(offset, size)

        raise DecodeError, "Entry data truncated" unless entry_data && entry_data.bytesize == size

        if png_entry?(entry_data)
          decode_png_entry(entry_data)
        else
          decode_bmp_entry(entry_data, entry[:width], entry[:height])
        end
      end

      def png_entry?(data)
        data.bytesize >= 8 && data.byteslice(0, 8) == PNG_SIGNATURE
      end

      def decode_png_entry(data)
        # Use Pura::Png if available
        require "pura-png"
        png_image = Pura::Png.decode(data)
        Image.new(png_image.width, png_image.height, png_image.pixels)
      end

      def decode_bmp_entry(data, dir_width, dir_height)
        pos = 0

        # BMP info header (BITMAPINFOHEADER - 40 bytes)
        header_size = data.byteslice(pos, 4).unpack1("V")
        bmp_width = data.byteslice(pos + 4, 4).unpack1("V")
        # Height in ICO BMP is doubled (includes AND mask)
        bmp_height = data.byteslice(pos + 8, 4).unpack1("V")
        data.byteslice(pos + 12, 2).unpack1("v")
        bpp = data.byteslice(pos + 14, 2).unpack1("v")
        data.byteslice(pos + 16, 4).unpack1("V")
        _image_size = data.byteslice(pos + 20, 4).unpack1("V")
        # Skip remaining header fields

        width = bmp_width
        height = bmp_height / 2 # Actual height (BMP height includes AND mask)

        # Use directory dimensions if BMP header seems wrong
        width = dir_width if width.zero?
        height = dir_height if height.zero?

        pos = header_size # Skip past BMP header

        # Read color table if needed
        palette = nil
        if bpp <= 8
          num_colors = 1 << bpp
          palette = Array.new(num_colors)
          num_colors.times do |i|
            b = data.getbyte(pos)
            g = data.getbyte(pos + 1)
            r = data.getbyte(pos + 2)
            _a = data.getbyte(pos + 3)
            palette[i] = [r, g, b]
            pos += 4
          end
        end

        # Decode pixel data (bottom-up, BMP style)
        stride = (((bpp * width) + 31) / 32) * 4 # Row stride aligned to 4 bytes
        pixels = String.new(encoding: Encoding::BINARY, capacity: width * height * 3)

        # Read rows bottom-up
        rows = Array.new(height)
        height.times do |y|
          row_offset = pos + (y * stride)
          row = String.new(encoding: Encoding::BINARY, capacity: width * 3)

          case bpp
          when 32
            width.times do |x|
              px_offset = row_offset + (x * 4)
              b = data.getbyte(px_offset)
              g = data.getbyte(px_offset + 1)
              r = data.getbyte(px_offset + 2)
              # a = data.getbyte(px_offset + 3)  # Alpha ignored for RGB output
              row << r.chr << g.chr << b.chr
            end
          when 24
            width.times do |x|
              px_offset = row_offset + (x * 3)
              b = data.getbyte(px_offset)
              g = data.getbyte(px_offset + 1)
              r = data.getbyte(px_offset + 2)
              row << r.chr << g.chr << b.chr
            end
          when 8
            width.times do |x|
              idx = data.getbyte(row_offset + x)
              r, g, b = palette[idx]
              row << r.chr << g.chr << b.chr
            end
          when 4
            width.times do |x|
              byte_offset = row_offset + (x / 2)
              byte = data.getbyte(byte_offset)
              idx = x.even? ? (byte >> 4) & 0x0F : byte & 0x0F
              r, g, b = palette[idx]
              row << r.chr << g.chr << b.chr
            end
          when 1
            width.times do |x|
              byte_offset = row_offset + (x / 8)
              byte = data.getbyte(byte_offset)
              bit = (byte >> (7 - (x % 8))) & 1
              r, g, b = palette[bit]
              row << r.chr << g.chr << b.chr
            end
          else
            raise DecodeError, "Unsupported BMP bit depth: #{bpp}"
          end

          rows[y] = row
        end

        # BMP is bottom-up, so reverse row order
        rows.reverse_each do |row|
          pixels << row
        end

        Image.new(width, height, pixels)
      end

      def read_uint8
        raise DecodeError, "Unexpected end of data" if @pos + 1 > @data.bytesize

        val = @data.getbyte(@pos)
        @pos += 1
        val
      end

      def read_uint16
        raise DecodeError, "Unexpected end of data" if @pos + 2 > @data.bytesize

        val = @data.byteslice(@pos, 2).unpack1("v")
        @pos += 2
        val
      end

      def read_uint32
        raise DecodeError, "Unexpected end of data" if @pos + 4 > @data.bytesize

        val = @data.byteslice(@pos, 4).unpack1("V")
        @pos += 4
        val
      end
    end
  end
end

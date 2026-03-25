# frozen_string_literal: true

module Pura
  module Ico
    class Encoder
      def self.encode(images, output_path)
        images = [images] unless images.is_a?(Array)
        encoder = new(images)
        data = encoder.encode
        File.binwrite(output_path, data)
        data.bytesize
      end

      def initialize(images)
        @images = images
      end

      def encode
        require "pura-png"

        count = @images.size

        # Encode each image as PNG data
        png_blobs = @images.map { |img| encode_png_blob(img) }

        # Calculate offsets
        # Header: 6 bytes
        # Directory entries: 16 bytes each
        header_size = 6 + (16 * count)
        offsets = []
        current_offset = header_size
        png_blobs.each do |blob|
          offsets << current_offset
          current_offset += blob.bytesize
        end

        out = String.new(encoding: Encoding::BINARY, capacity: current_offset)

        # ICO header
        out << [0, 1, count].pack("v3") # reserved=0, type=1 (ICO), count

        # Directory entries
        @images.each_with_index do |img, i|
          w = img.width >= 256 ? 0 : img.width
          h = img.height >= 256 ? 0 : img.height

          out << [
            w,           # width (0 = 256)
            h,           # height (0 = 256)
            0,           # color count (0 for >= 256 colors)
            0,           # reserved
            1,           # color planes
            32 # bits per pixel
          ].pack("C4v2")
          out << [
            png_blobs[i].bytesize,  # data size
            offsets[i]              # data offset
          ].pack("V2")
        end

        # Image data (PNG blobs)
        png_blobs.each { |blob| out << blob }

        out
      end

      private

      def encode_png_blob(image)
        # Create a Pura::Png::Image and encode to memory
        png_image = Pura::Png::Image.new(image.width, image.height, image.pixels)
        # Encode to a temporary buffer via StringIO-like approach
        # Pura::Png::Encoder returns binary data via encode method
        encoder = Pura::Png::Encoder.new(png_image)
        encoder.encode
      end
    end
  end
end

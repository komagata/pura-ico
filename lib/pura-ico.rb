# frozen_string_literal: true

require_relative "pura/ico/version"
require_relative "pura/ico/image"
require_relative "pura/ico/decoder"
require_relative "pura/ico/encoder"

module Pura
  module Ico
    def self.decode(input)
      Decoder.decode(input)
    end

    def self.encode(images, output_path)
      Encoder.encode(images, output_path)
    end
  end
end

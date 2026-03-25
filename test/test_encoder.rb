# frozen_string_literal: true

$LOAD_PATH.unshift(File.join("/tmp/pura-png", "lib"))

require "minitest/autorun"
require_relative "../lib/pura-ico"

class TestEncoder < Minitest::Test
  TMP_DIR = File.join(__dir__, "tmp")

  def setup
    FileUtils.mkdir_p(TMP_DIR)
  end

  def teardown
    Dir.glob(File.join(TMP_DIR, "*")).each { |f| File.delete(f) }
    FileUtils.rm_f(TMP_DIR)
  end

  def test_encode_creates_valid_ico
    image = create_red_image(16, 16)
    path = File.join(TMP_DIR, "test_output.ico")
    size = Pura::Ico.encode(image, path)
    assert size.positive?
    assert File.exist?(path)

    # Verify ICO header
    data = File.binread(path)
    reserved, type, count = data.byteslice(0, 6).unpack("v3")
    assert_equal 0, reserved
    assert_equal 1, type
    assert_equal 1, count
  end

  def test_encode_decode_roundtrip
    image = create_gradient_image(16, 16)
    path = File.join(TMP_DIR, "roundtrip.ico")
    Pura::Ico.encode(image, path)

    decoded = Pura::Ico.decode(path)
    assert_equal 16, decoded.width
    assert_equal 16, decoded.height
    assert_equal image.pixels, decoded.pixels
  end

  def test_encode_decode_roundtrip_solid_colors
    [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 255], [0, 0, 0]].each do |color|
      pixels = color.pack("C3").b * (8 * 8)
      image = Pura::Ico::Image.new(8, 8, pixels)
      path = File.join(TMP_DIR, "solid_#{color.join("_")}.ico")
      Pura::Ico.encode(image, path)

      decoded = Pura::Ico.decode(path)
      r, g, b = decoded.pixel_at(4, 4)
      assert_equal color[0], r, "Red mismatch for #{color}"
      assert_equal color[1], g, "Green mismatch for #{color}"
      assert_equal color[2], b, "Blue mismatch for #{color}"
    end
  end

  def test_encode_multiple_sizes
    image16 = create_red_image(16, 16)
    image32 = create_red_image(32, 32)
    path = File.join(TMP_DIR, "multi.ico")
    size = Pura::Ico.encode([image16, image32], path)

    assert size.positive?

    data = File.binread(path)
    _reserved, _type, count = data.byteslice(0, 6).unpack("v3")
    assert_equal 2, count
  end

  def test_encode_preserves_pixel_data_exactly
    pixels = String.new(encoding: Encoding::BINARY)
    256.times do |i|
      pixels << [i, (i * 2) & 0xFF, (i * 3) & 0xFF].pack("C3")
    end
    image = Pura::Ico::Image.new(16, 16, pixels)
    path = File.join(TMP_DIR, "exact_pixels.ico")
    Pura::Ico.encode(image, path)

    decoded = Pura::Ico.decode(path)
    assert_equal pixels, decoded.pixels
  end

  def test_encode_various_sizes
    [[1, 1], [3, 5], [64, 64]].each do |w, h|
      pixels = "\x80\x80\x80".b * (w * h)
      image = Pura::Ico::Image.new(w, h, pixels)
      path = File.join(TMP_DIR, "size_#{w}x#{h}.ico")
      Pura::Ico.encode(image, path)

      decoded = Pura::Ico.decode(path)
      assert_equal w, decoded.width
      assert_equal h, decoded.height
      assert_equal pixels, decoded.pixels
    end
  end

  private

  def create_red_image(w, h)
    pixels = "\xFF\x00\x00".b * (w * h)
    Pura::Ico::Image.new(w, h, pixels)
  end

  def create_gradient_image(w, h)
    pixels = String.new(encoding: Encoding::BINARY, capacity: w * h * 3)
    h.times do |y|
      w.times do |x|
        r = (x * 255 / [w - 1, 1].max)
        g = (y * 255 / [h - 1, 1].max)
        b = 128
        pixels << r.chr << g.chr << b.chr
      end
    end
    Pura::Ico::Image.new(w, h, pixels)
  end
end

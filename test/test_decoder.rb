# frozen_string_literal: true

$LOAD_PATH.unshift(File.join("/tmp/pura-png", "lib"))

require "minitest/autorun"
require_relative "../lib/pura-ico"

class TestDecoder < Minitest::Test
  FIXTURE_DIR = File.join(__dir__, "fixtures")

  def setup
    FileUtils.mkdir_p(FIXTURE_DIR)
    generate_fixtures
  end

  def test_decode_32bit_bmp_ico
    path = File.join(FIXTURE_DIR, "32bit.ico")
    image = Pura::Ico.decode(path)
    assert_equal 4, image.width
    assert_equal 4, image.height
    assert_equal 4 * 4 * 3, image.pixels.bytesize
    # Top-left pixel should be red
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 0, g
    assert_equal 0, b
  end

  def test_decode_24bit_bmp_ico
    path = File.join(FIXTURE_DIR, "24bit.ico")
    image = Pura::Ico.decode(path)
    assert_equal 4, image.width
    assert_equal 4, image.height
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 0, g
    assert_equal 0, b
  end

  def test_decode_8bit_bmp_ico
    path = File.join(FIXTURE_DIR, "8bit.ico")
    image = Pura::Ico.decode(path)
    assert_equal 4, image.width
    assert_equal 4, image.height
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 0, g
    assert_equal 0, b
  end

  def test_decode_4bit_bmp_ico
    path = File.join(FIXTURE_DIR, "4bit.ico")
    image = Pura::Ico.decode(path)
    assert_equal 4, image.width
    assert_equal 4, image.height
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 0, g
    assert_equal 0, b
  end

  def test_decode_1bit_bmp_ico
    path = File.join(FIXTURE_DIR, "1bit.ico")
    image = Pura::Ico.decode(path)
    assert_equal 4, image.width
    assert_equal 4, image.height
    # Pixel (0,0) should be white (palette index 1)
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 255, g
    assert_equal 255, b
  end

  def test_decode_png_ico
    path = File.join(FIXTURE_DIR, "png_entry.ico")
    image = Pura::Ico.decode(path)
    assert_equal 4, image.width
    assert_equal 4, image.height
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 0, g
    assert_equal 0, b
  end

  def test_decode_from_binary_data
    data = File.binread(File.join(FIXTURE_DIR, "32bit.ico"))
    image = Pura::Ico.decode(data)
    assert_equal 4, image.width
    assert_equal 4, image.height
  end

  def test_decode_picks_largest_image
    path = File.join(FIXTURE_DIR, "multi_size.ico")
    image = Pura::Ico.decode(path)
    # Should pick the 8x8 image (largest)
    assert_equal 8, image.width
    assert_equal 8, image.height
  end

  def test_decode_cur_file
    path = File.join(FIXTURE_DIR, "test.cur")
    image = Pura::Ico.decode(path)
    assert_equal 4, image.width
    assert_equal 4, image.height
  end

  def test_pixel_at
    image = Pura::Ico.decode(File.join(FIXTURE_DIR, "32bit.ico"))
    assert_raises(IndexError) { image.pixel_at(-1, 0) }
    assert_raises(IndexError) { image.pixel_at(0, -1) }
    assert_raises(IndexError) { image.pixel_at(4, 0) }
    assert_raises(IndexError) { image.pixel_at(0, 4) }
  end

  def test_to_rgb_array
    image = Pura::Ico.decode(File.join(FIXTURE_DIR, "32bit.ico"))
    arr = image.to_rgb_array
    assert_equal 16, arr.size
    assert_equal 3, arr[0].size
    assert_equal [255, 0, 0], arr[0]
  end

  def test_to_ppm
    image = Pura::Ico.decode(File.join(FIXTURE_DIR, "32bit.ico"))
    ppm = image.to_ppm
    assert ppm.start_with?("P6\n4 4\n255\n".b)
    assert_equal "P6\n4 4\n255\n".bytesize + (4 * 4 * 3), ppm.bytesize
  end

  def test_version
    assert_match(/\A\d+\.\d+\.\d+\z/, Pura::Ico::VERSION)
  end

  def test_not_ico_file
    assert_raises(Pura::Ico::DecodeError) { Pura::Ico.decode("not an ico file at all".b) }
  end

  def test_image_invalid_pixel_size
    assert_raises(ArgumentError) { Pura::Ico::Image.new(2, 2, "\xFF\x00\x00".b) }
  end

  private

  def generate_fixtures
    generate_32bit_ico unless File.exist?(File.join(FIXTURE_DIR, "32bit.ico"))
    generate_24bit_ico unless File.exist?(File.join(FIXTURE_DIR, "24bit.ico"))
    generate_8bit_ico unless File.exist?(File.join(FIXTURE_DIR, "8bit.ico"))
    generate_4bit_ico unless File.exist?(File.join(FIXTURE_DIR, "4bit.ico"))
    generate_1bit_ico unless File.exist?(File.join(FIXTURE_DIR, "1bit.ico"))
    generate_png_ico unless File.exist?(File.join(FIXTURE_DIR, "png_entry.ico"))
    generate_multi_size_ico unless File.exist?(File.join(FIXTURE_DIR, "multi_size.ico"))
    generate_cur unless File.exist?(File.join(FIXTURE_DIR, "test.cur"))
  end

  # Build a minimal ICO file with BMP data
  def build_ico(width, height, bpp, pixel_data, palette: nil, type: 1)
    # BMP info header (BITMAPINFOHEADER = 40 bytes)
    bmp_header = [
      40,                  # header size
      width,               # width
      height * 2,          # height (doubled for AND mask)
      1,                   # planes
      bpp,                 # bits per pixel
      0,                   # compression
      0,                   # image size (can be 0)
      0,                   # x pixels per meter
      0,                   # y pixels per meter
      0,                   # colors used
      0                    # important colors
    ].pack("VVVvvVVVVVV")

    palette_data = palette ? palette.pack("C*") : "".b
    # AND mask: all zeros (all opaque) - aligned to 4 bytes per row
    and_stride = ((width + 31) / 32) * 4
    and_mask = ("\x00".b * and_stride) * height

    entry_data = bmp_header + palette_data + pixel_data + and_mask
    data_offset = 6 + 16 # header + 1 directory entry

    w_byte = width >= 256 ? 0 : width
    h_byte = height >= 256 ? 0 : height

    out = String.new(encoding: Encoding::BINARY)
    # ICO header
    out << [0, type, 1].pack("v3")
    # Directory entry
    out << [w_byte, h_byte, 0, 0].pack("C4")
    out << if type == 2 # CUR
             [0, 0].pack("v2") # hotspot x, y
           else
             [1, bpp].pack("v2") # planes, bpp
           end
    out << [entry_data.bytesize, data_offset].pack("V2")
    # Entry data
    out << entry_data
    out
  end

  def generate_32bit_ico
    width = 4
    height = 4
    # Rows stored bottom-up: row 3 first, row 0 last
    pixel_data = String.new(encoding: Encoding::BINARY)
    # Row 3 (bottom of image, stored first): white
    4.times { pixel_data << [255, 255, 255, 255].pack("C4") } # BGRA
    # Row 2: blue
    4.times { pixel_data << [255, 0, 0, 255].pack("C4") }
    # Row 1: green
    4.times { pixel_data << [0, 255, 0, 255].pack("C4") }
    # Row 0 (top of image, stored last): red
    4.times { pixel_data << [0, 0, 255, 255].pack("C4") }

    File.binwrite(File.join(FIXTURE_DIR, "32bit.ico"), build_ico(width, height, 32, pixel_data))
  end

  def generate_24bit_ico
    width = 4
    height = 4
    # 24-bit: 3 bytes per pixel, rows padded to 4-byte boundary
    row_bytes = width * 3 # 12 bytes, already 4-byte aligned
    pad = (4 - (row_bytes % 4)) % 4

    pixel_data = String.new(encoding: Encoding::BINARY)
    # Row 3 (white)
    4.times { pixel_data << [255, 255, 255].pack("C3") }
    pixel_data << ("\x00".b * pad)
    # Row 2 (blue)
    4.times { pixel_data << [255, 0, 0].pack("C3") }
    pixel_data << ("\x00".b * pad)
    # Row 1 (green)
    4.times { pixel_data << [0, 255, 0].pack("C3") }
    pixel_data << ("\x00".b * pad)
    # Row 0 (red - BGR format)
    4.times { pixel_data << [0, 0, 255].pack("C3") }
    pixel_data << ("\x00".b * pad)

    File.binwrite(File.join(FIXTURE_DIR, "24bit.ico"), build_ico(width, height, 24, pixel_data))
  end

  def generate_8bit_ico
    width = 4
    height = 4
    # Palette: 256 BGRA entries (only first 4 used)
    palette = []
    # Index 0: red (BGR format)
    palette.push(0, 0, 255, 0)
    # Index 1: green
    palette.push(0, 255, 0, 0)
    # Index 2: blue
    palette.push(255, 0, 0, 0)
    # Index 3: white
    palette.push(255, 255, 255, 0)
    # Fill remaining 252 entries
    252.times { palette.push(0, 0, 0, 0) }

    # 8-bit: 1 byte per pixel, padded to 4 bytes
    pixel_data = String.new(encoding: Encoding::BINARY)
    # Row 3 (white)
    pixel_data << [3, 3, 3, 3].pack("C4")
    # Row 2 (blue)
    pixel_data << [2, 2, 2, 2].pack("C4")
    # Row 1 (green)
    pixel_data << [1, 1, 1, 1].pack("C4")
    # Row 0 (red)
    pixel_data << [0, 0, 0, 0].pack("C4")

    File.binwrite(File.join(FIXTURE_DIR, "8bit.ico"), build_ico(width, height, 8, pixel_data, palette: palette))
  end

  def generate_4bit_ico
    width = 4
    height = 4
    # Palette: 16 BGRA entries
    palette = []
    # Index 0: red
    palette.push(0, 0, 255, 0)
    # Index 1: green
    palette.push(0, 255, 0, 0)
    # Index 2: blue
    palette.push(255, 0, 0, 0)
    # Index 3: white
    palette.push(255, 255, 255, 0)
    # Fill remaining 12
    12.times { palette.push(0, 0, 0, 0) }

    # 4-bit: 2 pixels per byte, rows padded to 4 bytes
    # Width=4, so 2 bytes per row, padded to 4
    pixel_data = String.new(encoding: Encoding::BINARY)
    # Row 3 (white): index 3 -> 0x33
    pixel_data << [0x33, 0x33, 0, 0].pack("C4")
    # Row 2 (blue): index 2 -> 0x22
    pixel_data << [0x22, 0x22, 0, 0].pack("C4")
    # Row 1 (green): index 1 -> 0x11
    pixel_data << [0x11, 0x11, 0, 0].pack("C4")
    # Row 0 (red): index 0 -> 0x00
    pixel_data << [0x00, 0x00, 0, 0].pack("C4")

    File.binwrite(File.join(FIXTURE_DIR, "4bit.ico"), build_ico(width, height, 4, pixel_data, palette: palette))
  end

  def generate_1bit_ico
    width = 4
    height = 4
    # Palette: 2 BGRA entries
    palette = []
    # Index 0: black
    palette.push(0, 0, 0, 0)
    # Index 1: white
    palette.push(255, 255, 255, 0)

    # 1-bit: width=4 -> 4 bits, padded to 4 bytes per row
    pixel_data = String.new(encoding: Encoding::BINARY)
    # All rows: all white (index 1) -> 0xF0 (1111_0000 for 4 pixels)
    4.times { pixel_data << [0xF0, 0, 0, 0].pack("C4") }

    File.binwrite(File.join(FIXTURE_DIR, "1bit.ico"), build_ico(width, height, 1, pixel_data, palette: palette))
  end

  def generate_png_ico
    require "pura-png"
    width = 4
    height = 4
    # Create red PNG
    pixels = "\xFF\x00\x00".b * (width * height)
    png_image = Pura::Png::Image.new(width, height, pixels)
    png_data = Pura::Png::Encoder.new(png_image).encode

    data_offset = 6 + 16
    out = String.new(encoding: Encoding::BINARY)
    out << [0, 1, 1].pack("v3")
    out << [width, height, 0, 0].pack("C4")
    out << [1, 32].pack("v2")
    out << [png_data.bytesize, data_offset].pack("V2")
    out << png_data

    File.binwrite(File.join(FIXTURE_DIR, "png_entry.ico"), out)
  end

  def generate_multi_size_ico
    require "pura-png"

    # Two entries: 4x4 and 8x8
    red4 = "\xFF\x00\x00".b * 16
    png4 = Pura::Png::Encoder.new(Pura::Png::Image.new(4, 4, red4)).encode

    green8 = "\x00\xFF\x00".b * 64
    png8 = Pura::Png::Encoder.new(Pura::Png::Image.new(8, 8, green8)).encode

    header_size = 6 + (16 * 2)
    offset1 = header_size
    offset2 = header_size + png4.bytesize

    out = String.new(encoding: Encoding::BINARY)
    out << [0, 1, 2].pack("v3")

    # Entry 1: 4x4
    out << [4, 4, 0, 0].pack("C4")
    out << [1, 32].pack("v2")
    out << [png4.bytesize, offset1].pack("V2")

    # Entry 2: 8x8
    out << [8, 8, 0, 0].pack("C4")
    out << [1, 32].pack("v2")
    out << [png8.bytesize, offset2].pack("V2")

    out << png4 << png8

    File.binwrite(File.join(FIXTURE_DIR, "multi_size.ico"), out)
  end

  def generate_cur
    width = 4
    height = 4
    pixel_data = String.new(encoding: Encoding::BINARY)
    4.times { pixel_data << [255, 255, 255, 255].pack("C4") }
    4.times { pixel_data << [255, 0, 0, 255].pack("C4") }
    4.times { pixel_data << [0, 255, 0, 255].pack("C4") }
    4.times { pixel_data << [0, 0, 255, 255].pack("C4") }

    File.binwrite(File.join(FIXTURE_DIR, "test.cur"), build_ico(width, height, 32, pixel_data, type: 2))
  end
end

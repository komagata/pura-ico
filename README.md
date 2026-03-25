# pura-ico

A pure Ruby ICO decoder/encoder with zero C extension dependencies.

Part of the **pura-*** series — pure Ruby image codec gems.

## Features

- ICO decoding and encoding
- Handles both BMP-style and PNG-style icon entries
- Multiple icon sizes in a single file
- Image resizing (bilinear / nearest-neighbor / fit / fill)
- No native extensions, no FFI, no external dependencies
- CLI tool included

## Installation

```bash
gem install pura-ico
```

## Usage

```ruby
require "pura-ico"

# Decode (extracts the first/largest entry)
image = Pura::Ico.decode("favicon.ico")
image.width      #=> 32
image.height     #=> 32
image.pixels     #=> Raw RGB byte string
image.pixel_at(x, y) #=> [r, g, b]

# Encode
Pura::Ico.encode(images, "favicon.ico")

# Resize
thumb = image.resize(16, 16)
```

## CLI

```bash
pura-ico decode favicon.ico --info
```

## Why pure Ruby?

- **`gem install` and go** — no `brew install`, no `apt install`, no C compiler needed
- **Works everywhere Ruby works** — CRuby, ruby.wasm, JRuby, TruffleRuby
- **Both BMP and PNG entries** — handles all common ICO formats
- **Part of pura-\*** — convert between JPEG, PNG, BMP, GIF, TIFF, WebP, ICO seamlessly

## Related gems

| Gem | Format | Status |
|-----|--------|--------|
| [pura-jpeg](https://github.com/komagata/pura-jpeg) | JPEG | ✅ Available |
| [pura-png](https://github.com/komagata/pura-png) | PNG | ✅ Available |
| [pura-bmp](https://github.com/komagata/pura-bmp) | BMP | ✅ Available |
| [pura-gif](https://github.com/komagata/pura-gif) | GIF | ✅ Available |
| [pura-tiff](https://github.com/komagata/pura-tiff) | TIFF | ✅ Available |
| **pura-ico** | ICO | ✅ Available |
| [pura-webp](https://github.com/komagata/pura-webp) | WebP | ✅ Available |
| [pura-image](https://github.com/komagata/pura-image) | All formats | ✅ Available |

## License

MIT

# frozen_string_literal: true

$LOAD_PATH.unshift(File.join("/tmp/pura-png", "lib"))
require_relative "../lib/pura-ico"

module DecodeBenchmark
  def self.run(input)
    unless File.exist?(input)
      puts "Generating test ICO file..."
      unless generate_test_ico(input)
        $stderr.puts "Error: could not generate test ICO. Provide an existing ICO file."
        exit 1
      end
    end

    file_size = File.size(input)
    puts "Benchmark: decoding #{input} (#{file_size} bytes)"
    puts "=" * 60

    results = []

    # pura-ico
    results << bench("pura-ico") do
      image = Pura::Ico.decode(input)
      image.pixels.bytesize
    end

    # ffmpeg
    results << bench("ffmpeg") do
      out = `ffmpeg -v quiet -i #{shell_escape(input)} -f rawvideo -pix_fmt rgb24 pipe:1 2>/dev/null`
      $?.success? ? out.bytesize : nil
    end

    # Print results table
    puts
    puts format("%-15s %12s %15s %s", "Decoder", "Time (ms)", "Output (bytes)", "Status")
    puts "-" * 60
    results.each do |r|
      time_str = r[:time] ? format("%.2f", r[:time] * 1000) : "N/A"
      size_str = r[:output_size] ? r[:output_size].to_s : "N/A"
      status = r[:note] || "ok"
      puts format("%-15s %12s %15s %s", r[:name], time_str, size_str, status)
    end

    # Memory usage
    puts
    puts "Memory usage (current process): #{memory_usage_kb} KB"
  end

  def self.bench(name)
    GC.start
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    output_size = yield
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

    if output_size
      { name: name, time: elapsed, output_size: output_size }
    else
      { name: name, time: nil, output_size: nil, note: "failed" }
    end
  rescue => e
    { name: name, time: nil, output_size: nil, note: "error: #{e.message}" }
  end

  def self.generate_test_ico(path)
    # Create a simple 64x64 ICO
    pixels = String.new(encoding: Encoding::BINARY, capacity: 64 * 64 * 3)
    64.times do |y|
      64.times do |x|
        r = (x * 255 / 63)
        g = (y * 255 / 63)
        b = 128
        pixels << r.chr << g.chr << b.chr
      end
    end
    image = Pura::Ico::Image.new(64, 64, pixels)
    Pura::Ico.encode(image, path)
    true
  rescue
    false
  end

  def self.memory_usage_kb
    if RUBY_PLATFORM =~ /darwin/
      `ps -o rss= -p #{$$}`.strip.to_i
    elsif File.exist?("/proc/#{$$}/status")
      File.read("/proc/#{$$}/status")[/VmRSS:\s+(\d+)/, 1].to_i
    else
      0
    end
  end

  def self.shell_escape(s)
    "'" + s.gsub("'", "'\\''") + "'"
  end
end

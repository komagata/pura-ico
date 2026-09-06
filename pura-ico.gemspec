# frozen_string_literal: true

require_relative "lib/pura/ico/version"

Gem::Specification.new do |spec|
  spec.name = "pura-ico"
  spec.version = Pura::Ico::VERSION
  spec.authors = ["komagata"]
  spec.summary = "Pure Ruby ICO encoder and ICO/CUR decoder"
  spec.description = "A Ruby ICO/CUR decoder and ICO encoder using pura-png for PNG entries. " \
                     "Supports BMP and PNG icon entries, multiple bit depths, and multi-size ICO files."
  spec.homepage = "https://github.com/komagata/pura-ico"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir["lib/**/*.rb", "bin/*", "LICENSE", "README.md"]
  spec.bindir = "bin"
  spec.executables = ["pura-ico"]

  spec.add_dependency "pura-png", "~> 0.1"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end

# frozen_string_literal: true

require_relative 'lib/potty/version'

Gem::Specification.new do |spec|
  spec.name          = 'potty'
  spec.version       = Potty::VERSION
  spec.authors       = ['TwilightCoders']
  spec.email         = ['info@twilightcoders.net']

  spec.summary       = 'A curses-based terminal UI framework for Ruby'
  spec.description   = 'Provides views, widgets, layout, theming, and frame-based animation for building curses TUI applications.'
  spec.homepage      = 'https://github.com/TwilightCoders/potty'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['source_code_uri'] = 'https://github.com/TwilightCoders/potty'
  spec.metadata['changelog_uri'] = 'https://github.com/TwilightCoders/potty/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = (Dir.glob('{lib,examples,bin}/**/*') + %w[LICENSE.txt README.md CHANGELOG.md]).select { |f| File.file?(f) }
  spec.bindir = 'bin'
  spec.executables = ['potty_demo']
  spec.require_paths = ['lib']

  spec.add_dependency 'curses', '~> 1.4'

  spec.add_development_dependency 'rspec', '~> 3.12'
end

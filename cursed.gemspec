# frozen_string_literal: true

require_relative 'lib/cursed/version'

Gem::Specification.new do |spec|
  spec.name          = 'cursed'
  spec.version       = Cursed::VERSION
  spec.authors       = ['TwilightCoders']
  spec.email         = ['info@twilightcoders.net']

  spec.summary       = 'A curses-based terminal UI framework for Ruby'
  spec.description   = 'Provides views, widgets, layout, theming, and frame-based animation for building curses TUI applications.'
  spec.homepage      = 'https://github.com/TwilightCoders/cursed'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/TwilightCoders/cursed'

  spec.files = Dir.glob('{lib,examples}/**/*') + %w[LICENSE.txt README.md]
  spec.require_paths = ['lib']

  spec.add_dependency 'curses', '~> 1.4'

  spec.add_development_dependency 'rspec', '~> 3.12'
end

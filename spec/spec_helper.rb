# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'cursed'

# Logic-only specs: widgets are exercised through their public API
# (handle_key, tick, accessors) without invoking curses rendering, so no
# init_screen / real TTY is required. `app` is a bare stand-in since only
# render() touches app.theme.
module CursedSpec
  def self.app
    Object.new
  end
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end

# frozen_string_literal: true

module Potty
  # A one-shot timer on the Application's tick clock. Created by
  # Application#schedule(after_seconds) { … }; fires its block once, the first
  # tick at or after `after_seconds` have elapsed. The clock starts on the
  # first tick after scheduling (same model as Countdown), so it's robust to a
  # late first frame and deterministic to unit-test (drive #tick with explicit
  # Times). Cancel before it fires with #cancel.
  class ScheduledTask
    def initialize(after_seconds, block)
      @after = after_seconds
      @block = block
      @due = nil
      @cancelled = false
      @fired = false
    end

    def cancel
      @cancelled = true
    end

    def cancelled?
      @cancelled
    end

    def fired?
      @fired
    end

    # Advance against the frame's clock. Returns true once it has fired (or is
    # cancelled), signalling the Application to drop it.
    def tick(now)
      return true if @cancelled
      return true if @fired

      @due ||= now + @after
      return false if now < @due

      @fired = true
      @block&.call
      true
    end
  end
end

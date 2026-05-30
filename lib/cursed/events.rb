# frozen_string_literal: true

module Cursed
  # A tiny event-emitter mixin so widgets can be wired together
  # declaratively. Any includer gains `on`/`off`/`emit`. Widgets emit
  # semantic events (`:change`, `:focus`, `:select`, `:press`, …) that a
  # consumer subscribes to with blocks — letting a View stitch its pieces
  # together without each widget needing a bespoke callback setter:
  #
  #   input.on(:change)  { |text| preview.text = text }
  #   toggle.on(:change) { |on|   advanced.visible = on }
  #   button.on(:press)  { app.pop_view }
  #
  # `on` returns self, so subscriptions chain. Multiple listeners per event
  # are supported and fire in registration order.
  module Events
    def on(event, &block)
      return self unless block

      (@listeners ||= {})[event.to_sym] ||= []
      @listeners[event.to_sym] << block
      self
    end

    # Remove listeners for one event, or all events when called bare.
    def off(event = nil)
      @listeners ||= {}
      event ? @listeners.delete(event.to_sym) : @listeners.clear
      self
    end

    # Fire an event to its listeners. Returns true if any listener ran.
    def emit(event, *args)
      list = (@listeners ||= {})[event.to_sym]
      return false if list.nil? || list.empty?

      list.each { |cb| cb.call(*args) }
      true
    end

    def listeners?(event)
      list = (@listeners ||= {})[event.to_sym]
      !(list.nil? || list.empty?)
    end
  end
end

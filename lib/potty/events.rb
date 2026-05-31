# frozen_string_literal: true

module Potty
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
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level declaration of the events a widget fires. For each name it
    # generates the legacy `on_<name>` callback accessor plus a private
    # `fire_<name>` helper that calls that callback (when set) AND emits to
    # `on(:<name>)` listeners. This is the one home for the "invoke the setter,
    # then emit" dual-fire — instead of open-coding the pair at every trigger:
    #
    #   class Toggle < Base
    #     emits :change          # => attr_accessor :on_change + fire_change(*)
    #   end
    #   ...
    #   fire_change(@value)      # @on_change&.call(@value); emit(:change, @value)
    #
    # Names stay grep-able: search `emits :change` for the declaration and
    # `fire_change` for every trigger site.
    module ClassMethods
      def emits(*names)
        names.each do |name|
          attr_accessor "on_#{name}"
          define_method("fire_#{name}") do |*args|
            send("on_#{name}")&.call(*args)
            emit(name, *args)
          end
          private "fire_#{name}"
        end
      end
    end

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

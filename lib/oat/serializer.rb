require 'support/class_attribute'
module Oat
  class Serializer

    class_attribute :_adapter, :logger

    class << self
      attr_accessor :type
    end

    def self.schema(&block)
      _superclass = superclass
      if block_given?
        if _superclass.ancestors.include?(Oat::Serializer) && _superclass.schema
          @schema = Proc.new do
            instance_eval(&_superclass.schema)
            instance_eval(&block)
          end
        else
          @schema = block
        end
      end
      @schema
    end

    def self.adapter(adapter_class = nil)
      self._adapter = adapter_class if adapter_class
      self._adapter
    end

    def self.warn(msg)
      logger ? logger.warning(msg) : Kernel.warn(msg)
    end

    attr_reader :item, :context, :adapter_class, :adapter, :options

    def initialize(item, context = nil, _adapter_class = nil, parent_serializer = nil, options = {})
      @item = item
      @context = context || {}
      @parent_serializer = parent_serializer
      @options = options
      @adapter_class = _adapter_class || self.class.adapter
      @adapter = @adapter_class.new(self)
      if self.class.type
        type(self.class.type)
      end
      @context[:_serialized_entities] ||= Hash.new { |h, k| h[k] = Hash.new }
    end

    def top
      @top ||= @parent_serializer || self
    end

    def method_missing(name, *args, &block)
      if adapter.respond_to?(name)
        adapter.send(name, *args, &block)
      else
        super
      end
    end

    def type(*args)
      if adapter.respond_to?(:type) && adapter.method(:type).arity != 0
        adapter.type(*args)
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      adapter.respond_to? method_name
    end

    def to_hash
      @to_hash ||= (
        schema = self.class.schema
        instance_eval(&schema) if schema
        adapter.to_hash
      )
    end

    def map_properties(*args)
      args.each { |name| map_property name }
    end

    def map_property(name)
      value = item.send(name)
      property name, value
    end

    def should_serialize(type, id)
      if @context[:_serialized_entities][type][id]
        false
      else
        @context[:_serialized_entities][type][id] = true
        true
      end
    end

  end
end

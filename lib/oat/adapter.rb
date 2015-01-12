require 'oat/props'
module Oat
  class Adapter

    def initialize(serializer)
      @serializer = serializer
      @data = Hash.new{|h,k| h[k] = {}}
    end

    def to_hash
      data
    end

    protected

    attr_reader :data, :serializer

    def yield_props(&block)
      props = Props.new
      serializer.instance_exec(props, &block)
      props.to_hash
    end

    def serializer_from_block_or_class(obj, serializer_class = nil, context_options = {}, &block)
      return nil if obj.nil?

      if block_given?
        serializer_class = Class.new(serializer.class)
        serializer_class.adapter self.class
        s = serializer_class.new(obj, serializer.context.merge(context_options), serializer.adapter_class, serializer.top)
        serializer.instance_exec(obj, s, &block)
        s
      else
        if serializer_class.nil? && @serializer.class.respond_to?(:serializer_class)
          _serializer_class = @serializer.class.serializer_class(obj)
        elsif serializer_class.is_a?(Proc)
          _serializer_class = serializer_class.call(obj)
        else
          _serializer_class = serializer_class
        end
        _serializer_class.new(obj, serializer.context.merge(context_options), serializer.adapter_class, serializer.top)
      end
    end
  end
end

# http://jsonapi.org/format/#url-based-json-api
require 'active_support/inflector'
require 'active_support/core_ext/string/inflections'
unless defined?(String.new.pluralize)
  class String
    include ActiveSupport::CoreExtensions::String::Inflections
  end
end

module Oat
  module Adapters

    class JsonAPI < Oat::Adapter

      def initialize(*args)
        super
        @links = {}
        @link_templates = {}
        @meta = {}
      end

      def rel(rels)
        # no-op to maintain interface compatibility with the Siren adapter
      end

      def type(*types)
        @root_name = types.first.to_s.pluralize.to_sym
      end

      def link(rel, opts = {})
        templated = false
        if opts.is_a?(Hash)
          templated = opts.delete(:templated)
          if templated
            link_template(rel, opts[:href])
          else
            check_link_keys(opts)
          end
        end
        data[:links][rel] = opts unless templated
      end

      def check_link_keys(opts)
        unsupported_opts = opts.keys - [:href, :id, :ids, :type]

        unless unsupported_opts.empty?
          raise ArgumentError, "Unsupported opts: #{unsupported_opts.join(", ")}"
        end
        if opts.has_key?(:id) && opts.has_key?(:ids)
          raise ArgumentError, "ops canot contain both :id and :ids"
        end
      end
      private :check_link_keys

      def link_template(key, value)
        @link_templates[key] = value
      end
      private :link_template

      def properties(&block)
        data.merge! yield_props(&block)
      end

      def property(key, value)
        data[key] = value
      end

      def meta(key, value)
        @meta[key] = value
      end

      def entity(name, obj, serializer_class = nil, options = {}, &block)
        polymorphic = options.delete(:polymorphic)
        entity_name = options.delete(:entity_name)
        ent = serializer_from_block_or_class(obj, serializer_class, options, &block)
        if ent
          if entity_name
            if entity_name.is_a?(Proc)
              _name = entity_name.call(obj).try(:to_sym)
            else
              _name = entity_name
            end
          else
            _name = entity_name(name)
          end
          entity_hash[_name.to_s.pluralize.to_sym] ||= []
          data[:relationships][entity_name(name)] = {
            data: {
              id: ent.item.id,
              type: _name
            }
          }
          if serializer.should_serialize(_name, ent.item.id)
            ent_hash = ent.to_hash
            entity_hash[_name.to_s.pluralize.to_sym] << ent_hash
          end
        end
      end

      def entities(name, collection, serializer_class = nil, context_options = nil, &block)
        return if collection.nil? || collection.empty?
        context_options ||= {}
        link_name = entity_name(name)
        _name = link_name.to_s.singularize.to_sym
        data[:relationships][link_name] = {data: []}

        collection.each do |obj|
          entity_hash[link_name] ||= []
          ent = serializer_from_block_or_class(obj, serializer_class, context_options, &block)
          if ent
            data[:relationships][link_name][:data] << {type: link_name, id: ent.item.id}
            if serializer.should_serialize(_name, ent.item.id)
              ent_hash = ent.to_hash
              entity_hash[link_name] << ent_hash
            end
          end
        end
      end

      def entity_name(name)
        # entity name may be an array, but JSON API only uses the first
        name.respond_to?(:first) ? name.first : name
      end

      private :entity_name

      def collection(name, collection, serializer_class = nil, context_options = nil, &block)
        context_options ||= {}
        @treat_as_resource_collection = true
        data[:resource_collection] = [] unless data[:resource_collection].is_a?(Array)

        collection.each do |obj|
          ent = serializer_from_block_or_class(obj, serializer_class, context_options, &block)
          if ent && serializer.should_serialize(root_name, ent.item.id)
            data[:resource_collection] << ent.to_hash
          end
        end
      end

      def to_hash
        raise "JSON API entities MUST define a type. Use type 'user' in your serializers" unless root_name
        if serializer.top != serializer
          return data
        else
          h = {}
          if @treat_as_resource_collection
            h[:data] = data[:resource_collection].map { |d| to_json_api_data(root_name, d) }
          else
            h[:data] = to_json_api_data(root_name, data)
          end
          if @links.values.any?
            h[:included] = @links.map { |type, entities| entities.map { |e| to_json_api_data(type, e) } }.flatten
          end
          h[:data][:links] = @link_templates if @link_templates.keys.any?
          h[:meta] = @meta if @meta.keys.any?
          h
        end
      end

      protected

      attr_reader :root_name

      def entity_hash
        if serializer.top == serializer
          @links
        else
          serializer.top.adapter.entity_hash
        end
      end

      def entity_without_root(obj, serializer_class = nil, &block)
        ent = serializer_from_block_or_class(obj, serializer_class, &block)
        ent.to_hash.values.first.first if ent
      end

      def to_json_api_data(type, data)
        h = {
          type: type,
          id: data[:id],
          attributes: Hash[data.except(:id, :relationships).sort]
        }
        h[:relationships] = data[:relationships] if data[:relationships].present?
        h
      end

    end
  end
end

# frozen_string_literal: true

module Switchman
  module ActiveRecord
    module ConnectionHandler
      def resolve_pool_config(config, connection_name, role, shard)
        ret = super
        # Make pool configs share a schema reflection. By default every pool
        # shares one global reflection (all shards have identical schemas). When
        # namespace_schema_cache is enabled, each connection class gets its own
        # reflection, so databases with different schemas don't collide.
        ret.schema_reflection = ConnectionHandler.schema_reflection_for(connection_name)
        ret
      end

      def self.schema_reflection_for(connection_name)
        return global_schema_reflection unless Switchman.config[:namespace_schema_cache]

        namespaced_schema_reflections[schema_reflection_key(connection_name)] ||=
          ::ActiveRecord::ConnectionAdapters::SchemaReflection.new(nil)
      end

      def self.global_schema_reflection
        @global_schema_reflection ||= ::ActiveRecord::ConnectionAdapters::SchemaReflection.new(nil)
      end

      def self.namespaced_schema_reflections
        @namespaced_schema_reflections ||= {}
      end

      # Mirrors ActiveRecord's own pool-manager keying: the primary class is
      # always "ActiveRecord::Base", every other connection class uses its
      # fully-qualified name (so QuizApi::ApplicationRecord and
      # QuizLti::ApplicationRecord stay distinct even if base names collide).
      def self.schema_reflection_key(connection_name)
        connection_name.primary_class? ? "ActiveRecord::Base" : connection_name.name
      end
    end
  end
end

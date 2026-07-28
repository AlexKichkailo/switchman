# frozen_string_literal: true

module Switchman
  module ActiveRecord
    module Tasks
      module DatabaseTasks
        def drop(*)
          super
          # no really, it's gone
          Switchman.cache.delete("default_shard")
          Shard.default(reload: true)
        end

        def raise_for_multi_db(*)
          # ignore; Switchman doesn't use namespaced tasks for multiple shards; it uses
          # environment variables to filter which shards you want to target
        end

        # Rails resolves the connection that migrations execute against from
        # +migration_class+, which is hardcoded to ActiveRecord::Base. An
        # application with a second sharded connection class has to be able to
        # run migrations against that class's pool instead.
        def migration_class
          Thread.current[:switchman_migration_class] || super
        end

        def with_migration_class(klass)
          previous = Thread.current[:switchman_migration_class]
          Thread.current[:switchman_migration_class] = klass
          yield
        ensure
          Thread.current[:switchman_migration_class] = previous
        end
      end
    end
  end
end

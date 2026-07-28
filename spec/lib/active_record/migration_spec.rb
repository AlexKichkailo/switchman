# frozen_string_literal: true

require "spec_helper"

module Switchman
  module ActiveRecord
    describe Migration do
      include RSpecHelper

      describe "#connection" do
        it "returns a connection aligned to its own pool's shard" do
          migration = ::ActiveRecord::Migration.new
          conn = migration.connection
          expect(conn.shard).to eq(conn.pool.send(:current_shard))
        end

        it "delegates the shard switch to the connection's own pool" do
          migration = ::ActiveRecord::Migration.new
          pool = ::ActiveRecord::Base.connection_pool
          expect(pool).to receive(:ensure_shard).at_least(:once).and_call_original
          migration.connection
        end
      end
    end

    describe MigrationContext do
      include RSpecHelper

      def build_context
        ::ActiveRecord::MigrationContext.new(::ActiveRecord::Migrator.migrations_paths)
      end

      describe "#migration_schema_reflection" do
        it "resolves the reflection from the migration's own pool" do
          context = build_context
          migration_pool = if ::Rails.version < "7.2"
                             context.send(:connection).pool
                           else
                             context.send(:connection_pool)
                           end
          expect(context.send(:migration_schema_reflection)).to be(migration_pool.schema_reflection)
        end

        it "uses the migration pool, not a hardcoded ActiveRecord::Base pool" do
          distinct = ::ActiveRecord::ConnectionAdapters::SchemaReflection.new(nil)
          fake_pool = instance_double(::ActiveRecord::ConnectionAdapters::ConnectionPool,
                                      schema_reflection: distinct)
          context = build_context
          if ::Rails.version < "7.2"
            allow(context).to receive(:connection).and_return(double("conn", pool: fake_pool))
          else
            allow(context).to receive(:connection_pool).and_return(fake_pool)
          end
          expect(context.send(:migration_schema_reflection)).to be(distinct)
        end
      end
    end
  end
end

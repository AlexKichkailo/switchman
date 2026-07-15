# frozen_string_literal: true

require "spec_helper"

module Switchman
  module ActiveRecord
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

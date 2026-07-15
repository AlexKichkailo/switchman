# frozen_string_literal: true

require "spec_helper"

# A throwaway abstract connection class used to exercise resolve_pool_config
# against a real, non-primary owner without ever touching ActiveRecord::Base's
# own connection pool. It has to be a real, reachable constant (not an
# anonymous class with a fake name) because Switchman's own connection pool
# code resolves the owner class back from its descriptor name via
# +constantize+.
class ConnectionHandlerSpecOwner < ActiveRecord::Base
  self.abstract_class = true
end

module Switchman
  module ActiveRecord
    describe ConnectionHandler do
      include RSpecHelper

      # Stands in for the connection class / descriptor ActiveRecord hands to
      # resolve_pool_config. Responds to the two messages the lookup needs.
      def fake_connection_name(name, primary: false)
        double(name:, primary_class?: primary)
      end

      describe "#resolve_pool_config" do
        it "shares the schema reflection" do
          server_reflection = ::ActiveRecord::Base.establish_connection.pool_config.schema_reflection
          server2_reflection = @shard2.activate do
            ::ActiveRecord::Base.establish_connection.pool_config.schema_reflection
          end
          expect(server_reflection).to be(server2_reflection)
        end
      end

      describe ".schema_reflection_for" do
        around do |example|
          example.run
        ensure
          Switchman.config.delete(:namespace_schema_cache)
          ConnectionHandler.instance_variable_set(:@namespaced_schema_reflections, nil)
        end

        context "when namespacing is disabled" do
          it "returns the single global reflection regardless of connection name" do
            a = ConnectionHandler.schema_reflection_for(fake_connection_name("QuizApi::ApplicationRecord"))
            b = ConnectionHandler.schema_reflection_for(fake_connection_name("QuizLti::ApplicationRecord"))
            expect(a).to be(b)
            expect(a).to be(ConnectionHandler.global_schema_reflection)
          end
        end

        context "when namespacing is enabled" do
          before { Switchman.config[:namespace_schema_cache] = true }

          it "reuses one reflection for the same connection class" do
            a = ConnectionHandler.schema_reflection_for(fake_connection_name("QuizApi::ApplicationRecord"))
            b = ConnectionHandler.schema_reflection_for(fake_connection_name("QuizApi::ApplicationRecord"))
            expect(a).to be(b)
          end

          it "returns distinct reflections for different connection classes" do
            a = ConnectionHandler.schema_reflection_for(fake_connection_name("QuizApi::Quiz"))
            b = ConnectionHandler.schema_reflection_for(fake_connection_name("QuizLti::Submission"))
            expect(a).not_to be(b)
          end

          it "distinguishes identical base names in different namespaces" do
            a = ConnectionHandler.schema_reflection_for(fake_connection_name("QuizApi::ApplicationRecord"))
            b = ConnectionHandler.schema_reflection_for(fake_connection_name("QuizLti::ApplicationRecord"))
            expect(a).not_to be(b)
          end

          it "buckets every primary class into one reflection" do
            a = ConnectionHandler.schema_reflection_for(fake_connection_name("ApplicationRecord", primary: true))
            b = ConnectionHandler.schema_reflection_for(fake_connection_name("ActiveRecord::Base", primary: true))
            expect(a).to be(b)
          end

          it "does not return the global reflection" do
            a = ConnectionHandler.schema_reflection_for(fake_connection_name("QuizApi::ApplicationRecord"))
            expect(a).not_to be(ConnectionHandler.global_schema_reflection)
          end

          it "assigns a namespaced reflection to a real established connection without raising" do
            # resolve_pool_config runs for any owner class, not just the primary
            # one. Establishing a connection for a throwaway abstract class
            # exercises the real override end-to-end, the same way a genuine
            # establish_connection call would, without ever reconnecting (and
            # risking corrupting) ActiveRecord::Base's own live pool.
            ConnectionHandlerSpecOwner.establish_connection(::ActiveRecord::Base.connection_db_config)
            reflection = ConnectionHandlerSpecOwner.connection_pool.pool_config.schema_reflection
            expect(reflection).not_to be(ConnectionHandler.global_schema_reflection)
          ensure
            ConnectionHandlerSpecOwner.remove_connection
            Switchman.config.delete(:namespace_schema_cache)
            ConnectionHandler.instance_variable_set(:@namespaced_schema_reflections, nil)
          end
        end
      end
    end
  end
end

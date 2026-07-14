# frozen_string_literal: true

require "spec_helper"

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
        end
      end
    end
  end
end

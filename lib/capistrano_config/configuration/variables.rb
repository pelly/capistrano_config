require "capistrano_config/proc_helpers"

module CapistranoConfig
  class Configuration
    # Holds the variables assigned at Capistrano runtime via `set` and retrieved
    # with `fetch`. Does internal bookkeeping to help identify user mistakes
    # like spelling errors or unused variables that may lead to unexpected
    # behavior.
    class Variables

      class NonCachingProc < Proc
      end

      module NonCacheable
        extend self

        def no_cache(&block)
          NonCachingProc.new(&block)
        end

        alias_method :dont_cache, :no_cache
      end

      CAPISTRANO_LOCATION = File.expand_path("../..", __FILE__).freeze
      IGNORED_LOCATIONS = [
        "#{CAPISTRANO_LOCATION}/configuration/variables.rb:",
        "#{CAPISTRANO_LOCATION}/configuration.rb:",
        "#{CAPISTRANO_LOCATION}/dsl/env.rb:",
        "/dsl.rb:",
        "/forwardable.rb:"
      ].freeze
      private_constant :CAPISTRANO_LOCATION, :IGNORED_LOCATIONS

      include CapistranoConfig::ProcHelpers
      include NonCacheable

      def initialize(values = {}, indifferent_access: true)
        @trusted_keys = []
        @fetched_keys = []
        @locations = {}
        @values = values
        @trusted = true
        @indifferent_access = indifferent_access
      end

      def untrusted!
        @trusted = false
        yield
      ensure
        @trusted = true
      end

      def merge!(other)
        other.each do |key, value|
          set(key, value)
        end
      end

      def set(key, value = nil, &block)
        key = key.to_sym if @indifferent_access
        @trusted_keys << key if trusted? && !@trusted_keys.include?(key)
        remember_location(key)
        values[key] = block || value
        trace_set(key)
        values[key]
      end

      def fetch!(key, &block)
        key = key.to_sym if @indifferent_access
        raise "#{key.inspect} does not exist in variables keys" unless has_key?(key)
        fetch(key, &block)
      end

      def fetch(key, default = nil, &block)
        key = key.to_sym if @indifferent_access
        fetched_keys << key unless fetched_keys.include?(key)
        peek(key, default, &block)
      end

      # Internal use only.
      def peek(key, default = nil, &block)
        key = key.to_sym if @indifferent_access
        value = fetch_for(key, default, &block)
        while callable_without_parameters?(value)
          value = value.call
        end
        value
      end

      def fetch_for(key, default, &block)
        key = key.to_sym if @indifferent_access
        block ? values.fetch(key, &block) : values.fetch(key, default)
      end

      def delete(key)
        key = key.to_sym if @indifferent_access
        values.delete(key)
      end

      def trusted_keys
        @trusted_keys.dup
      end

      def untrusted_keys
        keys - @trusted_keys
      end

      def keys
        values.keys
      end

      def has_key?(key)
        values.has_key?(key)
      end

      # Keys that have been set, but which have never been fetched.
      def unused_keys
        keys - fetched_keys
      end

      # Returns an array of source file location(s) where the given key was
      # assigned (i.e. where `set` was called). If the key was never assigned,
      # returns `nil`.
      def source_locations(key)
        key = key.to_sym if @indifferent_access
        locations[key]
      end

      private

      attr_reader :locations, :values, :fetched_keys

      def trusted?
        @trusted
      end

      def remember_location(key)
        location = caller.find do |line|
          IGNORED_LOCATIONS.none? { |i| line.include?(i) }
        end
        (locations[key] ||= []) << location
      end

      def trace_set(key)
        return unless fetch(:print_config_variables, false)
        puts "Config variable set: #{key.inspect} => #{values[key].inspect}"
      end
    end
  end
end

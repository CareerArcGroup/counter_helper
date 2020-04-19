# frozen_string_literal: true

require 'logger'

module CounterHelper
  class Config
    attr_accessor :options

    DEFAULT_GRANULARITY = 60 # 1 minute
    DEFAULT_EXPIRATION = 60 * 60 * 2 # 2 hours

    class << self
      def configure(options = {})
        @instance = new(options)
      end

      def instance
        @instance ||= new
      end

      def redis
        instance.redis
      end

      def redis_prefix
        instance.redis_prefix
      end

      def granularity
        instance.granularity
      end

      def expiration
        instance.expiration
      end

      def log_formatter
        instance.log_formatter
      end

      def logger
        instance.logger
      end
    end

    def initialize(options = {})
      @options = options
      @redis   = options[:redis].is_a?(Hash) ? Redis.new(options[:redis]) : options[:redis]

      raise ArgumentError, 'granularity cannot be larger than expiration' if granularity > expiration
      raise ArgumentError, 'expiration cannot be less than or equal to granularity' if expiration <= granularity
    end

    def redis
      @redis || options[:redis]
    end

    def redis_prefix
      options[:redis_prefix]
    end

    def granularity
      options.fetch(:granularity, DEFAULT_GRANULARITY)
    end

    def expiration
      options.fetch(:expiration, DEFAULT_EXPIRATION)
    end

    def log_formatter
      options[:log_formatter]
    end

    def logger
      @logger ||= options.fetch(:logger, Logger.new(STDOUT))
    end
  end
end

module CounterHelper
  class Config
    class << self
      require 'logger'
      attr_accessor :redis_prefix, :log_formatter

      DEFAULT_GRANULARITY = 60 # 1 minute
      DEFAULT_EXPIRATION = 60 * 60 * 2 # 2 hours

      def from_options(options={})
        options.each do |key, value|
          send(:"#{key}=", value) if respond_to?(:"#{key}=")
        end
      end

      def redis
        @redis || Redis.current
      end

      def redis=(value)
        @redis = value.is_a?(Hash) ? Redis.new(value) : value
      end

      def granularity
        @granularity || DEFAULT_GRANULARITY
      end

      def granularity=(value)
        raise ArgumentError, "granularity cannot be larger than expiration" if value > expiration

        @granularity = value
      end

      def expiration
        @expiration || DEFAULT_EXPIRATION
      end

      def expiration=(value)
        raise ArgumentError, "expiration cannot be less than or equal to granularity" if value <= granularity

        @expiration = value
      end

      def logger
        @logger ||= Logger.new(STDOUT)
      end

      def logger=(l)
        @logger = l
      end
    end
  end
end
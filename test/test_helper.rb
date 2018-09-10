$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'counter_helper'
require 'minitest/autorun'
require 'yaml'

class TestHelper
  class << self
    def configure_redis
      config_path = "redis.yml"

      if File.exist?(config_path)
        Redis.current = Redis.new(YAML.load(File.read(config_path)))
      else
        puts "No redis.yml file found in root directory, using default connection settings..."
      end
    end

    def keys
      @keys ||= []
    end

    def create_key(prefix)
      keys.push("#{prefix}_#{rand}").last
    end

    def unregister_keys
      keys.each do |key|
        CounterHelper.send(:unregister, key)
      end
    end
  end

  class TestLogger
    attr_reader :last_args

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    def method_missing(*args)
      @last_args = args
      logger.send(*args)
    end
  end
end

TestHelper.configure_redis
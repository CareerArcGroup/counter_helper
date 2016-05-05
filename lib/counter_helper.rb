require 'redis_helper'

require 'counter_helper/version'
require 'counter_helper/config'

module CounterHelper
  class << self
    include Redis::RedisHelper

    COUNTER_LIST_KEY = "counter_helper:counter_list"
    COUNTER_LIST_LOCK_KEY = "counter_helper:counter_list_lock"
    COUNTER_SLICE_PREFIX = "counter_helper:counters"

    # =================================================================
    # counter operations
    # =================================================================

    def increment(key, by=1, &block)
      register(key) unless registered?(key)
      slice = slice_counter(key)
      value = slice.increment(by)

      block_given? ? rewindable_block(:decrement, key, by, value, &block) : value
    end

    def decrement(key, by=1, &block)
      register(key) unless registered?(key)
      slice = slice_counter(key)
      value = slice.decrement(by)

      block_given? ? rewindable_block(:increment, key, by, value, &block) : value
    end

    def increment_with_logging(key, message, options = {}, &block)
      increment(key, &block)
      log(key, message, options)
    end

    def decrement_with_logging(key, message, options = {}, &block)
      decrement(key, &block)
      log(key, message, options)
    end

    def value(key)
      slice_counter(key).value
    end

    def has_counter?(key)
      registered?(key)
    end

    def read_counters(mark_read=false, &block)
      end_slice = slice_index - 1
      counter_list_lock.lock do
        each_counter do |key, last_read_slice|
          each_counter_value(key, last_read_slice.to_i + 1, end_slice, mark_read, &block)
        end.flatten.compact
      end
    end

    def read_counters!(&block)
      read_counters(true, &block)
    end

    def read_counter(key, mark_read=false, &block)
      each_counter_value(key, nil, slice_index - 1, mark_read, &block)
    end

    def read_counter!(key, &block)
      read_counter(key, true, &block)
    end

    def configure(options={})
      Config.from_options(options)
    end

    protected

    def counter_list
      @counter_list ||= Redis::SortedSet.new(COUNTER_LIST_KEY, redis)
    end

    def counter_list_lock
      @counter_list_lock ||= Redis::Lock.new(COUNTER_LIST_LOCK_KEY, redis, timeout: 0, expiration: 60)
    end

    # =================================================================
    # counter registration
    # =================================================================

    # adds the counter key to the counter list
    # with a score of 0...
    def register(key)
      counter_list.add(key, slice_index - 1)
    end

    # removes the counter key from the counter list
    def unregister(key)
      counter_list.delete!(key)
    end

    # checks to see if the counter is registered
    def registered?(key)
      counter_list.score(key) != nil
    end

    # =================================================================
    # counter slices
    # =================================================================

    # retrieves the slice index for the given time (really the
    # number of <granularity> periods since the Unix epoch)...
    def slice_index(time=Time.now)
      time.to_i / granularity
    end

    # returns the key name used to represent the given
    # slice (with optional offset) for the given counter...
    def slice_name(key, slice)
      "#{counter_slice_prefix}:#{key}:#{slice}"
    end

    # returns a redis counter representing the given
    # counter slice. if it doesn't exist, it will be created
    # with a value of 0 and given an expiration...
    def slice_counter(key, slice=slice_index)
      slice = Redis::Counter.new(slice_name(key, slice), redis)

      unless slice.exists?
        slice.reset
        slice.expire counter_expiration
      end

      slice
    end

    # =================================================================
    # counter enumerators
    # =================================================================

    # enumerate over counters with their last-viewed times...
    def each_counter(&block)
      counter_list.members(with_scores: true).map(&block)
    end

    # enumerates over counter values for the specific key
    def each_counter_value(key, start_slice, end_slice, mark_read=false, &block)
      last_slice = slice_index - 1
      last_read = counter_list.score(key).to_i
      start_slice ||= last_read + 1
      end_slice ||= last_slice

      # don't bother trying to read slices older than the counter
      # expiration date because they're not gonna be around! also,
      # don't bother trying to read slices past 1 slice ago, because
      # they are either incomplete (this slice) or non-existant
      start_slice = [start_slice, slice_index(Time.now - counter_expiration)].max
      end_slice = [end_slice, last_slice].min

      # if we're starting past the last slice, we've got no data...
      return if start_slice > last_slice

      # if we're marking last-read times, set the score to start_slice - 1...
      counter_list[key] = start_slice - 1 if mark_read

      (start_slice..end_slice).map do |slice|
        counter = slice_counter(key, slice)
        value = counter.value
        timestamp = Time.at(slice * granularity)

        item = {
          counter: key,
          value: value,
          timestamp: timestamp
        }

        result = yield(item) if block_given?
        result ||= item

        # increment the last-read value as we enumerate. if we ever
        # get out of sync (which we shouldn't), just set the score.
        # setting the score is slower than incrementing...
        if mark_read
          last = counter_list.increment(key)
          counter_list[key] = slice unless last == slice
        end

        result
      end
    end

    # =================================================================
    # logging
    # =================================================================

    def logger
      Config.logger
    end

    def log_formatter
      Config.log_formatter
    end

    def log(key, message_or_exception, options = {})
      is_exception = message_or_exception.is_a?(Exception)
      level = options[:level] || (is_exception ? :error : :info)

      value = if log_formatter
        log_formatter.call(key, message_or_exception, options)
      elsif is_exception
        message_or_exception.message
      else
        message_or_exception
      end

      logger.send(level, value)
    end

    # =================================================================
    # config
    # =================================================================

    def redis
      Config.redis
    end

    def counter_list_key
      @counter_list_key ||= key_with_prefix(COUNTER_LIST_KEY)
    end

    def counter_list_lock_key
      @counter_list_lock_key ||= key_with_prefix(COUNTER_LIST_LOCK_KEY)
    end

    def counter_slice_prefix
      @counter_slice_prefix ||= key_with_prefix(COUNTER_SLICE_PREFIX)
    end

    def counter_expiration
      @counter_expiration ||= Config.expiration
    end

    def granularity
      @granularity ||= Config.granularity
    end

    # =================================================================
    # misc
    # =================================================================

    # performs a "rewind" operation after an increment or decrement
    # operation (returning the counter to it's previous value) after the
    # execution of the given block. see the increment and decrement
    # methods for more information...
    def rewindable_block(rewind, key, by, value, &block)
      raise ArgumentError, "Missing block to rewindable_block" unless block_given?

      ret = nil

      begin
        ret = yield value
      rescue
        send(rewind, key, by)
        raise
      end

      send(rewind, key, by) if ret.nil?
      ret
    end

    def key_with_prefix(key)
      [Config.redis_prefix, key].join(":")
    end
  end
end
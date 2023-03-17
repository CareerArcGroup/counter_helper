require "test_helper"

class CounterHelperTest < Minitest::Test
  def setup
    Redis::RedisHelper.redis = Redis.new

    CounterHelper.configure(
      granularity: 60,     # 1 minute
      expiration: 5 * 60,  # 5 minutes
      logger: logger,
      log_formatter: ->(k, v, msg, opts) do
        ["[#{k} -> #{v}] #{msg}", opts.merge(counter_key: k)]
      end
    )

    # make sure all counters are marked as read...
    CounterHelper.read_counters!

    # wait until we're in the next slice if
    # we're too close for comfort...
    time_to_next_slice = Time.now.to_i % CounterHelper::Config.granularity

    if time_to_next_slice <= 5
      puts "Waiting #{time_to_next_slice} seconds for next slice..."
      sleep time_to_next_slice
    end
  end

  def teardown
    TestHelper.unregister_keys
  end

  def test_increment
    apple_key = TestHelper.create_key("apples")

    assert_equal 0, CounterHelper.value(apple_key)
    assert_equal 1, CounterHelper.increment(apple_key)
    assert_equal 1, CounterHelper.value(apple_key)
    assert_equal 5, CounterHelper.increment(apple_key, 4)
  end

  def test_decrement
    banana_key = TestHelper.create_key("bananas")

    assert_equal(0, CounterHelper.value(banana_key))
    assert_equal(-1, CounterHelper.decrement(banana_key))
    assert_equal(-1, CounterHelper.value(banana_key))
    assert_equal(-7, CounterHelper.decrement(banana_key, 6))

    CounterHelper.send(:unregister, banana_key)
  end

  def test_increment_with_logging
    coconut_key = TestHelper.create_key("coconut")

    assert_equal 0, CounterHelper.value(coconut_key)

    assert_equal 1, CounterHelper.increment_with_logging(coconut_key, "I just ate a coconut!")
    assert_logged(:info, "[#{coconut_key} -> 1] I just ate a coconut!", counter_key: coconut_key)

    assert_equal 2, CounterHelper.increment_with_logging(coconut_key, Exception.new("A coconut hit me on the head!"))
    assert_logged(:error, "[#{coconut_key} -> 2] A coconut hit me on the head!", counter_key: coconut_key)
  end

  def test_decrement_with_logging
    durian_key = TestHelper.create_key("durian")

    assert_equal 0, CounterHelper.value(durian_key)

    assert_equal(-1, CounterHelper.decrement_with_logging(durian_key, "What is that smell?"))
    assert_logged(:info, "[#{durian_key} -> -1] What is that smell?", counter_key: durian_key)

    assert_equal(-2, CounterHelper.decrement_with_logging(durian_key, Exception.new("Someone is eating a durian!")))
    assert_logged(:error, "[#{durian_key} -> -2] Someone is eating a durian!", counter_key: durian_key)
  end

  def test_read_counters
    monkey_key = TestHelper.create_key("monkey")

    # make sure all counters are marked as read...
    CounterHelper.read_counters!

    # set the granularity to be small for this test...
    CounterHelper.configure(granularity: 2)

    # boundaries will be on even-second times, so
    # let's try to start close to an odd-second time...
    delta = Time.now.to_f % 2
    wait_time = (delta < 1.0 ? 1 : 3) - delta
    sleep wait_time

    # now, lets increment counters over time...
    (1..5).each do |inc|
      CounterHelper.increment(monkey_key, inc)
      sleep 2 # wait for the middle of the next slice...
    end

    # now read back the counters...
    expected = 1

    CounterHelper.read_counters! do |counter|
      if counter[:key] == monkey_key
        assert_equal expected, counter[:value]
        expected += 1
      end
    end
  end

  private

  def logger
    @logger ||= TestHelper::TestLogger.new
  end

  def assert_logged(*args)
    assert_equal args, logger.last_args
  end
end

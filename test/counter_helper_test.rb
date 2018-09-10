require "test_helper"

class CounterHelperTest < Minitest::Test
  def setup
    CounterHelper.configure(
      granularity: 60,     # 1 minute
      expiration: 5 * 60,  # 5 minutes
      logger: logger
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

    assert_equal  0, CounterHelper.value(banana_key)
    assert_equal -1, CounterHelper.decrement(banana_key)
    assert_equal -1, CounterHelper.value(banana_key)
    assert_equal -7, CounterHelper.decrement(banana_key, 6)

    CounterHelper.send(:unregister, banana_key)
  end

  def test_increment_with_logging
    coconut_key = TestHelper.create_key("coconut")

    assert_equal 0, CounterHelper.value(coconut_key)

    assert_equal 1, CounterHelper.increment_with_logging(coconut_key, "I just ate a coconut!")
    assert_logged(:info, "I just ate a coconut!")

    assert_equal 2, CounterHelper.increment_with_logging(coconut_key, Exception.new("A coconut hit me on the head!"))
    assert_logged(:error, "A coconut hit me on the head!")
  end

  def test_increment_with_logging
    durian_key = TestHelper.create_key("durian")

    assert_equal 0, CounterHelper.value(durian_key)

    assert_equal -1, CounterHelper.decrement_with_logging(durian_key, "What is that smell?")
    assert_logged(:info, "What is that smell?")

    assert_equal -2, CounterHelper.decrement_with_logging(durian_key, Exception.new("Someone is eating a durian!"))
    assert_logged(:error, "Someone is eating a durian!")
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

  def assert_logged(level, payload)
    assert_equal [level, payload], logger.last_args
  end
end

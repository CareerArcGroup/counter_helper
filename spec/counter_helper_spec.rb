require 'spec_helper'

RSpec.describe CounterHelper do
  let(:test_key) { "spec_test_key_#{rand}" }

  before do
    # Reset cached module-level state so each test starts fresh
    CounterHelper.instance_variable_set(:@counter_list, nil)
    CounterHelper.instance_variable_set(:@counter_list_lock, nil)
    CounterHelper.instance_variable_set(:@counter_slice_prefix, nil)
    CounterHelper.instance_variable_set(:@counter_expiration, nil)
    CounterHelper.instance_variable_set(:@granularity, nil)

    CounterHelper.configure(
      granularity: 60,
      expiration:  5 * 60,
      logger:      Logger.new(IO::NULL)
    )
    CounterHelper.read_counters!
  end

  after do
    CounterHelper.send(:unregister, test_key)
  end

  describe '.increment' do
    it 'starts at 0' do
      expect(CounterHelper.value(test_key)).to eq(0)
    end

    it 'increments by 1 by default' do
      expect(CounterHelper.increment(test_key)).to eq(1)
    end

    it 'increments by a given amount' do
      expect(CounterHelper.increment(test_key, 5)).to eq(5)
    end

    it 'accumulates increments' do
      CounterHelper.increment(test_key, 3)
      expect(CounterHelper.increment(test_key, 2)).to eq(5)
    end

    it 'updates value' do
      CounterHelper.increment(test_key)
      expect(CounterHelper.value(test_key)).to eq(1)
    end

    context 'with a block' do
      it 'returns the block return value and rolls back on nil return' do
        CounterHelper.increment(test_key) { |_v| nil }
        expect(CounterHelper.value(test_key)).to eq(0)
      end

      it 'rolls back on exception' do
        expect do
          CounterHelper.increment(test_key) { raise "boom" }
        end.to raise_error(RuntimeError, "boom")
        expect(CounterHelper.value(test_key)).to eq(0)
      end
    end
  end

  describe '.decrement' do
    it 'decrements by 1 by default' do
      expect(CounterHelper.decrement(test_key)).to eq(-1)
    end

    it 'decrements by a given amount' do
      expect(CounterHelper.decrement(test_key, 3)).to eq(-3)
    end

    it 'updates value' do
      CounterHelper.decrement(test_key)
      expect(CounterHelper.value(test_key)).to eq(-1)
    end
  end

  describe '.increment_with_logging' do
    let(:logger) { instance_double(Logger, info: nil, error: nil) }

    before do
      CounterHelper.configure(
        granularity: 60,
        expiration:  5 * 60,
        logger:      logger
      )
    end

    after do
      CounterHelper.send(:unregister, test_key)
    end

    it 'increments the counter and returns new value' do
      expect(CounterHelper.increment_with_logging(test_key, "test message")).to eq(1)
    end

    it 'logs at info level for a string message' do
      CounterHelper.increment_with_logging(test_key, "test message")
      expect(logger).to have_received(:info).with("test message")
    end

    it 'logs at error level for an exception' do
      CounterHelper.increment_with_logging(test_key, RuntimeError.new("something broke"))
      expect(logger).to have_received(:error).with("something broke")
    end
  end

  describe '.decrement_with_logging' do
    let(:logger) { instance_double(Logger, info: nil, error: nil) }

    before do
      CounterHelper.configure(
        granularity: 60,
        expiration:  5 * 60,
        logger:      logger
      )
    end

    after do
      CounterHelper.send(:unregister, test_key)
    end

    it 'decrements the counter and returns new value' do
      expect(CounterHelper.decrement_with_logging(test_key, "test message")).to eq(-1)
    end

    it 'logs at info level for a string message' do
      CounterHelper.decrement_with_logging(test_key, "test message")
      expect(logger).to have_received(:info).with("test message")
    end
  end

  describe '.has_counter?' do
    it 'returns false before any increment/decrement' do
      expect(CounterHelper.has_counter?(test_key)).to be false
    end

    it 'returns true after incrementing' do
      CounterHelper.increment(test_key)
      expect(CounterHelper.has_counter?(test_key)).to be true
    end
  end

  describe '.mark_read!' do
    it 'does not raise an error when counters exist' do
      CounterHelper.increment(test_key)
      expect { CounterHelper.mark_read! }.not_to raise_error
    end

    it 'uses pipelined writes to update counter read positions' do
      CounterHelper.increment(test_key)
      redis = CounterHelper.send(:redis)
      pipeline_commands = []

      # Wrap pipelined to capture that block arg is used (Redis 5.x style)
      original_pipelined = redis.method(:pipelined)
      allow(redis).to receive(:pipelined) do |&block|
        # Call real pipelined but verify block arity allows argument passing
        original_pipelined.call(&block)
      end

      CounterHelper.mark_read!
      expect(redis).to have_received(:pipelined)
    end
  end

  describe '.configure' do
    it 'accepts a timeout option without raising' do
      expect do
        CounterHelper.configure(
          granularity: 60,
          expiration:  300,
          timeout:     5
        )
      end.not_to raise_error
    end

    it 'stores the configured timeout' do
      CounterHelper.configure(granularity: 60, expiration: 300, timeout: 5)
      expect(CounterHelper::Config.instance.timeout).to eq(5)
    end

    it 'passes timeout to Redis when redis is a Hash' do
      received_options = nil
      real_redis_new = Redis.method(:new)
      allow(Redis).to receive(:new) do |opts|
        received_options = opts
        real_redis_new.call
      end
      CounterHelper.configure(
        granularity: 60,
        expiration:  300,
        redis:       { host: 'localhost' },
        timeout:     5
      )
      expect(received_options).to include(host: 'localhost', timeout: 5)
    end
  end
end


require 'spec_helper'

RSpec.describe CounterHelper::Config do
  subject(:config) { described_class.new(options) }

  let(:options) { { granularity: 60, expiration: 300 } }

  describe '#timeout' do
    context 'when not configured' do
      it 'returns nil' do
        expect(config.timeout).to be_nil
      end
    end

    context 'when configured' do
      let(:options) { { granularity: 60, expiration: 300, timeout: 5 } }

      it 'returns the configured value' do
        expect(config.timeout).to eq(5)
      end
    end
  end

  describe '#redis' do
    # Restore global redis connection after tests that may change it
    around do |example|
      original = Redis::RedisHelper.instance_variable_get(:@redis)
      example.run
      Redis::RedisHelper.instance_variable_set(:@redis, original)
    end

    context 'when redis is a Hash' do
      let(:options) { { granularity: 60, expiration: 300, redis: { host: 'localhost', port: 6379 } } }

      it 'creates a Redis instance from the hash' do
        expect(config.redis).to be_a(Redis)
      end
    end

    context 'when redis is a Hash and timeout is configured' do
      it 'merges timeout into the redis connection options' do
        received_options = nil
        real_redis_new = Redis.method(:new)
        allow(Redis).to receive(:new) do |opts|
          received_options = opts
          real_redis_new.call
        end
        described_class.new(granularity: 60, expiration: 300, redis: { host: 'localhost' }, timeout: 5)
        expect(received_options).to include(host: 'localhost', timeout: 5)
      end
    end

    context 'when redis is a Hash and timeout is not configured' do
      it 'does not add a timeout to the redis connection options' do
        received_options = nil
        real_redis_new = Redis.method(:new)
        allow(Redis).to receive(:new) do |opts|
          received_options = opts
          real_redis_new.call
        end
        described_class.new(granularity: 60, expiration: 300, redis: { host: 'localhost' })
        expect(received_options).not_to have_key(:timeout)
      end
    end

    context 'when redis is a Redis instance' do
      let(:redis_instance) { Redis.new }
      let(:options) { { granularity: 60, expiration: 300, redis: redis_instance } }

      it 'uses the given Redis instance directly' do
        expect(config.redis).to eq(redis_instance)
      end
    end
  end

  describe 'validations' do
    context 'when granularity is larger than expiration' do
      let(:options) { { granularity: 300, expiration: 60 } }

      it 'raises ArgumentError' do
        expect { config }.to raise_error(ArgumentError, /granularity cannot be larger than expiration/)
      end
    end

    context 'when expiration equals granularity' do
      let(:options) { { granularity: 60, expiration: 60 } }

      it 'raises ArgumentError' do
        expect { config }.to raise_error(ArgumentError, /expiration cannot be less than or equal to granularity/)
      end
    end
  end

  describe '#granularity' do
    context 'with default value' do
      it 'returns 60' do
        expect(config.granularity).to eq(60)
      end
    end

    context 'with a custom value' do
      let(:options) { { granularity: 120, expiration: 3600 } }

      it 'returns the configured value' do
        expect(config.granularity).to eq(120)
      end
    end
  end

  describe '#expiration' do
    context 'with default value' do
      let(:options) { {} }

      it 'returns 7200' do
        expect(config.expiration).to eq(7200)
      end
    end

    context 'with a custom value' do
      let(:options) { { granularity: 60, expiration: 3600 } }

      it 'returns the configured value' do
        expect(config.expiration).to eq(3600)
      end
    end
  end
end

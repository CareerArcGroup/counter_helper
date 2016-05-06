# CounterHelper

Abacus got you angry? Calculator got you cursing? Don't fear, **CounterHelper** is here!

If you're anything like me, you've often tried to count a bunch of things only to discover that counting lots of things at once can be really hard! You're doing just fine and then some dude comes along and says a bunch of random numbers and you lose track! Next thing you know, you're in the middle of the desert with a massive headache, a shovel in your hand, and no idea how you got there. We've *all* been there before, friend!

With CounterHelper, you'll never again have to worry about:

* Unexpexted Lotto number announcements
* Overly-loud recountings of sports statistics
* Group conversations on the right number of teeth to have
* Rain Man

You can finally relax, knowing that CounterHelper has your back!

## Summary

CounterHelper is a library designed to help you count things over time.

Let's say that you're worried that you're in some kind of Truman Show- or Matrix-like simulation due to the odd pattern of events you've been witnessing lately. You want to keep a table of event counts like:

| Event               | 8AM  | 9AM  | 10AM | 11AM | 12PM | 1PM  | 2PM  | 3PM  | 4PM  | 5PM  |
| :------------------ | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| Red car spotted     | 1    | 0    | 1    | 0    | 1    | 0    | 1    | 0    | 1    | 0    |
| Dog catches frisbee | 5    | 0    | 0    | 5    | 0    | 0    | 5    | 0    | 0    | 5    |
| Runner ties shoes   | 1    | 3    | 0    | 1    | 3    | 0    | 1    | 3    | 0    | 1    |
| Computer crashes    | 9    | 9    | 9    | 9    | 0    | 9    | 9    | 9    | 9    | 0    |

Looks normal to me, Mr. Anderson. But you don't need to keep track of this stuff in your notebook! Instead, you can use CounterHelper to keep track of it all for you!

With CounterHelper, you set:

* the `granularity` - How big are the time-slices? In our example, time is divided into 1 hour blocks.
* the `expiration` - How long do we want to keep the data? Here we're keeping 10 hours worth.

Then you can count and count, and at any point, CounterHelper can give you the data for the last 10 hours just like in the table above. Sound good? Read on, friend!

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'counter_helper'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install counter_helper

## Configuration

Here's how you configure CounterHelper, along with a table of configuration options for reference. If you're using Rails, you can put this configuration in an initializer (i.e. config/initializers/counter_helper.rb).

```ruby
CounterHelper.configure(
  granularity: 60,      # 1 minute
  expiration:  5 * 60,  # 5 minutes
)
```

Here's a full listing of all of the things you can configure:

| Item            | Default              | Description                                              |
| --------------- | -------------------- | -------------------------------------------------------- |
| `granularity`   | 60 (1 minute)        | Time-slice duration in seconds.                          |
| `expiration`    | 7200 (2 hours)       | Time in seconds to keep counter data                     |
| `redis`         | `Redis.current`      | Redis connection to use. See below for example           |
| `redis_prefix`  | `nil`                | A string prefix to use with all CounterHelper Redis keys |
| `logger`        | `Logger.new(STDOUT)` | The logger CounterHelper should use for logging          |
| `log_formatter` | `nil`                | See [Logging](#logging)                                  |

By default, CounterHelper will try to use `Redis.current` as a Redis client. If you're already using Redis and have configured it elsewhere, this default may be fine for you. If not, or if you want to put CounterHelper data into its own special place, here are a couple options for how you can configure it:

```ruby
# Option 1: By passing a configuration Hash.
# This hash will be passed directly to Redis.new (see the redis-rb gem for details)
CounterHelper.configure(
  redis: {
    host: "10.0.0.123",
    port: 6380,
    db:   10
  }
)

# Option 2: By passing a Redis object
ConfigHelper.configure(
  redis: Redis.new(host: "10.0.0.123", port: 6380, db: 10)
)
```

## Usage

CounterHelper lets you count all kinds of things at once. Just pick a name for the thing you're counting, and call `increment` to up the count:

```ruby
CounterHelper.increment("Failed cold fusion experiments")  # more ice around the tokamak?
```

Of course, you can also call `decrement` to lower the count:

```ruby
CounterHelper.decrement("Living laboratory assistants")    # no one liked jared anyway.
```

These methods will atomically increment/decrement the given count by 1, but sometimes it's easier to count by twos (or sevens). You can also count things with decimal places:

```ruby
CounterHelper.increment("Clip-on Spock ears", 2)  # thanks, mom!
CounterHelper.decrement("Lunch money", 5.75)      # thanks, biff.
```

### Time Slicing

I know! I'm just as excited about time slicing as you are! It turns out you just need a really sharp knife and super steady hands (no more Jolt Cola for you, sonny). But we're talking about a different kind of time slicing here.

Out of the box, CounterHelper is configured to slice up time into 1 minute increments. As you count, CounterHelper keeps track of how your counts change from minute to minute.  This way, you can see how your counts change over time. To illustrate this point we'll introduce another method called `value` which tells you the value of a given count for the current time slice (i.e. minute):

```ruby
# at 10:00PM
CounterHelper.value("Pop-Tarts eaten")      # => 0
CounterHelper.increment("Pop-Tarts eaten")  # => 1

# at 10:01PM
CounterHelper.value("Pop-Tarts eaten")      # => 0
```

The second call to `value` returns 0 because although there was 1 tasty Pop-Tart eaten in the minute of 10:00PM, there were 0 Pop-Tarts eaten in the minute of 10:01PM (no one's perfect). Since counts are stored slice-by-slice, when it comes time to do something with all your hard-earned counts, you'll be able to slice and dice the numbers however you want. And the size of each time slice is configurable (see the Configuration section for details).

### Retrieval

Now that you've done all the hard work, it's time to see some results! CounterHelper lets you see all of the awesome time sliced goodness through the use of a method called (drumroll) `read_counters`:

```ruby
# call it as a pure method...
CounterHelper.read_counters

# => [
#  {:counter=>"Pop-Tarts eaten", :value=>0, :timestamp=>2016-02-14 22:00:00 -0700},
#  {:counter=>"Pop-Tarts eaten", :value=>1, :timestamp=>2016-02-14 22:01:00 -0700},
#  {:counter=>"Pop-Tarts eaten", :value=>0, :timestamp=>2016-02-14 22:02:00 -0700}
# ]

# or call it as an iterator...
CounterHelper.read_counters do |item|
  puts "Count '#{item[:counter]}' had value #{item[:value]} on #{item[:timestamp].to_s(:long)}"
end

# output:
# Count 'Pop-Tarts eaten' had value 0 on February 14, 2016 22:00
# Count 'Pop-Tarts eaten' had value 1 on February 14, 2016 22:01
# Count 'Pop-Tarts eaten' had value 0 on February 14, 2016 22:02
```

The `read_counters` method will yield every value for every counter during each time-slice. Yep, that's all that was happening then. What? Pop-Tarts can be very fulfilling! Well that's not entirely true. I mean, the part about Pop-Tarts is true. But the part about *every counter and each time-slice* is not exactly accurate. There have been a lot of time-slices after all!

CounterHelper will only keep track of counts for a configurable time period after which the counter data will automagically expire. If you only need to keep track of 2 weeks worth of count data, then the `read_counters` method will give you *at most* 2 weeks worth of data for each counter you've used.

And for those of us that don't need to be reminded of data we've already seen, there's the lovely `read_counters!` method which marks the data as it's yielded so that you only see it once (i.e. you won't see it in future `read_counters` or `read_counters!` calls).

You can also read just one counter at a time if you'd like:

```ruby
CounterHelper.read_counter("My Counter")
```

Of course, you can use the iterator calling style for this method too. And there's a `read_counter!` method as well if you only want to see the data once.

## Logging

Often times when you `increment` or `decrement` a counter, you'll want to log some relevant information at the same time. To that end, we present the *with_logging* method flavors:

```ruby
# decrement the "My Counter" counter, and log "My Log Message" to the logger...
CounterHelper.decrement_with_logging("My Counter", "My Log Message")

# increment the "Exceptions caught" counter and log `ex.message` on Exception `ex`...
CounterHelper.increment_with_logging("Exceptions caught", ex)
```

You may want to get a little more fancy with your logging. As noted in the [Configuration](#configuration) section, you can have CounterHelper use a custom logger. You can also provide a `log_formatter` Proc to shape the data that is logged. Here's an example that uses a Log4r logger:

```ruby
# configuration
CounterHelper.configure(
  logger: Log4r::Logger["CounterHelper"]
  log_formatter: ->(counter, value, message_or_exception, options) do
    exception = message_or_exception if message_or_exception.is_a?(Exception)
    exception ||= options.delete(:exception)

    message = exception.message if exception

    options.merge!(short_message: message, counter_key: key, counter_value: value)
    options.merge!(exception: exception.message, backtrace: exception.backtrace.join("\n")) if exception

    options
  end
)

# and now we count something...
CounterHelper.increment_with_logging("Unhandled exceptions", ex, controller: "Home", action: "Index")

# this would return the new value of the counter (let's say it's 5)
# and CounterHelper would make a logging call equivalent to:
logger = Log4r::Logger["CounterHelper"]
logger.error(
  short_message: "Undefined method `length` for nil",
  counter_key: "Unhandled exceptions",
  counter_value: 5,
  exception: "Undefined method `length` for nil",
  backtrace: "... backtrace ..."
)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/CareerArcGroup/counter_helper. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'counter_helper/version'

Gem::Specification.new do |spec|
  spec.name          = "counter_helper"
  spec.version       = CounterHelper::VERSION
  spec.authors       = ["Stephen Roos"]
  spec.email         = ["sroos@careerarc.com"]

  spec.homepage      = "https://github.com/CareerArcGroup/counter_helper"
  spec.license       = "MIT"
  spec.summary       = %q{A simple wrapper around Redis counters to help you count things over time}
  spec.description   = %q{The counter_helper gem is a simple wrapper around the Redis Counter API that allows you to track the things you count over time.}

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "redis", "~> 4.0"

  spec.add_development_dependency "bundler", "~> 2"
  spec.add_development_dependency "rake", "~> 13"
  spec.add_development_dependency "minitest", "~> 5"
end

# Faraday Hedge

[![Gem Version](https://img.shields.io/gem/v/faraday-hedge.svg)](https://rubygems.org/gems/faraday-hedge)
[![Gem Downloads](https://img.shields.io/gem/dt/faraday-hedge.svg)](https://rubygems.org/gems/faraday-hedge)
[![Ruby](https://img.shields.io/badge/ruby-3.0%2B-cc0000.svg)](https://www.ruby-lang.org)
[![CI](https://github.com/Elysium-Arc/faraday-hedge/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Elysium-Arc/faraday-hedge/actions/workflows/ci.yml)
[![GitHub Release](https://img.shields.io/github/v/release/Elysium-Arc/faraday-hedge.svg)](https://github.com/Elysium-Arc/faraday-hedge/releases)
[![Rails](https://img.shields.io/badge/rails-6.x%20%7C%207.x%20%7C%208.x-cc0000.svg)](https://rubyonrails.org)
[![Elysium Arc](https://img.shields.io/badge/Elysium%20Arc-Reliability%20Toolkit-0b3d91.svg)](https://github.com/Elysium-Arc)

Hedged requests middleware for Faraday to reduce tail latency on idempotent methods.

## About
Faraday Hedge issues a backup request after a small delay and returns the first response. This reduces tail latency when occasional slow requests occur, while keeping overall load bounded.

The middleware defaults to idempotent methods and can be configured to hedge only specific HTTP verbs.

## Use Cases
- Reduce p99 latency for flaky upstream APIs
- Protect against tail latency spikes on critical read paths
- Improve UX for latency-sensitive services

## Compatibility
- Ruby 3.0+
- Faraday 1.0+

## Elysium Arc Reliability Toolkit
Also check out these related gems:
- Cache Coalescer: https://github.com/Elysium-Arc/cache-coalescer
- Cache SWR: https://github.com/Elysium-Arc/cache-swr
- Rack Idempotency Kit: https://github.com/Elysium-Arc/rack-idempotency-kit
- Env Contract: https://github.com/Elysium-Arc/env-contract

## Installation
```ruby
# Gemfile

gem "faraday-hedge"
```

## Usage
```ruby
conn = Faraday.new do |f|
  f.request :hedge, delay: 0.05
  f.adapter :net_http
end
```

## Options
- `delay` (Float) seconds before firing a backup request
- `max_hedges` (Integer) number of backup requests to allow
- `methods` (Array) methods eligible for hedging
- `idempotent_only` (Boolean) restrict hedging to idempotent methods

## Notes
- Hedging uses background threads.
- Use conservative delays to avoid excessive duplicate work.

## Release
```bash
bundle exec rake release
```

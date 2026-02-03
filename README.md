# Faraday Hedge

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

# Faraday Hedge

Hedged requests for Faraday to reduce tail latency on idempotent methods.

## Install
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
- `delay`: seconds before firing a backup request
- `max_hedges`: number of backups (default 1)
- `methods`: methods eligible for hedging (default GET/HEAD)

## Release
```bash
bundle exec rake release
```

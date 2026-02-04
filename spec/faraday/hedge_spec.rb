# frozen_string_literal: true

require "faraday"
require "faraday/adapter/test"

RSpec.describe Faraday::Hedge do
  let(:app) { ->(_env) { [200, {}, "ok"] } }

  it "validates non-negative delays" do
    expect { described_class.new(app, delay: -0.1) }.to raise_error(ArgumentError)
  end

  it "validates non-negative max_hedges" do
    expect { described_class.new(app, max_hedges: -1) }.to raise_error(ArgumentError)
  end

  it "returns the fastest response" do
    counter = 0
    mutex = Mutex.new
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/") do
        call = mutex.synchronize { counter += 1 }
        result = call == 1 ? "primary" : "hedge"
        sleep 0.2 if call == 1
        [200, {}, result]
      end
    end

    conn = Faraday.new do |f|
      f.request :hedge, delay: 0.05
      f.adapter :test, stubs
    end

    response = conn.get("/")
    expect(response.body).to eq("hedge")
  end

  it "builds delay schedules from scalar delays" do
    middleware = described_class.new(app, delay: 0.05, max_hedges: 2)
    expect(middleware.send(:hedge_delays)).to eq([0.05, 0.1])
  end

  it "builds delay schedules from arrays" do
    middleware = described_class.new(app, delay: [0.01, 0.02], max_hedges: 2)
    expect(middleware.send(:hedge_delays)).to eq([0.01, 0.02])
  end

  it "returns no delays when max_hedges is zero" do
    middleware = described_class.new(app, max_hedges: 0)
    expect(middleware.send(:hedge_delays)).to eq([])
  end

  it "skips hedging when primary completes before delay" do
    counter = 0
    mutex = Mutex.new

    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/") do
        mutex.synchronize { counter += 1 }
        [200, {}, "primary"]
      end
    end

    conn = Faraday.new do |f|
      f.request :hedge, delay: 0.3
      f.adapter :test, stubs
    end

    response = conn.get("/")
    expect(response.body).to eq("primary")
    expect(counter).to eq(1)
  end

  it "does not hedge non-idempotent methods when restricted" do
    counter = 0
    mutex = Mutex.new

    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/") do
        mutex.synchronize { counter += 1 }
        [200, {}, "ok"]
      end
    end

    conn = Faraday.new do |f|
      f.request :hedge, delay: 0.05, methods: [:post], idempotent_only: true
      f.adapter :test, stubs
    end

    conn.post("/")
    expect(counter).to eq(1)
  end

  it "does not hedge methods outside the allowlist" do
    counter = 0
    mutex = Mutex.new

    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/") do
        mutex.synchronize { counter += 1 }
        [200, {}, "ok"]
      end
    end

    conn = Faraday.new do |f|
      f.request :hedge, delay: 0.01, methods: [:get]
      f.adapter :test, stubs
    end

    conn.post("/")
    expect(counter).to eq(1)
  end

  it "hedges non-idempotent methods when idempotent_only is false" do
    counter = 0
    mutex = Mutex.new

    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/") do
        call = mutex.synchronize { counter += 1 }
        sleep 0.05 if call == 1
        [200, {}, "ok"]
      end
    end

    conn = Faraday.new do |f|
      f.request :hedge, delay: 0.01, max_hedges: 1, methods: [:post], idempotent_only: false
      f.adapter :test, stubs
    end

    conn.post("/")
    expect(counter).to eq(2)
  end

  it "does not hedge when max_hedges is zero" do
    counter = 0
    mutex = Mutex.new

    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/") do
        mutex.synchronize { counter += 1 }
        [200, {}, "ok"]
      end
    end

    conn = Faraday.new do |f|
      f.request :hedge, delay: 0.01, max_hedges: 0
      f.adapter :test, stubs
    end

    conn.get("/")
    expect(counter).to eq(1)
  end

  it "falls back to a hedge response when the primary errors" do
    counter = 0
    mutex = Mutex.new

    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/") do
        call = mutex.synchronize { counter += 1 }
        raise Faraday::ConnectionFailed, "boom" if call == 1
        [200, {}, "ok"]
      end
    end

    conn = Faraday.new do |f|
      f.request :hedge, delay: 0.01
      f.adapter :test, stubs
    end

    response = conn.get("/")
    expect(response.body).to eq("ok")
  end

  it "raises when all hedged requests fail" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/") { raise Faraday::ConnectionFailed, "boom" }
    end

    conn = Faraday.new do |f|
      f.request :hedge, delay: 0.01
      f.adapter :test, stubs
    end

    expect { conn.get("/") }.to raise_error(Faraday::ConnectionFailed)
  end
end

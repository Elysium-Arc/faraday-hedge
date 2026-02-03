# frozen_string_literal: true

require "faraday"
require "faraday/adapter/test"

RSpec.describe Faraday::Hedge do
  it "returns the fastest response" do
    counter = 0
    mutex = Mutex.new

    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/") do
        call = mutex.synchronize { counter += 1 }
        sleep 0.2 if call == 1
        [200, {}, call == 1 ? "primary" : "hedge"]
      end
    end

    conn = Faraday.new do |f|
      f.request :hedge, delay: 0.05
      f.adapter :test, stubs
    end

    response = conn.get("/")
    expect(response.body).to eq("hedge")
  end

  it "does not hedge non-idempotent methods" do
    counter = 0
    mutex = Mutex.new

    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/") do
        mutex.synchronize { counter += 1 }
        [200, {}, "ok"]
      end
    end

    conn = Faraday.new do |f|
      f.request :hedge, delay: 0.05
      f.adapter :test, stubs
    end

    conn.post("/")
    expect(counter).to eq(1)
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
end

# frozen_string_literal: true

require "faraday"
require "faraday/hedge/version"

module Faraday
  class Hedge
    DEFAULT_DELAY = 0.1
    DEFAULT_MAX_HEDGES = 1

    def initialize(app, options = {})
      @app = app
      @delay = options.fetch(:delay, DEFAULT_DELAY)
      @max_hedges = options.fetch(:max_hedges, DEFAULT_MAX_HEDGES)
      @methods = Array(options.fetch(:methods, %i[get head])).map(&:to_sym)
      @idempotent_only = options.fetch(:idempotent_only, true)
    end

    def call(env)
      return @app.call(env) unless hedgeable?(env)

      responses = Queue.new
      primary_thread = Thread.new { responses << @app.call(env.dup) }

      hedge_thread = Thread.new do
        sleep @delay
        # :nocov:
        return if primary_thread.join(0)
        # :nocov:
        responses << @app.call(env.dup)
      end

      response = responses.pop
      [primary_thread, hedge_thread].each { |t| t.kill if t.alive? }
      response
    end

    private

    def hedgeable?(env)
      return false if @idempotent_only && !@methods.include?(env.method)
      @max_hedges > 0
    end
  end

  Request.register_middleware(hedge: Faraday::Hedge)
end

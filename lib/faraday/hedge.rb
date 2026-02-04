# frozen_string_literal: true

require "faraday"
require "faraday/hedge/version"

module Faraday
  class Hedge
    DEFAULT_DELAY = 0.1
    DEFAULT_MAX_HEDGES = 1
    IDEMPOTENT_METHODS = %i[get head put delete options trace].freeze

    def initialize(app, options = {})
      @app = app
      @delay = options.fetch(:delay, DEFAULT_DELAY)
      @max_hedges = options.fetch(:max_hedges, DEFAULT_MAX_HEDGES)
      @methods = Array(options.fetch(:methods, %i[get head])).map(&:to_sym)
      @idempotent_only = options.fetch(:idempotent_only, true)
      validate_options!
    end

    def call(env)
      return @app.call(env) unless hedgeable?(env)

      responses = Queue.new
      threads = []
      spawn_request = lambda do |delay|
        Thread.new do
          sleep delay if delay.positive?

          begin
            responses << [:ok, @app.call(env.dup)]
          rescue StandardError => e
            responses << [:error, e]
          end
        end
      end

      threads << spawn_request.call(0)
      hedge_delays.each { |delay| threads << spawn_request.call(delay) }

      errors = []
      response = nil

      threads.size.times do
        status, result = responses.pop
        if status == :ok
          response = result
          break
        else
          errors << result
        end
      end

      threads.each { |t| t.kill if t.alive? }

      return response if response
      raise errors.fetch(0)
    end

    private

    def hedgeable?(env)
      method = env.method.to_s.downcase.to_sym
      return false unless @methods.include?(method)
      return false if @idempotent_only && !IDEMPOTENT_METHODS.include?(method)
      @max_hedges.to_i > 0
    end

    def hedge_delays
      return [] if @max_hedges.to_i <= 0
      if @delay.is_a?(Array)
        @delay.first(@max_hedges).map(&:to_f)
      else
        delay = @delay.to_f
        (1..@max_hedges).map { |i| delay * i }
      end
    end

    def validate_options!
      raise ArgumentError, "max_hedges must be >= 0" if @max_hedges.to_i < 0

      delays = @delay.is_a?(Array) ? @delay : [@delay]
      if delays.any? { |delay| delay.to_f.negative? }
        raise ArgumentError, "delay must be >= 0"
      end
    end
  end

  Request.register_middleware(hedge: Faraday::Hedge)
end

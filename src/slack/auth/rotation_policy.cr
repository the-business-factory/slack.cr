require "./clock"
require "./errors"

module Slack::Auth
  # Calls never wait or retry HTTP. These bounds limit early rotation and ownership.
  struct RotationPolicy
    getter refresh_margin : Time::Span
    getter lease_duration : Time::Span

    def initialize(@refresh_margin : Time::Span = 5.minutes, @lease_duration : Time::Span = 2.minutes)
      unless Time::Span.zero <= @refresh_margin <= 1.hour &&
             Time::Span.zero < @lease_duration <= 10.minutes
        raise ContractError.new(:invalid_configuration)
      end
    end

    def due?(expires_at : Time, now : Time) : Bool
      expires_at - now <= @refresh_margin
    end
  end
end

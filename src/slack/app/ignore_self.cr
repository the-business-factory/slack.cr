# Stops the listener chain for a message that this app posted, so a listener
# that posts into a channel it reads does not answer itself. Bolt calls this
# `ignoreSelf`. `Slack::App.new` adds it unless `ignore_self: false`.
#
# A `message` event without a subtype is the app's own when its `app_id`
# equals the envelope's `api_app_id`, or its `user` equals the user ID of a
# bot authorization in the envelope. Other events pass, including message
# subtypes such as `thread_broadcast` and `member_joined_channel` for the bot
# user, and so do messages of other apps and incoming webhooks.
module Slack::App::IgnoreSelf
  def self.middleware : Middleware
    ->(ctx : Context, call_next : Proc(Nil)) do
      call_next.call unless self_message?(ctx)
    end
  end

  def self.self_message?(ctx : Context) : Bool
    return false unless ctx.is_a?(EventContext)
    envelope = ctx.envelope
    message = envelope.event
    return false unless message.is_a?(Slack::Events::Message)
    return true if message.app_id == envelope.api_app_id
    envelope.authorizations.any? { |authorization| authorization.bot? && authorization.user_id == message.user }
  end
end

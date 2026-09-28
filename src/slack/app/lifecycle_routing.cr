class Slack::App
  alias OwnerSelector = Proc(Slack::VerifiedEvent, Slack::Auth::InstallationKey?)

  @lifecycle : Slack::Auth::CredentialLifecycle? = nil
  @lifecycle_owner : OwnerSelector? = nil
  @lifecycle_history = LifecycleHistory.new

  # Sends `tokens_revoked` and `app_uninstalled` events to *lifecycle*, which
  # removes the revoked grants or the installation from its store. The event
  # must name its owner in `authorizations`; otherwise use the overload that
  # selects the owner.
  #
  # The app applies these events before authorization, because the
  # installation can already be gone, and acknowledges them with an empty 200.
  # They do not reach listeners. If the cleanup raises, the outcome is failed
  # (HTTP 500), so Slack retries the event.
  #
  # The app keeps the preparation of each event in memory and applies it again
  # to a repeated delivery, so a retry after a reinstall does not remove the new
  # installation. A retry that this process has no preparation for, for example
  # after a restart or on another process, is acknowledged without cleanup and
  # logged as a warning.
  def lifecycle(lifecycle : Slack::Auth::CredentialLifecycle) : Nil
    @lifecycle = lifecycle
    @lifecycle_owner = nil
  end

  # Like `#lifecycle`, but the block selects the owner of each event, for
  # events without `authorizations` such as Slack's `tokens_revoked` example.
  # Return the exact installation key from your own routing; the lifecycle
  # still checks it against the event's app and workspace.
  #
  # ```
  # app.lifecycle(lifecycle) do |envelope|
  #   Slack::Auth::InstallationKey.new(app_id, :workspace, team_id: envelope.team_id)
  # end
  # ```
  def lifecycle(lifecycle : Slack::Auth::CredentialLifecycle, &owner : Slack::VerifiedEvent -> Slack::Auth::InstallationKey?) : Nil
    @lifecycle = lifecycle
    @lifecycle_owner = owner
  end

  # Returns nil when no lifecycle is set or *payload* is not a lifecycle event.
  private def apply_lifecycle(payload : Payload, delivery : Slack::Events::Delivery?) : Outcome?
    lifecycle = @lifecycle || return
    return unless payload.is_a?(Slack::VerifiedEvent)
    return unless payload.event.is_a?(Slack::Events::TokensRevoked | Slack::Events::AppUninstalled)
    prepared = @lifecycle_history.fetch(payload.event_id) do
      lifecycle.prepare_trusted(payload, @lifecycle_owner.try(&.call(payload))) unless delivery.try(&.retry?)
    end
    unless prepared
      @log.warn { "Skipped credential cleanup for #{describe(payload)}: a retry without a retained preparation" }
      return Outcome.acknowledged
    end
    outcome = lifecycle.apply(prepared)
    @log.info { "Credential cleanup for #{describe(payload)}: #{outcome}" }
    Outcome.acknowledged
  rescue error
    @log.error { "Credential cleanup for #{describe(payload)} raised #{error.class}" }
    Outcome.failed
  end
end

require "../commands/command"
require "../event"
require "../events/**"
require "../interaction"
require "../interactions/**"
require "./installation"
require "./request_authorization_error"

module Slack::Auth
  # Extracts an exact owner and explicit grant from payloads that the caller trusts.
  # The caller must bind app-less shortcuts to this configured app. Use RequestAuthorizer
  # for raw HTTP requests because this type does not verify signatures or app routing.
  class QueryExtractor
    def initialize(@expected_app_id : String)
      invalid(:missing_app) if @expected_app_id.empty?
    end

    def extract(event : Slack::VerifiedEvent, grant : GrantKey,
                selected_owner : InstallationKey? = nil) : InstallationQuery
      verify_app(event.api_app_id)
      invalid(:missing_owner) if event.authorizations.empty?

      owners = [] of InstallationKey
      event.authorizations.each do |authorization|
        required_id(authorization.user_id, :missing_authorization_user)
        owner = owner(authorization.enterprise_install, authorization.enterprise_id, authorization.team_id)
        owners << owner unless owners.includes?(owner)
      end

      resolved = if selection = selected_owner
                   invalid(:app_mismatch) unless selection.app_id == @expected_app_id
                   invalid(:owner_not_authorized) unless owners.includes?(selection)
                   selection
                 else
                   invalid(:ambiguous_owner) unless owners.size == 1
                   owners.first
                 end

      InstallationQuery.new(resolved, grant, actor_user_id: actor(event.event), visible_team_id: optional_id(event.team_id))
    end

    def extract(command : Slack::Command, grant : GrantKey) : InstallationQuery
      verify_app(command.api_app_id)
      resolved = owner(command.is_enterprise_install, command.enterprise_id, command.team_id)
      InstallationQuery.new(resolved, grant,
        actor_user_id: required_id(command.user_id, :missing_actor),
        visible_team_id: optional_id(command.team_id))
    end

    def extract(interaction : Slack::Interaction, grant : GrantKey) : InstallationQuery
      verify_interaction_app(interaction)
      visible_team_id = optional_id(interaction.team.try(&.id))
      installed_team_id = optional_id(view_installed_team_id(interaction))
      team_id = installed_team_id || visible_team_id
      enterprise_id = interaction_enterprise_id(interaction, team_id, visible_team_id)
      actor_id = interaction.user.try(&.id) || invalid(:missing_actor)
      resolved = owner(interaction.is_enterprise_install, enterprise_id, team_id)
      InstallationQuery.new(resolved, grant,
        actor_user_id: required_id(actor_id, :missing_actor), visible_team_id: visible_team_id)
    end

    private def verify_interaction_app(interaction : Slack::Interaction) : Nil
      if app_id = interaction.api_app_id
        verify_app(app_id)
      elsif !interaction.is_a?(Slack::Interactions::Shortcut) && !interaction.is_a?(Slack::Interactions::MessageAction)
        invalid(:missing_app)
      end
    end

    private def view_installed_team_id(interaction : Slack::Interaction) : String?
      case interaction
      when Slack::Interactions::BlockAction
        interaction.view.try(&.app_installed_team_id)
      when Slack::Interactions::ViewSubmission
        interaction.view.try(&.app_installed_team_id)
      when Slack::Interactions::ViewClosed
        interaction.view.try(&.app_installed_team_id)
      end
    end

    private def interaction_enterprise_id(interaction : Slack::Interaction, owner_team_id : String?,
                                          visible_team_id : String?) : String?
      top_level = optional_id(interaction.enterprise.try(&.id))
      nested = optional_id(interaction.team.try(&.enterprise_id))

      return reconcile_enterprise(top_level, nested) if interaction.is_enterprise_install == true
      return reconcile_enterprise(top_level, nested) if owner_team_id == visible_team_id

      # View installation metadata can name a workspace other than the visible team.
      # Slack does not provide the owning workspace's enterprise in that case.
      invalid(:ambiguous_owner) if reconcile_enterprise(top_level, nested)
    end

    private def reconcile_enterprise(top_level : String?, nested : String?) : String?
      invalid(:conflicting_owner) if top_level && nested && top_level != nested
      nested || top_level
    end

    private def owner(enterprise_install : Bool?, enterprise_id : String?, team_id : String?) : InstallationKey
      enterprise = optional_id(enterprise_id)
      team = optional_id(team_id)

      case enterprise_install
      when true
        InstallationKey.new(@expected_app_id, :organization,
          enterprise_id: enterprise || invalid(:missing_owner))
      when false
        InstallationKey.new(@expected_app_id, :workspace,
          enterprise_id: enterprise, team_id: team || invalid(:missing_owner))
      when nil
        invalid(:invalid_install_kind) if enterprise
        InstallationKey.new(@expected_app_id, :workspace, team_id: team || invalid(:missing_owner))
      else
        invalid(:invalid_install_kind)
      end
    end

    private def verify_app(app_id : String) : Nil
      required_id(app_id, :missing_app)
      invalid(:app_mismatch) unless app_id == @expected_app_id
    end

    private def required_id(value : String, reason : Symbol) : String
      invalid(reason) if value.empty?
      value
    end

    private def optional_id(value : String?) : String?
      invalid(:empty_id) if value.try(&.empty?)
      value
    end

    private def actor(event : Slack::Event) : String?
      value = case event
              when Slack::Events::AppHomeOpened      then event.user
              when Slack::Events::AppMentioned       then event.user
              when Slack::Events::Message            then event.user
              when Slack::Events::Message::BotAdd    then event.user
              when Slack::Events::Message::FileShare then event.user
              when Slack::Events::ReactionAdded      then event.user
              when Slack::Events::ReactionRemoved    then event.user
              end
      optional_id(value)
    end

    private def invalid(reason : Symbol) : NoReturn
      raise RequestAuthorizationError.new(reason)
    end
  end
end

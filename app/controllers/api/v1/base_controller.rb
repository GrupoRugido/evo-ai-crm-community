class Api::V1::BaseController < Api::BaseController
  include SwitchLocale
  include ApiResponseHelper
  # EVO-CUSTOM: resolve Current.workspace_id e expoe workspace_scope/_strict.
  # Fica no BaseController da v1 (depois da autenticacao, que roda no
  # Api::BaseController) para que qualquer controller possa escopar sem repetir
  # o include. Sem workspace ativo os helpers sao no-op.
  include WorkspaceScopeConcern

  around_action :switch_locale_using_default

  private

  def paginate_instance_variables(page, per_page)
    %w[
      @contacts
      @conversations
      @inboxes
      @labels
      @teams
      @team_members
      @canned_responses
      @webhooks
      @macros
      @agent_bots
      @notifications
      @automation_rules
      @custom_filters
      @custom_attribute_definitions
      @dashboard_apps
      @scheduled_actions
      @scheduled_action_templates
      @templates
      @pipeline_items
      @pipeline_stages
      @pipeline_tasks
      @pipelines
      @csat_survey_responses
      @messages
      @notes
      @moderations
    ].each do |var_name|
      var = instance_variable_get(var_name)
      next unless var.respond_to?(:page)

      instance_variable_set(var_name, var.page(page).per(per_page))
    end
  end
end

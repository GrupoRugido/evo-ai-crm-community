# frozen_string_literal: true

class Api::V1::DashboardController < Api::V1::BaseController
  require_permissions({
    customer: 'dashboard.read'
  })

  def customer
    dashboard_data = Dashboard::CustomerDashboardService.new(
      params: dashboard_params,
      allowed_inbox_ids: dashboard_allowed_inbox_ids
    ).call

    success_response(
      data: dashboard_data,
      message: 'Customer dashboard data retrieved successfully'
    )
  end

  private

  # EVO-CUSTOM: nil = admin/service sem restricao; array = so as caixas em que
  # o usuario e membro. E o que faz o dashboard do papel "cliente" mostrar
  # apenas as metricas das caixas dele.
  def dashboard_allowed_inbox_ids
    return nil if current_user.nil? || current_user.unrestricted_inbox_access?

    current_user.assigned_inboxes.pluck(:id)
  end

  def dashboard_params
    params.permit(:pipeline_id, :team_id, :inbox_id, :user_id, :since, :until)
  end
end

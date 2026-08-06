# frozen_string_literal: true

# EVO-CUSTOM: alimenta o seletor de workspace da interface.
#
# Deliberadamente sem require_permissions: a resposta E o escopo do proprio
# usuario. Admin recebe a lista completa (para transitar entre clientes);
# usuario de cliente recebe SO o workspace dele — assim o seletor nem aparece
# para ele, e mesmo que aparecesse nao teria para onde ir.
class Api::V1::WorkspacesController < Api::V1::BaseController
  def index
    success_response(
      data: visible_workspaces.map { |w| serialize(w) },
      message: 'Workspaces retrieved successfully'
    )
  end

  # O workspace ativo desta requisicao, ja resolvido pelo WorkspaceScopeConcern.
  # A interface usa para saber qual logo mostrar sem ter que adivinhar.
  def current
    workspace = Current.workspace_id.present? ? Workspace.find_by(id: Current.workspace_id) : nil

    success_response(
      data: workspace ? serialize(workspace) : nil,
      message: 'Current workspace retrieved successfully'
    )
  end

  # EVO-CUSTOM: edicao do workspace — hoje so a marca (nome e logo).
  # Restrito a admin: o cliente nao troca a propria identidade visual, quem
  # configura isso somos nos ao cadastrar o cliente.
  def update
    return render_forbidden unless admin_like?

    workspace = Workspace.find_by(id: params[:id])
    return error_response(ApiErrorCodes::RESOURCE_NOT_FOUND, 'Workspace not found', status: :not_found) if workspace.nil?

    if workspace.update(workspace_params)
      success_response(data: serialize(workspace), message: 'Workspace updated successfully')
    else
      error_response(
        ApiErrorCodes::VALIDATION_ERROR,
        'Validation failed',
        details: workspace.errors.full_messages,
        status: :unprocessable_entity
      )
    end
  end

  private

  def workspace_params
    params.permit(:name, :logo_url, :active)
  end

  def render_forbidden
    error_response(ApiErrorCodes::FORBIDDEN, 'Only administrators can change a workspace', status: :forbidden)
  end

  # EVO-CUSTOM: quem PERTENCE a um workspace so enxerga o proprio — a checagem
  # vem antes de qualquer coisa.
  #
  # Achado no QA: o atendente de um cliente tem a permissao conversations.read_all
  # (herdada do papel `agent` do upstream), o que ligava evo_can_read_all_inboxes
  # e o fazia passar por "admin" aqui. Resultado: ele via os NOMES das outras
  # clinicas no seletor. Pertencer a um workspace e o sinal mais forte e tem
  # prioridade sobre qualquer permissao ampla.
  def visible_workspaces
    proprio = current_user&.workspace_id
    return Workspace.active.where(id: proprio).order(:name) if proprio.present?
    return Workspace.active.order(:name) if admin_like?

    Workspace.none
  end

  def admin_like?
    current_user&.administrator? || Current.evo_can_read_all_inboxes
  end

  def serialize(workspace)
    {
      id: workspace.id,
      name: workspace.name,
      slug: workspace.slug,
      logo_url: workspace.logo_url,
      settings: workspace.settings
    }
  end
end

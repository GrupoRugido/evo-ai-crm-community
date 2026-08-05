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

  private

  def visible_workspaces
    return Workspace.active.order(:name) if admin_like?

    Workspace.active.where(id: current_user&.workspace_id).order(:name)
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

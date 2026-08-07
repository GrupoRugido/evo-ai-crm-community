# frozen_string_literal: true

# EVO-CUSTOM: quem trabalha em qual cliente, com que papel e enxergando quanto.
#
# Faltava exatamente isto: dava para criar usuario (no auth-service) e dava para
# criar cliente, mas nada ligava os dois. Na pratica todo usuario nascia global.
#
# Quem administra:
#   - super admin / admin nosso: qualquer cliente
#   - gestor: apenas o cliente dele, e nao pode promover ninguem a gestor
#     (senao o teto do papel deixaria de ser teto)
class Api::V1::WorkspaceMembersController < Api::V1::BaseController
  before_action :fetch_workspace
  before_action :autorizar_gestao

  def index
    membros = @workspace.workspace_members.includes(:user).order('users.name')

    success_response(
      data: membros.map { |m| serialize(m) },
      message: 'Workspace members retrieved successfully'
    )
  end

  def create
    membro = @workspace.workspace_members.new(member_params)
    return render_papel_proibido if promovendo_gestor_sem_poder?(membro.role_key)

    if membro.save
      success_response(data: serialize(membro), message: 'Member added successfully', status: :created)
    else
      erro_validacao(membro)
    end
  end

  def update
    membro = @workspace.workspace_members.find(params[:id])
    return render_papel_proibido if promovendo_gestor_sem_poder?(member_params[:role_key])

    if membro.update(member_params)
      success_response(data: serialize(membro), message: 'Member updated successfully')
    else
      erro_validacao(membro)
    end
  end

  def destroy
    membro = @workspace.workspace_members.find(params[:id])
    membro.destroy
    success_response(data: { id: membro.id }, message: 'Member removed successfully')
  end

  private

  def fetch_workspace
    @workspace = Workspace.find(params[:workspace_id])
  end

  # O gestor administra o proprio cliente; o admin nosso administra qualquer um.
  def autorizar_gestao
    return if admin_like?
    return if current_user&.gestor_de?(@workspace.id)

    error_response(ApiErrorCodes::FORBIDDEN, 'Only administrators or the workspace manager can do this',
                   status: :forbidden)
  end

  # Um gestor nao cria outro gestor: promover esta acima do teto dele, e sem
  # isso ele poderia se multiplicar dentro do cliente sem passar por nos.
  def promovendo_gestor_sem_poder?(papel)
    papel.to_s == 'gestor' && !admin_like?
  end

  def render_papel_proibido
    error_response(ApiErrorCodes::FORBIDDEN, 'Only administrators can grant the manager role', status: :forbidden)
  end

  def erro_validacao(membro)
    error_response(ApiErrorCodes::VALIDATION_ERROR, 'Validation failed',
                   details: membro.errors.full_messages, status: :unprocessable_entity)
  end

  def admin_like?
    current_user&.administrator? && !current_user.belongs_to_workspace?
  end

  def member_params
    params.permit(:user_id, :role_key, :conversation_visibility)
  end

  def serialize(membro)
    {
      id: membro.id,
      workspace_id: membro.workspace_id,
      user_id: membro.user_id,
      user_name: membro.user&.name,
      user_email: membro.user&.email,
      role_key: membro.role_key,
      conversation_visibility: membro.conversation_visibility
    }
  end
end

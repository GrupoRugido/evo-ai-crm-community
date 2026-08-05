# frozen_string_literal: true

# EVO-CUSTOM: resolve o workspace ativo da requisicao e oferece o helper de
# escopo usado pelos controllers.
#
# Duas fontes, nessa ordem de autoridade:
#
#   1. Usuario de CLIENTE (users.workspace_id preenchido) — o workspace e o
#      dele, ponto. Header e ignorado: cliente nao passeia entre workspaces.
#
#   2. Nosso ADMIN (workspace_id nulo) — pode mandar o header X-Workspace-Id
#      para "entrar" num workspace (o seletor da interface). Sem header, ve a
#      instalacao inteira, que e o comportamento de hoje.
#
# workspace_scope(relation) devolve a relation intacta quando nao ha workspace
# ativo, entao ligar isto num controller nao muda nada ate existir workspace.
module WorkspaceScopeConcern
  extend ActiveSupport::Concern

  WORKSPACE_HEADER = 'X-Workspace-Id'

  included do
    before_action :resolve_current_workspace
  end

  private

  def resolve_current_workspace
    Current.workspace_id = current_user_workspace_id || admin_selected_workspace_id
  end

  def current_user_workspace_id
    return nil unless current_user.respond_to?(:workspace_id)

    current_user&.workspace_id
  end

  # So admin escolhe. E o id e validado contra a tabela para um header invalido
  # nao virar "workspace inexistente" (que esvaziaria as listas silenciosamente).
  def admin_selected_workspace_id
    return nil unless current_user&.administrator? || Current.evo_can_read_all_inboxes

    requested = request.headers[WORKSPACE_HEADER].presence
    return nil if requested.blank?

    Workspace.where(id: requested).pick(:id)
  end

  # Aplica o escopo quando ha workspace ativo. NULL (global/nosso) continua
  # visivel de proposito: sem isso, o retrofit incompleto esconderia dados que
  # ainda nao foram atribuidos.
  def workspace_scope(relation, column: :workspace_id)
    return relation if Current.workspace_id.blank?

    table = relation.klass.table_name
    relation.where("#{table}.#{column} = ? OR #{table}.#{column} IS NULL", Current.workspace_id)
  end

  # Variante estrita, sem o "OR IS NULL": usada onde vazar registro global seria
  # errado (ex.: listagem de automacoes de um cliente).
  def workspace_scope_strict(relation, column: :workspace_id)
    return relation if Current.workspace_id.blank?

    relation.where(column => Current.workspace_id)
  end
end

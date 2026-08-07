# frozen_string_literal: true

# EVO-CUSTOM: a regra do "quanto da fila eu enxergo", em UM lugar.
#
# Existem dois caminhos independentes para listar conversa e eles nao se
# conversam: o ConversationFinder (o index, com seu proprio filtro por caixa) e o
# PermissionFilterService (usado pelo /filter, por pipelines e pelo OAuth).
# Aplicar a visibilidade so no segundo deixou o index vazando — medido: um
# atendente restrito a "apenas as minhas" recebeu 100 conversas, 18 de outros
# atendentes e 82 sem dono.
#
# Por isso a regra mora aqui e os dois chamam. Colocar de novo em cada um seria
# repetir a mesma armadilha que ja custou o vazamento de contatos, busca e
# dashboard antes de eu centralizar em User#unrestricted_inbox_access?.
module Conversations::VisibilityScope
  module_function

  def apply(escopo, user, workspace_id = nil)
    return escopo unless user.respond_to?(:conversation_visibility_for)

    case user.conversation_visibility_for(workspace_id || Current.workspace_id)
    when 'apenas_minhas'
      escopo.where(conversations: { assignee_id: user.id })
    when 'fila'
      # Sem dono + as minhas: e o que faz uma fila funcionar, porque a pessoa
      # precisa enxergar o que ninguem pegou para poder pegar.
      escopo.where('conversations.assignee_id IS NULL OR conversations.assignee_id = ?', user.id)
    else
      escopo
    end
  end
end

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

  # EVO-CUSTOM: quem tem vinculo so opera DENTRO dos seus clientes.
  #
  # Um vinculo: e ele, sem escolha. Varios (gerente de contas nosso): o header
  # escolhe, desde que aponte para um dos dele; um header de cliente alheio nao
  # vira "sem workspace" — cai no primeiro vinculo, senao bastaria mandar um id
  # qualquer para escapar do escopo.
  def current_user_workspace_id
    return nil unless current_user.respond_to?(:workspace_ids)

    ids = current_user.workspace_ids
    return nil if ids.empty?
    return ids.first if ids.size == 1

    pedido = request.headers[WORKSPACE_HEADER].presence
    ids.include?(pedido) ? pedido : ids.first
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

  # EVO-CUSTOM: workspace que um registro NOVO deve receber.
  #
  # Existe porque criar pela API era o caminho que furava o modelo: os
  # controllers de inbox, agente, automacao, etiqueta e resposta rapida nunca
  # tocavam em workspace_id, entao tudo que os colaboradores criavam por script
  # nascia global — visivel para todos os clientes. So teams e workspaces
  # atribuiam.
  #
  # Precedencia:
  #   1. Usuario de CLIENTE  -> o workspace dele, sempre. Ignora corpo e header:
  #      cliente nao cria coisa no workspace do vizinho.
  #   2. ADMIN               -> workspace_id do corpo (validado contra a tabela),
  #      senao o header X-Workspace-Id, senao nil (global, de proposito).
  #
  # O corpo e aceito alem do header porque a API e usada por script: exigir
  # header numa chamada que ja manda JSON e o tipo de detalhe que faz o agente
  # de IA errar e criar o recurso no lugar errado.
  # O corpo e lido de dois lugares porque as duas formas chegam na pratica: no
  # topo (`{"name": ..., "workspace_id": ...}`, o formato dos controllers estilo
  # Chatwoot) e sob a chave do recurso. O ParamsWrapper do Rails costuma
  # espelhar um no outro, mas depender desse espelho e fragil — melhor olhar os
  # dois.
  def workspace_id_for_create(corpo = nil)
    return Current.workspace_id if current_user&.belongs_to_workspace?
    return Current.workspace_id unless admin_pode_escolher_workspace?

    pedido = extrai_workspace_id(corpo) || extrai_workspace_id(params)
    return Current.workspace_id if pedido.blank?

    Workspace.where(id: pedido).pick(:id)
  end

  def extrai_workspace_id(fonte)
    return nil unless fonte.is_a?(ActionController::Parameters) || fonte.is_a?(Hash)

    fonte[:workspace_id].presence
  end

  def admin_pode_escolher_workspace?
    current_user&.administrator? || Current.evo_can_read_all_inboxes
  end
end

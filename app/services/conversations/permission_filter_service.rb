class Conversations::PermissionFilterService
  attr_reader :conversations, :user

  def initialize(conversations, user, _account = nil)
    @conversations = conversations
    @user = user
  end

  def perform
    # No resolvable user (e.g. service-token contexts) degrades to all conversations,
    # preserving the pre-feature behavior and avoiding a NoMethodError on user.role.
    return conversations if user.nil?

    # EVO-CUSTOM: o atalho de administrador nao vale para quem tem vinculo com um
    # cliente. Um Account Owner de clinica tem papel administrativo e passaria
    # direto por aqui, enxergando a fila das outras clinicas — e o mesmo bypass
    # que ja tinha vazado em contatos, busca e dashboard antes de eu centralizar
    # a regra em unrestricted_inbox_access?.
    return conversations if unrestricted?

    accessible_conversations
  end

  private

  def accessible_conversations
    # Use assigned_inboxes (not raw inboxes) so `conversations.read_all` is
    # honored consistently; no membership and no grant means no inboxes.
    # Degrade to all inboxes only when there is no resolvable user (service
    # contexts).
    accessible = user&.assigned_inboxes || Inbox.all
    aplicar_visibilidade(conversations.where(inbox: accessible))
  end

  # EVO-CUSTOM: o "so o que e meu" passa a RESTRINGIR, nao so contar.
  #
  # A interface ja mostrava mine_count / unassigned_count / all_count, mas eram
  # filtros que a propria pessoa escolhia — nada impedia o atendente de clicar
  # em "todas" e ler a fila inteira da clinica. Quem decide agora e o vinculo
  # dela com o cliente (workspace_members.conversation_visibility), que so o
  # gestor ou o super admin editam.
  #
  # O escopo por caixa continua sendo a primeira barreira; isto aperta dentro
  # dela.
  def aplicar_visibilidade(escopo)
    return escopo unless user.respond_to?(:conversation_visibility_for)

    case user.conversation_visibility_for(Current.workspace_id)
    when 'apenas_minhas'
      escopo.where(assignee_id: user.id)
    when 'fila'
      # Sem dono + as minhas: e o que faz uma fila funcionar, porque a pessoa
      # precisa enxergar o que ainda nao foi pego para poder pegar.
      escopo.where('conversations.assignee_id IS NULL OR conversations.assignee_id = ?', user.id)
    else
      escopo
    end
  end

  def unrestricted?
    return user.unrestricted_inbox_access? if user.respond_to?(:unrestricted_inbox_access?)

    user_role == 'administrator'
  end

  def user_role
    user.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')

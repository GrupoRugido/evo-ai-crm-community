# EVO-CUSTOM: monta o trecho da conversa que a IA nao viu.
#
# Por que isso e necessario: mensagem de saida nunca invoca o agente
# (AgentBotListener corta em `return unless message.incoming?`), e mensagem de
# entrada que chega enquanto a conversa nao esta "pending" e pulada. Nada disso
# entra na sessao ADK. Resultado medido antes desta mudanca: 1.549 mensagens de
# humano na base, 0 presentes no contexto do agente.
#
# Existe como classe separada porque HA DOIS caminhos de volta para a IA:
#
#   1. Acao de inatividade 'reopen' — conversa ficou "open" apos a intervencao
#      humana e volta sozinha depois do tempo configurado.
#
#   2. Conversa RESOLVIDA que recebe mensagem nova — Message#reopen_resolved_conversation
#      joga direto para "pending" quando a caixa tem bot ativo. E o caso do
#      atendente que finaliza e encerra, e dias depois o cliente volta a escrever.
#      Esse caminho e nativo do upstream e nao passa pela acao de inatividade.
#
# Sem cobrir o caminho 2, a IA reassume sem saber o que foi combinado — e o
# cenario classico de agendamento: o humano fecha o horario, o cliente volta dias
# depois perguntando que horas era, e a IA nao faz ideia.
class AgentBots::MissedContextBuilder
  MAX_MESSAGES = 50
  MAX_CHARS = 4000
  ATTRIBUTE = 'pending_ai_context'.freeze

  # Monta e grava em additional_attributes. Usa update_column para nao disparar
  # conversation_updated nem gerar mensagem de atividade na timeline do cliente.
  #
  # `except` e a mensagem que disparou a reabertura: ela ja vai ser enviada ao
  # bot como conteudo principal, entao incluir aqui a duplicaria.
  def self.capture(conversation, except: nil)
    context = build(conversation, except: except)
    return false if context.blank?

    attributes = (conversation.additional_attributes || {}).merge(ATTRIBUTE => context)
    conversation.update_column(:additional_attributes, attributes)
    Rails.logger.info "[MissedContext] Guardado para conversa #{conversation.id} (#{context.length} chars)"
    true
  rescue StandardError => e
    Rails.logger.error "[MissedContext] Falha ao guardar contexto: #{e.message}"
    false
  end

  # Tudo que aconteceu depois da ultima fala da IA. Nao precisa de marcador de
  # "ja entreguei": assim que a IA responde, a mensagem dela vira o novo corte e
  # a janela esvazia sozinha.
  def self.build(conversation, except: nil)
    last_ai_message = conversation.messages.reorder(nil)
                                  .where(message_type: :outgoing, sender_type: 'AgentBot')
                                  .order(created_at: :desc).first

    scope = conversation.messages.reorder(nil).where.not(message_type: :activity)
    scope = scope.where('messages.created_at > ?', last_ai_message.created_at) if last_ai_message
    scope = scope.where.not(id: except.id) if except

    missed = scope.order(created_at: :asc).last(MAX_MESSAGES)
    return nil if missed.blank?

    lines = missed.filter_map do |message|
      text = message.content.to_s.strip
      next if text.blank?

      "#{role_for(message)}: #{text}"
    end
    return nil if lines.blank?

    body = lines.join("\n")
    body.length > MAX_CHARS ? "#{body[0, MAX_CHARS]}..." : body
  end

  def self.role_for(message)
    return 'Cliente' if message.incoming?
    return 'IA' if message.sender_type == 'AgentBot'

    'Atendente'
  end
  private_class_method :role_for
end

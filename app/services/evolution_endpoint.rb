# frozen_string_literal: true

# EVO-CUSTOM: endereco e chave da Evolution API da instalacao.
#
# Existe porque a Evolution passou a ser UMA so para todos os canais: quem cria
# um canal informa o numero, nao a infraestrutura. Antes cada canal carregava a
# propria copia de `api_url` e `admin_token`, o que significava a mesma chave
# mestra repetida em cada linha de channel_whatsapp e um campo a mais para o
# operador errar.
#
# Precedencia: ENV primeiro, InstallationConfig depois.
#
# ENV vem antes de proposito. No corte o banco e restaurado do dump de producao,
# e o que estivesse em installation_configs voltaria ao valor antigo — ou a
# nulo. ENV vive no compose, que e o que de fato descreve a instalacao, e passa
# incolume pelo restore.
module EvolutionEndpoint
  extend self

  def api_url
    resolver('EVOLUTION_API_URL')
  end

  def admin_token
    resolver('EVOLUTION_ADMIN_SECRET')
  end

  def go_api_url
    resolver('EVOLUTION_GO_API_URL')
  end

  def go_admin_token
    resolver('EVOLUTION_GO_ADMIN_SECRET')
  end

  # A instalacao tem Evolution padrao configurada? A tela de canal usa isto para
  # decidir se esconde os campos de infraestrutura.
  def configured?
    api_url.present? && admin_token.present?
  end

  private

  def resolver(chave)
    ENV.fetch(chave, nil).presence&.strip ||
      GlobalConfigService.load(chave, '').to_s.strip.presence
  end
end

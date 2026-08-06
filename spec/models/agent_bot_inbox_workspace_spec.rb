require 'rails_helper'

# O vinculo agente<->caixa nao tinha nenhuma trava de workspace: dava para ligar
# o agente de uma clinica na caixa de outra e a mensagem do paciente ia parar no
# agente errado. Medido no ambiente de dev antes da correcao.
RSpec.describe AgentBotInbox do
  let(:ws_a) { Workspace.create!(name: 'Clinica A', slug: 'clinica-a') }
  let(:ws_b) { Workspace.create!(name: 'Clinica B', slug: 'clinica-b') }

  def caixa(workspace_id)
    Inbox.create!(name: "caixa-#{SecureRandom.hex(4)}",
                  channel: Channel::Api.create!,
                  workspace_id: workspace_id)
  end

  def agente(workspace_id)
    AgentBot.create!(name: "bot-#{SecureRandom.hex(4)}",
                     outgoing_url: 'http://exemplo.invalid/bot',
                     workspace_id: workspace_id)
  end

  it 'recusa agente de outro workspace' do
    vinculo = described_class.new(inbox: caixa(ws_a.id), agent_bot: agente(ws_b.id))

    expect(vinculo).not_to be_valid
    expect(vinculo.errors[:agent_bot_id].join).to include('outro workspace')
  end

  it 'aceita agente do mesmo workspace' do
    expect(described_class.new(inbox: caixa(ws_a.id), agent_bot: agente(ws_a.id))).to be_valid
  end

  it 'aceita agente global (sem workspace) em qualquer caixa' do
    expect(described_class.new(inbox: caixa(ws_a.id), agent_bot: agente(nil))).to be_valid
  end

  it 'aceita qualquer agente numa caixa sem workspace (instalacao de cliente unico)' do
    expect(described_class.new(inbox: caixa(nil), agent_bot: agente(ws_b.id))).to be_valid
  end
end

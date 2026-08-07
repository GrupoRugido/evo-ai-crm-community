require 'rails_helper'

RSpec.describe WorkspaceMember do
  let(:ws_a) { Workspace.create!(name: 'Clinica A', slug: 'clinica-a') }
  let(:ws_b) { Workspace.create!(name: 'Clinica B', slug: 'clinica-b') }
  let(:pessoa) { User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(4)}@ex.com") }

  def caixa(workspace_id, nome = nil)
    Inbox.create!(name: nome || "caixa-#{SecureRandom.hex(4)}",
                  channel: Channel::Api.create!,
                  workspace_id: workspace_id)
  end

  describe 'o vinculo' do
    it 'nao aceita a mesma pessoa duas vezes no mesmo cliente' do
      described_class.create!(user: pessoa, workspace: ws_a)
      repetido = described_class.new(user: pessoa, workspace: ws_a)

      expect(repetido).not_to be_valid
      expect(repetido.errors[:user_id].join).to include('ja e membro')
    end

    it 'aceita a mesma pessoa em clientes diferentes com papeis diferentes' do
      described_class.create!(user: pessoa, workspace: ws_a, role_key: 'gestor')
      segundo = described_class.new(user: pessoa, workspace: ws_b, role_key: 'atendente')

      expect(segundo).to be_valid
    end

    it 'recusa visibilidade inventada' do
      vinculo = described_class.new(user: pessoa, workspace: ws_a, conversation_visibility: 'tudo')
      expect(vinculo).not_to be_valid
    end
  end

  describe 'alcance de caixas' do
    it 'da ao gestor TODAS as caixas do cliente, sem precisar ser membro de cada uma' do
      duas = [caixa(ws_a.id), caixa(ws_a.id)]
      caixa(ws_b.id) # de outro cliente, nao pode entrar
      described_class.create!(user: pessoa, workspace: ws_a, role_key: 'gestor')

      expect(pessoa.reload.assigned_inboxes.pluck(:id)).to match_array(duas.map(&:id))
    end

    it 'da ao atendente apenas as caixas em que ele e membro' do
      dele, nao_dele = caixa(ws_a.id), caixa(ws_a.id)
      described_class.create!(user: pessoa, workspace: ws_a, role_key: 'atendente')
      InboxMember.create!(user: pessoa, inbox: dele)

      ids = pessoa.reload.assigned_inboxes.pluck(:id)
      expect(ids).to eq([dele.id])
      expect(ids).not_to include(nao_dele.id)
    end

    it 'nao vaza caixa de outro cliente para o gestor' do
      caixa(ws_a.id)
      alheia = caixa(ws_b.id)
      described_class.create!(user: pessoa, workspace: ws_a, role_key: 'gestor')

      expect(pessoa.reload.assigned_inboxes.pluck(:id)).not_to include(alheia.id)
    end
  end

  describe 'visibilidade' do
    it 'devolve a do vinculo do cliente ativo' do
      described_class.create!(user: pessoa, workspace: ws_a, conversation_visibility: 'apenas_minhas')
      described_class.create!(user: pessoa, workspace: ws_b, conversation_visibility: 'todas')

      expect(pessoa.conversation_visibility_for(ws_a.id)).to eq('apenas_minhas')
      expect(pessoa.conversation_visibility_for(ws_b.id)).to eq('todas')
    end

    it 'quem nao tem vinculo nenhum nao e restrito por dono' do
      expect(pessoa.conversation_visibility_for(ws_a.id)).to eq('todas')
    end
  end
end

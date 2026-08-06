require 'rails_helper'

# Entrar num workspace pelo seletor e uma LENTE: vale para todo mundo, inclusive
# para quem tem acesso amplo. "Irrestrito" quer dizer que a pessoa PODE escolher
# qualquer workspace, nao que a escolha seja ignorada.
#
# Medido antes desta correcao, com o super admin e o Oral Riso selecionado:
#   canais        -> 0     (pior que nao filtrar: parece que o cliente nao tem)
#   conversas     -> 56    (a instalacao inteira)
#   contatos      -> 1.997 (a instalacao inteira)
#   agentes de IA -> 11    (a instalacao inteira)
RSpec.describe 'a lente do seletor de workspace' do
  let(:ws_a) { Workspace.create!(name: 'Clinica A', slug: 'clinica-a') }
  let(:ws_b) { Workspace.create!(name: 'Clinica B', slug: 'clinica-b') }

  # Nosso admin: sem vinculo com workspace nenhum e com acesso amplo.
  let(:admin) do
    u = User.create!(name: 'Nosso Admin', email: "admin-#{SecureRandom.hex(4)}@rugido.com")
    allow(u).to receive(:administrator?).and_return(true)
    u
  end

  def caixa(workspace_id)
    Inbox.create!(name: "cx-#{SecureRandom.hex(4)}", channel: Channel::Api.create!, workspace_id: workspace_id)
  end

  after { Current.workspace_id = nil }

  describe 'sem workspace ativo' do
    it 'o admin enxerga a instalacao inteira' do
      caixa(ws_a.id)
      caixa(ws_b.id)
      Current.workspace_id = nil

      expect(admin.unrestricted_inbox_access?).to be(true)
      expect(admin.assigned_inboxes.count).to eq(Inbox.count)
    end
  end

  describe 'com um workspace ativo' do
    it 'deixa de ser irrestrito — e o que faz contatos, busca e painel filtrarem' do
      Current.workspace_id = ws_a.id

      expect(admin.unrestricted_inbox_access?).to be(false)
    end

    it 'alcanca TODAS as caixas do workspace, mesmo sem ser membro de nenhuma' do
      duas = [caixa(ws_a.id), caixa(ws_a.id)]
      caixa(ws_b.id)
      Current.workspace_id = ws_a.id

      ids = admin.assigned_inboxes.pluck(:id)
      expect(ids).to match_array(duas.map(&:id))
    end

    it 'nao devolve zero (era o sintoma: a tela de Canais ficava vazia)' do
      caixa(ws_a.id)
      Current.workspace_id = ws_a.id

      expect(admin.assigned_inboxes.count).to be_positive
    end

    it 'nao vaza caixa do outro workspace' do
      caixa(ws_a.id)
      alheia = caixa(ws_b.id)
      Current.workspace_id = ws_a.id

      expect(admin.assigned_inboxes.pluck(:id)).not_to include(alheia.id)
    end
  end

  describe 'o membro comum nao ganha alcance por causa disto' do
    it 'continua vendo so as caixas de que participa' do
      dele = caixa(ws_a.id)
      nao_dele = caixa(ws_a.id)
      pessoa = User.create!(name: 'Bia', email: "bia-#{SecureRandom.hex(4)}@ex.com")
      WorkspaceMember.create!(user: pessoa, workspace: ws_a, role_key: 'atendente')
      InboxMember.create!(user: pessoa, inbox: dele)
      Current.workspace_id = ws_a.id

      ids = pessoa.reload.assigned_inboxes.pluck(:id)
      expect(ids).to eq([dele.id])
      expect(ids).not_to include(nao_dele.id)
    end
  end
end

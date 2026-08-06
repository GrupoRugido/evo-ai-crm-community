require 'rails_helper'

# A visibilidade so vale se RESTRINGIR. Antes disto os contadores mine/unassigned/all
# existiam como filtro que a propria pessoa escolhia — o atendente clicava em
# "todas" e lia a fila inteira da clinica.
RSpec.describe Conversations::PermissionFilterService do
  let(:ws)    { Workspace.create!(name: 'Clinica A', slug: 'clinica-a') }
  let(:cx)    { Inbox.create!(name: "cx-#{SecureRandom.hex(4)}", channel: Channel::Api.create!, workspace_id: ws.id) }
  let(:ana)   { User.create!(name: 'Ana',  email: "ana-#{SecureRandom.hex(4)}@ex.com") }
  let(:bruno) { User.create!(name: 'Bruno', email: "bruno-#{SecureRandom.hex(4)}@ex.com") }

  def conversa(assignee)
    contato = Contact.create!(name: "c-#{SecureRandom.hex(4)}")
    ci = ContactInbox.create!(contact: contato, inbox: cx, source_id: SecureRandom.uuid)
    Conversation.create!(inbox: cx, contact: contato, contact_inbox: ci, assignee: assignee)
  end

  def visiveis_para(pessoa)
    described_class.new(Conversation.all, pessoa).perform.pluck(:id)
  end

  before do
    InboxMember.create!(user: ana, inbox: cx)
    Current.workspace_id = ws.id
  end

  after { Current.workspace_id = nil }

  let!(:minha)   { conversa(ana) }
  let!(:do_bruno) { conversa(bruno) }
  let!(:sem_dono) { conversa(nil) }

  it 'todas: enxerga a fila inteira da caixa' do
    WorkspaceMember.create!(user: ana, workspace: ws, conversation_visibility: 'todas')

    expect(visiveis_para(ana.reload)).to match_array([minha.id, do_bruno.id, sem_dono.id])
  end

  it 'fila: sem dono mais as minhas, nunca a de outro atendente' do
    WorkspaceMember.create!(user: ana, workspace: ws, conversation_visibility: 'fila')

    ids = visiveis_para(ana.reload)
    expect(ids).to match_array([minha.id, sem_dono.id])
    expect(ids).not_to include(do_bruno.id)
  end

  it 'apenas_minhas: so o que esta atribuido a ela' do
    WorkspaceMember.create!(user: ana, workspace: ws, conversation_visibility: 'apenas_minhas')

    expect(visiveis_para(ana.reload)).to eq([minha.id])
  end

  it 'o gestor enxerga tudo do cliente mesmo sem ser membro da caixa' do
    gestora = User.create!(name: 'Gi', email: "gi-#{SecureRandom.hex(4)}@ex.com")
    WorkspaceMember.create!(user: gestora, workspace: ws, role_key: 'gestor', conversation_visibility: 'todas')

    expect(visiveis_para(gestora.reload)).to match_array([minha.id, do_bruno.id, sem_dono.id])
  end

  # O index NAO passa pelo PermissionFilterService: ele tem o proprio filtro no
  # ConversationFinder. Aplicar a visibilidade so no service deixou o index
  # vazando — medido no dev, 100 conversas devolvidas para quem devia ver 7.
  describe 'pelo ConversationFinder, que e o caminho do index' do
    def pelo_finder(pessoa)
      ConversationFinder.new(pessoa, { status: 'all' }).perform
    end

    it 'restringe a lista, e nao so o service' do
      WorkspaceMember.create!(user: ana, workspace: ws, conversation_visibility: 'apenas_minhas')

      expect(pelo_finder(ana.reload)[:conversations].pluck(:id)).to eq([minha.id])
    end

    it 'restringe tambem os contadores, para a tela nao mostrar um numero que a lista nao entrega' do
      WorkspaceMember.create!(user: ana, workspace: ws, conversation_visibility: 'apenas_minhas')

      contagens = pelo_finder(ana.reload)[:count]
      expect(contagens[:all_count]).to eq(1)
      expect(contagens[:unassigned_count]).to eq(0)
    end

    it 'fila: conta o sem dono junto com as minhas' do
      WorkspaceMember.create!(user: ana, workspace: ws, conversation_visibility: 'fila')

      contagens = pelo_finder(ana.reload)[:count]
      expect(contagens[:all_count]).to eq(2)
    end
  end
end

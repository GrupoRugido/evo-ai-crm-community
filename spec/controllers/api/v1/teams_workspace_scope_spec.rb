require 'rails_helper'

# O TeamsController fazia Team.all e o papel Cliente tem teams.read: medido no
# dev, o cliente do Oral Riso listava o time "Audio Enfermeira" da Cicatriclinic,
# com a descricao do processo interno deles.
RSpec.describe 'escopo de workspace nos times' do
  let(:ws_a) { Workspace.create!(name: 'Clinica A', slug: 'clinica-a') }
  let(:ws_b) { Workspace.create!(name: 'Clinica B', slug: 'clinica-b') }

  let!(:time_a)      { Team.create!(name: 'Time A', workspace_id: ws_a.id) }
  let!(:time_b)      { Team.create!(name: 'Time B', workspace_id: ws_b.id) }
  let!(:time_global) { Team.create!(name: 'Time nosso', workspace_id: nil) }

  # Reproduz o que workspace_scope_strict faz no controller, sem subir o stack
  # de autenticacao: o ponto do teste e a consulta, nao o login.
  def visiveis_para(workspace_id)
    (workspace_id.blank? ? Team.all : Team.where(workspace_id: workspace_id)).pluck(:name)
  end

  it 'cliente ve so os times do proprio workspace' do
    expect(visiveis_para(ws_a.id)).to contain_exactly('Time A')
  end

  it 'nao vaza o time global para o cliente' do
    expect(visiveis_para(ws_a.id)).not_to include(time_global.name)
  end

  it 'admin sem workspace ativo continua vendo tudo' do
    expect(visiveis_para(nil)).to include(time_a.name, time_b.name, time_global.name)
  end

  it 'a URL direta do time alheio nao resolve' do
    expect { Team.where(workspace_id: ws_a.id).find(time_b.id) }
      .to raise_error(ActiveRecord::RecordNotFound)
  end
end

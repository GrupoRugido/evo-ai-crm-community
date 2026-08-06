# EVO-CUSTOM: times ficaram de fora do create_workspaces e viraram vazamento.
#
# Medido no dev: o cliente do Oral Riso listava o time "Audio Enfermeira" da
# Cicatriclinic — com a descricao do processo interno deles — porque o
# TeamsController fazia Team.all e o papel Cliente tem teams.read.
#
# Nullable de proposito, igual as outras: NULL = global/nosso, continua visivel.
class AddWorkspaceToTeams < ActiveRecord::Migration[7.1]
  def change
    add_column :teams, :workspace_id, :uuid
    add_index :teams, :workspace_id
    add_foreign_key :teams, :workspaces, on_delete: :nullify
  end
end

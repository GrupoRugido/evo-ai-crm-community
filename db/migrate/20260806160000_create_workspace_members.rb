# EVO-CUSTOM: o vinculo pessoa<->cliente vira tabela propria.
#
# Ate aqui a associacao era a coluna users.workspace_id: uma pessoa, um cliente.
# Isso cobria a clinica (o atendente dela atende ela e mais ninguem), mas nao
# cobre o gerente de contas nosso, que cuida de tres clinicas e nao de todas.
# E, mais importante, nao tinha onde guardar o PAPEL e a VISIBILIDADE por
# cliente — a mesma pessoa pode precisar ser gestora num e atendente noutro.
#
# E a forma que o Chatwoot usa (account_users) e a que a literatura de
# multi-tenant recomenda: papel escopado ao tenant numa tabela de vinculo.
#
# O down reconstroi users.workspace_id a partir dos vinculos, entao a migration
# e reversivel de verdade — quem tiver mais de um vinculo perde os extras na
# volta, que e o unico jeito de caber numa coluna so.
class CreateWorkspaceMembers < ActiveRecord::Migration[7.1]
  def up
    create_table :workspace_members, id: :uuid do |t|
      t.references :user,      type: :uuid, null: false, foreign_key: true, index: false
      t.references :workspace, type: :uuid, null: false, foreign_key: true

      # Papel DENTRO deste cliente (roles.key do auth-service): gestor,
      # atendente, cliente. Nulo = herda o papel global da pessoa.
      t.string :role_key

      # Quanto da fila a pessoa enxerga:
      #   todas          — tudo do cliente
      #   fila           — sem dono + as minhas
      #   apenas_minhas  — so as atribuidas a mim
      t.string :conversation_visibility, null: false, default: 'todas'

      t.timestamps
    end

    add_index :workspace_members, [:user_id, :workspace_id], unique: true,
                                  name: 'index_workspace_members_unicidade'

    execute <<~SQL.squish
      INSERT INTO workspace_members (id, user_id, workspace_id, conversation_visibility, created_at, updated_at)
      SELECT gen_random_uuid(), u.id, u.workspace_id, 'todas', now(), now()
      FROM users u
      WHERE u.workspace_id IS NOT NULL
    SQL

    remove_column :users, :workspace_id
  end

  def down
    add_column :users, :workspace_id, :uuid
    add_index  :users, :workspace_id

    # Um vinculo por pessoa: o mais antigo vence, para o resultado nao depender
    # da ordem em que o banco devolveu as linhas.
    execute <<~SQL.squish
      UPDATE users u SET workspace_id = wm.workspace_id
      FROM (
        SELECT DISTINCT ON (user_id) user_id, workspace_id
        FROM workspace_members ORDER BY user_id, created_at ASC
      ) wm
      WHERE wm.user_id = u.id
    SQL

    drop_table :workspace_members
  end
end

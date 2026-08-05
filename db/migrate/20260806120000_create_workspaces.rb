# EVO-CUSTOM: workspaces — separacao por cliente dentro da mesma instalacao.
#
# Nao e multi-tenancy no sentido forte (sem billing, sem provisionamento, sem
# super-admin novo): e uma foreign key + disciplina de escopo. O objetivo e
# organizacao e separacao operacional entre clientes que as vezes sao
# concorrentes, com nossos usuarios admin transitando entre eles.
#
# workspace_id e NULLABLE de proposito: NULL = global/nosso, que mantem tudo o
# que ja existe funcionando enquanto o retrofit nao roda.
#
# Versao PAR (20260806120000): o upstream reserva versoes pares para o CRM e
# impares para o auth-service (ver migration-version-parity.yml). Respeitar
# isso evita colisao com migrations futuras deles.
class CreateWorkspaces < ActiveRecord::Migration[7.1]
  # Tabelas que ganham dono. Conversas, mensagens e sessoes de agente NAO
  # entram: herdam o workspace pela caixa de entrada via join, entao carregar
  # coluna nelas seria redundante e caro de manter em sincronia.
  SCOPED_TABLES = %i[
    inboxes
    contacts
    automation_rules
    agent_bots
    labels
    canned_responses
    pipelines
    users
  ].freeze

  def change
    create_table :workspaces, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :logo_url
      t.jsonb :settings, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :workspaces, :slug, unique: true

    SCOPED_TABLES.each do |table|
      next unless table_exists?(table)

      add_reference table, :workspace, type: :uuid, null: true, index: true, foreign_key: { to_table: :workspaces }
    end

    # Dedup de contato passa a ser POR WORKSPACE: o mesmo telefone falando com
    # duas clinicas vira dois registros independentes (nome, etiquetas e notas
    # separados) — requisito de clientes concorrentes.
    # Indice parcial: so vale para contatos ja atribuidos a um workspace, entao
    # os contatos globais (NULL) que existem hoje nao sao afetados.
    return unless table_exists?(:contacts)

    add_index :contacts, %i[workspace_id phone_number],
              unique: true,
              where: "workspace_id IS NOT NULL AND phone_number IS NOT NULL AND phone_number <> ''",
              name: 'index_contacts_on_workspace_and_phone'
  end
end

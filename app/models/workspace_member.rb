# frozen_string_literal: true

# EVO-CUSTOM: vinculo entre uma pessoa e um cliente (workspace).
#
# Guarda o papel e a visibilidade POR cliente, e nao no usuario, porque a mesma
# pessoa pode ter alcances diferentes em clientes diferentes — o gerente de
# contas que e gestor numa clinica e so atendente noutra.
class WorkspaceMember < ApplicationRecord
  # Papel dentro do cliente. Nulo herda o papel global da pessoa, que e o caso
  # do super admin: ele nao precisa de vinculo para enxergar tudo.
  PAPEIS = %w[gestor atendente cliente].freeze

  # Ordem importa: e usada para decidir quem manda quando alguem tem mais de um
  # vinculo (o mais amplo vence na hora de montar o menu).
  VISIBILIDADES = %w[todas fila apenas_minhas].freeze

  belongs_to :user
  belongs_to :workspace

  validates :user_id, uniqueness: { scope: :workspace_id, message: 'ja e membro deste cliente' }
  validates :role_key, inclusion: { in: PAPEIS }, allow_blank: true
  validates :conversation_visibility, inclusion: { in: VISIBILIDADES }

  scope :gestores, -> { where(role_key: 'gestor') }

  def gestor?
    role_key == 'gestor'
  end
end

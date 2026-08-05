# EVO-CUSTOM: um cliente nosso dentro da instalacao.
#
# Agrupa caixas de entrada, contatos, automacoes, agentes, etiquetas, respostas
# rapidas, pipelines e usuarios. Nossos usuarios admin nao pertencem a workspace
# nenhum (workspace_id NULL) e transitam entre todos.
class Workspace < ApplicationRecord
  has_many :inboxes, dependent: :nullify
  has_many :contacts, dependent: :nullify
  has_many :automation_rules, dependent: :nullify
  has_many :agent_bots, dependent: :nullify
  has_many :labels, dependent: :nullify
  has_many :canned_responses, dependent: :nullify
  has_many :pipelines, dependent: :nullify
  has_many :users, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: 'aceita apenas minusculas, numeros e hifen' }

  scope :active, -> { where(active: true) }

  before_validation :derive_slug, on: :create

  private

  def derive_slug
    return if slug.present?

    self.slug = name.to_s.parameterize
  end
end

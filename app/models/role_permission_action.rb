# frozen_string_literal: true

# EVO-CUSTOM: referencia somente-leitura para a tabela role_permissions_actions,
# populada e gerida pelo evo-auth-service (mesmo banco Postgres). O CRM nunca
# escreve aqui — o modelo existe para User#has_permission? consultar as
# permissoes reais em vez do stub `true` que existia antes.
#
# Mesmo padrao do modelo Role logo ao lado ("Evolution Reference Model").
class RolePermissionAction < ApplicationRecord
  self.table_name = 'role_permissions_actions'

  belongs_to :role
end

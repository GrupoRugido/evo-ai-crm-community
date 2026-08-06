require 'rails_helper'

# Guarda de regressao: existem DUAS listas independentes de condicoes permitidas.
#
#   1. AutomationRule#conditions_attributes  -> valida no save (json_conditions_format)
#   2. lib/filters/filter_keys.yml           -> alimenta o ConditionValidationService,
#                                               o FilterService e o seletor do frontend
#
# Uma chave que exista so no YAML aparece na tela e faz a regra estourar
# "Automation conditions <chave> not supported." na hora de salvar — foi
# exatamente o que aconteceu com sender_type.
RSpec.describe AutomationRule do
  let(:yaml_keys) do
    YAML.safe_load(File.read(Rails.root.join('lib/filters/filter_keys.yml')))
        .values_at('conversations', 'contacts', 'messages')
        .compact.flat_map(&:keys)
  end

  let(:model_keys) { described_class.new.send(:conditions_attributes) }

  it 'aceita no model toda condicao que o filter_keys.yml oferece' do
    faltando = yaml_keys - model_keys
    expect(faltando).to be_empty,
                        "chaves no filter_keys.yml e ausentes em conditions_attributes: #{faltando.join(', ')}. " \
                        'Regras que as usarem vao aparecer na tela e falhar ao salvar.'
  end

  it 'salva uma regra com a condicao sender_type' do
    rule = described_class.new(
      name: 'guarda sender_type',
      event_name: 'message_created',
      conditions: [{ 'attribute_key' => 'sender_type', 'filter_operator' => 'equal_to',
                     'values' => ['user'], 'query_operator' => nil }],
      actions: [{ 'action_name' => 'change_status', 'action_params' => ['open'] }]
    )

    expect(rule).to be_valid, rule.errors.full_messages.join('; ')
  end
end

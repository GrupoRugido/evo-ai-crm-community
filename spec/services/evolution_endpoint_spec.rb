require 'rails_helper'

# A Evolution da instalacao e uma so para todos os canais. Quem cria canal
# informa o numero, nao a infraestrutura.
#
# A precedencia ENV > banco existe por causa do corte: o banco e restaurado do
# dump de producao, e o que estivesse so em installation_configs voltaria ao
# valor antigo. O compose passa incolume.
RSpec.describe EvolutionEndpoint do
  before { GlobalConfig.clear_cache }
  after  { GlobalConfig.clear_cache }

  describe '.api_url' do
    it 'usa o ENV quando ele existe' do
      GlobalConfig.set('EVOLUTION_API_URL', 'https://do-banco.exemplo')

      with_env('EVOLUTION_API_URL' => 'https://do-ambiente.exemplo') do
        expect(described_class.api_url).to eq('https://do-ambiente.exemplo')
      end
    end

    it 'cai para o banco quando o ENV esta ausente' do
      GlobalConfig.set('EVOLUTION_API_URL', 'https://do-banco.exemplo')

      with_env('EVOLUTION_API_URL' => nil) do
        expect(described_class.api_url).to eq('https://do-banco.exemplo')
      end
    end

    it 'trata ENV vazio como ausente' do
      GlobalConfig.set('EVOLUTION_API_URL', 'https://do-banco.exemplo')

      with_env('EVOLUTION_API_URL' => '   ') do
        expect(described_class.api_url).to eq('https://do-banco.exemplo')
      end
    end

    it 'devolve nil quando nao ha nem um nem outro' do
      GlobalConfig.set('EVOLUTION_API_URL', '')

      with_env('EVOLUTION_API_URL' => nil) do
        expect(described_class.api_url).to be_nil
      end
    end
  end

  describe '.configured?' do
    it 'exige url e chave' do
      with_env('EVOLUTION_API_URL' => 'https://evo.exemplo', 'EVOLUTION_ADMIN_SECRET' => nil) do
        GlobalConfig.set('EVOLUTION_ADMIN_SECRET', '')
        expect(described_class).not_to be_configured
      end
    end

    it 'fica verdadeiro com os dois presentes' do
      with_env('EVOLUTION_API_URL' => 'https://evo.exemplo', 'EVOLUTION_ADMIN_SECRET' => 'chave') do
        expect(described_class).to be_configured
      end
    end
  end

  # IntegrationRequirements alimenta o hasEvolutionConfig que a tela de canal usa
  # para esconder os campos de infraestrutura — precisa enxergar o ENV tambem.
  describe 'IntegrationRequirements' do
    it 'reconhece a Evolution configurada pelo ambiente' do
      GlobalConfig.set('EVOLUTION_API_URL', '')
      GlobalConfig.set('EVOLUTION_ADMIN_SECRET', '')

      with_env('EVOLUTION_API_URL' => 'https://evo.exemplo', 'EVOLUTION_ADMIN_SECRET' => 'chave') do
        expect(IntegrationRequirements.configured?('evolution')).to be(true)
      end
    end
  end

  def with_env(vars)
    originais = vars.keys.index_with { |k| ENV.fetch(k, nil) }
    vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    GlobalConfig.clear_cache
    yield
  ensure
    originais.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    GlobalConfig.clear_cache
  end
end

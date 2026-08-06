# EvoCRM — fork do Grupo Rugido

Fork de `evolution-foundation/evo-crm-community`. Existe porque precisávamos de coisas que o
upstream não tem e que não fazem sentido como PR: separação por cliente numa instalação só,
intervenção humana no atendimento com IA, e uma Evolution única para toda a instalação.

Este arquivo é para outro Claude Code assumir o trabalho sem ter estado nas conversas anteriores.
O que está aqui é o que **não dá para deduzir lendo o código**.

---

## Regras de trabalho

**Comentários e commits em português.** Todo o código nosso segue isso; não misture.

**Marque o que é nosso com `EVO-CUSTOM`.** É como se distingue nossa alteração de código do
upstream num arquivo compartilhado — e é o que permite reaplicar depois de um merge do upstream.
Para achar tudo que tocamos: `grep -rl "EVO-CUSTOM" app/ lib/ db/`.

**Comentário explica o porquê, não o quê.** Vários dos nossos comentários registram um bug medido
("medido no dev: o cliente do Oral Riso via o time da Cicatriclinic"). Mantenha esse padrão — é o
que impede alguém de "simplificar" a correção de volta para o bug.

**Verifique contra o ambiente, não contra o código.** Boa parte dos erros desta base só aparece
rodando: duas listas de validação que divergem, um enum invertido, um campo com outro nome.
Antes de afirmar que algo funciona, execute.

---

## Branches e build

| Branch | Papel |
|---|---|
| `desenvolvimento` | Integração. **Push aqui dispara o build da imagem** (`.github/workflows/rugido-publish.yml`) |
| `producao` | O que está em produção |
| `feat/*` | Trabalho em andamento; merge em `desenvolvimento` quando pronto |

A imagem sai em `ghcr.io/gruporugido/evo-ai-crm-community:sha-<sha-curto>`. O frontend tem o mesmo
arranjo em `evo-ai-frontend-community`.

Deploy é manual, por `docker service update` — nada é automático:

```bash
docker service update --with-registry-auth \
  --image ghcr.io/gruporugido/evo-ai-crm-community:sha-XXXXXXX evo_crm_evocrm_crm
```

Sempre os **dois** serviços: `evocrm_crm` e `evocrm_crm_sidekiq`. Esquecer o sidekiq deixa o worker
rodando código velho, e o sintoma é uma automação que se comporta de um jeito na tela e de outro em
segundo plano.

---

## Ambientes

| | Servidor | CRM | API |
|---|---|---|---|
| Produção | 5.161.69.99 | `evocrm.gruporugido.com` | `evocrm-api.gruporugido.com` |
| Desenvolvimento | 179.198.104.129 | `evocrm-dev.rugido.com` | `evocrm-api-dev.rugido.com` |

Docker Swarm nos dois, stack `evo_crm`. O servidor novo também tem `evo_wa` (Evolution) e um
`evo_prod` que **não é nosso** — não mexa nele.

**O ambiente de dev está desarmado de propósito.** Os canais de WhatsApp apontam para
`evolution-desarmada.invalid` e os agentes para `lucasfelix-desarmado.invalid`. Se você precisar
armar algo para testar, desarme de novo depois. Uma mensagem que escape do dev vai para o WhatsApp
real de um paciente.

Senhas de servidor e a chave da Evolution **não estão neste repositório** de propósito — a chave da
Evolution é a chave mestra de todas as instâncias de WhatsApp das clínicas. Peça ao time; ou leia de
`installation_configs` (produção) e do ENV do serviço (dev).

---

## O modelo de domínio que adicionamos

### Workspaces = clientes

Cada clínica é um `workspace`. Pertencem a um workspace (coluna `workspace_id`, nullable):
`inboxes`, `contacts`, `automation_rules`, `agent_bots`, `labels`, `canned_responses`, `pipelines`,
`teams`.

**`workspace_id` nulo significa "global/nosso"** — visível para todos. Isso é retrocompatibilidade
deliberada: a instalação de cliente único continua funcionando sem nenhum workspace.

### Pessoas: `workspace_members`

Uma pessoa pode atender mais de um cliente. O vínculo carrega:

- `role_key` — papel dentro daquele cliente
- `conversation_visibility` — `todas`, `fila` ou `apenas_minhas`

Gestor do workspace alcança todas as caixas do cliente; membro comum só as caixas de que participa
(`User#inboxes_do_workspace`).

### Como o workspace ativo é resolvido

`WorkspaceScopeConcern`, em `Api::V1::BaseController`:

1. **Tem vínculo** → é dentro dos clientes dele, sempre. Um vínculo: esse. Vários: o header
   `X-Workspace-Id` escolhe, desde que aponte para um dos dele.
2. **Admin sem vínculo** → o header escolhe; sem header, vê a instalação inteira.

Três helpers, e a diferença importa:

- `workspace_scope(rel)` — do workspace **ou global**. Para etiqueta e resposta rápida, que têm
  itens nossos compartilhados.
- `workspace_scope_strict(rel)` — só do workspace. Para funil, time, automação.
- `workspace_id_for_create(corpo)` — o workspace que um registro **novo** recebe.

**Ao criar um controller novo que lista algo por cliente, escope o `index` E o `fetch_*`.** Esconder
da lista não basta: já aconteceu duas vezes de a URL direta abrir o registro do vizinho (funis e
times). O teste é sempre `GET /recurso/<id-de-outro-cliente>` → precisa dar 404.

---

## Armadilhas — todas custaram uma sessão de depuração

**Duas listas de condições de automação.** `lib/filters/filter_keys.yml` alimenta a tela e o
casamento; `AutomationRule#conditions_attributes` valida no save. Chave só no YAML = aparece na tela
e a regra estoura `not supported` ao salvar. Guarda: `spec/models/automation_rule_allowlist_spec.rb`.

**`sender_type` só aceita minúsculo** — `user` (atendente humano) e `agentbot`. A consulta envolve a
coluna em `LOWER()`, mas o `FilterService` só rebaixa o valor quando a chave é `content`. Com
maiúscula a regra salva, fica ativa e nunca casa.

**`AgentBotInbox` tem o enum invertido em relação à intuição:** `active: 0`, `inactive: 1`. Criar
com `status: 1` deixa o agente ligado e mudo.

**`move_to_stage` espera `new_stage_id`**, não `pipeline_stage_id`. Nome errado devolve
`404 Stage not found in this pipeline`, que manda você procurar o problema na etapa.

**`InboxesController#create` lê os parâmetros da raiz**, não de dentro de `inbox`.
`{"name": …, "channel": {…}}` funciona; `{"inbox": {…}}` falha sem mensagem útil.

**`/public/api/v1` responde `204` com corpo vazio** ao criar contato, conversa e mensagem. É
sucesso. Mande o `source_id` que você mesmo escolheu e não tente extrair id da resposta.

**`AccessToken` não gera o próprio token.** `before_create :generate_token` roda depois da validação
`validates :token, presence: true`. Passe `token:` e `name:` explicitamente.

**O canal guarda a própria `api_url` e ela vence a global.** Ao mudar a Evolution da instalação, os
canais existentes não mudam de servidor — o que é o comportamento certo, mas surpreende.

---

## Evolution

Uma só para a instalação: quem cria canal informa **nome e número**, não infraestrutura.

`EvolutionEndpoint` resolve na ordem **`provider_config` do canal → ENV → `installation_configs`**.
ENV antes do banco porque a migração restaura o dump de produção — o que estivesse só no banco
voltaria ao valor antigo.

`IntegrationRequirements.configured?('evolution')` vira o `hasEvolutionConfig` que o frontend usa
para esconder os campos de URL e chave. A tela já tinha essa lógica; o que faltava era a
configuração existir.

Na tela: **"Testar Conexão" é obrigatório** — é ele que habilita o "Criar Canal", que nasce
desabilitado. E o campo de telefone assume `+1` se o número vier sem código de país, o que deixa o
formulário inválido sem dizer por quê.

---

## Testes

```bash
bundle exec rspec spec/models/automation_rule_allowlist_spec.rb   # as duas allowlists
bundle exec rspec spec/models/agent_bot_inbox_workspace_spec.rb   # agente x caixa de outro cliente
bundle exec rspec spec/services/evolution_endpoint_spec.rb        # precedencia ENV > banco
bundle exec rspec spec/controllers/api/v1/teams_workspace_scope_spec.rb
```

Há uma suíte de QA por navegador em `/root/evo-crm/qa` (Playwright, fora deste repositório). Ela
navega **clicando**, nunca indo direto na URL — foi assim que apareceram os vazamentos entre
clientes, que um teste de API não pegaria. Prints em `qa/screenshots/`, achados em
`qa/RESULTADOS.md` e `qa/ANALISE-AGENTES.md`.

`docs/api-evocrm.html` é a referência pública da API, escrita para agentes de IA que operam o CRM
por chave. Se você mudar rota, parâmetro aceito ou regra de workspace, atualize junto — uma
referência desatualizada é pior que nenhuma, porque o agente confia nela e erra em silêncio.

---

## O que está pendente

**A migração para o servidor novo não foi concluída.** Falta a Fase 5 (corte): congelar a produção,
dumps frescos, restore, DNS. O runbook está em `/root/evo-crm/MIGRACAO.md`, fora deste repositório,
com dois passos que se esquecidos quebram o corte:

- trocar o ENV `EVOLUTION_API_URL` do servidor novo para o domínio de produção depois do restore
  (ENV vence o banco);
- remover a instância de teste `manso-maromba` da Evolution nova — o dump de sessões só pode ser
  restaurado com a Evolution vazia.

**Regra de ouro da migração:** duas Evolutions ligadas no mesmo banco de sessões derrubam as
conexões de WhatsApp das clínicas. A velha para **antes** do restore.

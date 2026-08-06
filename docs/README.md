# Documentação da API

`api-evocrm.html` é a página pública de referência da API, escrita para quem opera o CRM por
script — inclusive agentes de IA (Claude Code, Codex) com a chave de API.

Publicada em: https://claude.ai/code/artifact/7314519c-4e1f-427a-9314-c52da14963cc

## Por que ela existe

Não havia documentação nenhuma. A tarefa `lib/tasks/swagger.rake` é resíduo do upstream — a pasta
`swagger/` nunca existiu no fork —, e a tela "Documentação" do frontend é maquete estática.
Enquanto isso, o WhatsApp oficial só se conecta por API, porque a interface exige o SDK de um
aplicativo Tech Provider.

## O que ela promete

Todo exemplo foi executado contra o ambiente de desenvolvimento antes de ser escrito. Quando a
página cita uma resposta, é a resposta que voltou de verdade — não a que o código sugere que
voltaria. Isso importa porque o leitor principal é um agente de IA, que não tem como desconfiar
de uma documentação plausível e errada.

## Como atualizar

O índice de endpoints (`endpoints.json`) sai do app em execução, não do `routes.rb` — o arquivo
tem `resources` duplicados, e o que vale é o que o Rails resolveu:

```bash
docker exec $CRM bundle exec rails routes > rotas.txt
# parsear verbo/caminho/controller#action, deduplicar por (verbo, caminho), agrupar por familia
```

Depois de editar o HTML, republique com a mesma URL para não gerar link novo.

## Se você mudar a API

Mexeu em rota, em parâmetro aceito ou em regra de workspace? A página precisa acompanhar na mesma
mudança. Uma referência desatualizada é pior que nenhuma: o agente confia nela e erra em silêncio.

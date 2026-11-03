---
name: schematize-payments
metadata:
  version: 0.2.1
description: >-
  Pagamentos BR: PIX, boleto, cartão sem tocar PAN, ledger em centavos, webhooks idempotentes, conciliação. Use ao integrar PSP ou cobrança. Nunca cobra fora de prd. Gate check-pay.sh.
---
<!-- cross-skill: efeitos-externos.md, iam.md -> schematize-engineering -->

# Pagamentos no Brasil (schematize-payments)

Disciplina normativa para **integrar, operar e auditar pagamento**: PIX, boleto, cartão, assinatura
recorrente, split, conciliação e documento fiscal. A tese: **pagamento é uma máquina de estados com
dinheiro irreversível dentro**. Quem guarda valor em `float`, confia no redirect do navegador como
prova de "pago", processa o mesmo webhook duas vezes ou deixa a chave de produção a um `.env` de
distância do ambiente de teste está a uma execução do incidente financeiro.

**Versão:** skill `schematize-payments` v0.2.1. Changelog em `CHANGELOG.md`.

## Precedência e herança (leia antes de divergir)

<!-- herdado:engineering/precedencia:dominio intro="Esta skill é o recorte **pagamentos (PIX, boleto, cartão, ledger, conciliação, fiscal)** de um **domínio de negócio**: independe de linguagem e vale em qualquer serviço do rol (`schematize-engineering` → `references/linguagens.md`), escolhido por fit + ADR." cmd="pay" -->Esta skill é o recorte **pagamentos (PIX, boleto, cartão, ledger, conciliação, fiscal)** de um **domínio de negócio**: independe de linguagem e vale em qualquer serviço do rol (`schematize-engineering` → `references/linguagens.md`), escolhido por fit + ADR.

1. **Onde esta skill divergir da base, a BASE MANDA.** Aqui mora a especialização do domínio ou da
   ferramenta — o como, o padrão, o gate. Divergência de *piso* é defeito desta skill, não variante local.
2. **O que não está repetido aqui é HERDADO, não dispensado.** Esta skill herda os pisos da base e
   os comandos dela cobrem o **domínio**, não o piso geral. Valem integralmente, sem cópia local:
   - **§28 Archive** — `<projeto>/<projeto>_archive/` é **repositório git próprio, PRIVADO e
     obrigatório**, criticidade 0 (`schematize-archive`).
   - **§35 Definition of Done** e a lista de anti-padrões (citada por **título**, nunca por número).
   - **§39 Índice/MAPA** — enumeração exaustiva (uma entrada por unidade chamável, `M == N`) e grafo
     com arestas em ASCII (`A -> B`), nunca a seta unicode.
   - **IAM** (`schematize-engineering` → `references/iam.md`): identidade ≠ email, ≥2 fatores, ReBAC
     multi-tenant, argon2id-only para senha nova, sessão longa e logout irreversível.
   - **Efeito externo** nunca sai de não-produção (`schematize-engineering` →
     `references/efeitos-externos.md`).
   - **Orquestração** (`schematize-engineering` → `references/orquestracao.md` §9): o principal não
     desenvolve (é Claude Opus); executor mais barato que resolve — `haiku`/`sonnet` → Codex Terra → Cursor → `opus` só após falha; visual direto ao Codex; imagem nunca pelo Claude: detecta Codex/Gemini e pergunta ao usuário qual usar (Codex é a sugestão, não automática), nunca API paga.
3. **QA, ops, IAM e índice não têm comando próprio aqui:** vêm da base `/eng-*`. Para trabalho
   contínuo use `/eng-overdev`; para planejar `/eng-plan`; para varrer a base `/eng-scan`; para
   revisão geral `/eng-review` (e `/eng-ops`, `/eng-iam`, `/eng-index`). Os comandos
   `/pay-*` cobrem o domínio desta skill; o piso geral é o da base.<!-- /herdado -->

## Fronteira com as outras skills

| Assunto | Dono | Ponteiro |
|---|---|---|
| **Pagamento**: PIX, boleto, cartão, ledger em centavos, estados, webhook de PSP, idempotência de cobrança, split, conciliação, fiscal, não cobrar fora de prd | **esta skill** | `references/*.md` abaixo |
| Webhook **genérico** (contrato, assinatura HMAC, retry, replay window), idempotency-key como padrão de API, erros RFC 9457 | `schematize-api` | aqui só o que muda quando o evento move dinheiro |
| Conciliação como **pipeline** (contrato do arquivo do PSP, quarentena, lineage, backfill) | `schematize-data` | aqui o que casar e o que é exceção; lá o pipeline |
| Identidade, step-up em pagamento, ReBAC multi-tenant, 2º fator | `schematize-iam` e `schematize-engineering → references/iam.md` | aqui só **onde** exigir step-up |
| Desenho de schema (tabelas do ledger, constraints, índices, migrations) | `schematize-database` | aqui o modelo conceitual do ledger |
| Termos, privacidade, devolução ao consumidor, LGPD, retenção de evidência | `schematize-institutional` | aqui só o gatilho técnico |
| Teste (pirâmide, flaky, gate); teste nunca dispara efeito real | `schematize-qa` | aqui o que provar em sandbox |
| Ataque a fluxo de pagamento (race de saldo, replay, forja de webhook) | `schematize-pentest` | lado ofensivo; aqui o construtivo |
| Transação, lock e isolamento no banco do ledger; backup/PITR do dado financeiro | `schematize-postgres` | `schematize-postgres → references/locks-e-migrations.md`, `backup-e-pitr.md`; aqui o invariante do ledger |
| Cobrança duplicada, vazamento de dado de cartão/cliente, PSP fora do ar: resposta | `schematize-incident` | declarar SEV, mitigar; aqui o que conferir no ledger |
| Evento de funil de checkout (conversão) | `schematize-analytics` | tracking plan sem PAN nem PII; aqui só o dado financeiro |
| Segredo do PSP commitado | `schematize-git` | `/git-leak`; `schematize-git → references/segredos.md` |
| Segredo e cofre, rede, mTLS no ingress | `schematize-infra` | aqui o que exigir do PSP |
| Alerta/SLO de taxa de falha, chargeback e atraso de webhook | `schematize-observability` | aqui o que medir |
| Efeito externo fora de prd (base) | `schematize-engineering → references/efeitos-externos.md` | herdado, piso 18 da engineering |

## Comandos (Claude Code)

| Comando | O que faz |
|---|---|
| `/pay-help` | lista os comandos |
| `/pay-load` | carrega à força o corpo normativo (estado e ledger, PIX, cartão e PCI, boleto e recorrência, webhooks, split e fiscal, não cobrar fora de prd) |
| `/pay-review` | revisa o código de pagamento: roda o gate e lê o que a máquina não lê |
| `/pay-flow` | desenha o fluxo de um meio de pagamento: estados, transições, lançamentos do ledger, idempotência |
| `/pay-webhook` | cria ou audita o receptor de webhook do PSP (autenticidade, dedupe, ordem, reconsulta) |
| `/pay-sandbox` | prova que nada cobra fora de prd: ambiente fail-closed, chaves, dublê, dado sintético |
| `/pay-reconcile` | desenha ou audita a conciliação diária ledger x PSP x banco |
| `/pay-claude` | cria/mescla o `CLAUDE.md` sempre-on de pagamentos na raiz do repo |
| `/pay-cc` · `/pay-handoff` | context compact / handoff arquivado |

## Como usar

1. **Rode os gates antes de discutir estilo:** `bash scripts/check-pay.sh .` e `bash scripts/check-pay-effects.sh .`
   (piso 18 da engineering: gateway real com guard fail-closed, sandbox/sink default, cap `PAY_MAX_*`) — `0` passa · `1`
   reprova · `2` **nada para verificar** (que não é aprovação). Estático e sem dependência de
   linguagem ou SDK; waiver rastreável `pay-ok: <motivo>` (não vale para chave live nem PAN). Gate por commit é LOCAL; CI remoto só antes do hml/tag (piso 27).
2. **Modele antes de integrar** (`references/estado-e-ledger.md`): dinheiro inteiro, estados,
   ledger. A integração com o PSP é uma camada fina por cima.
3. **Escolha o meio** (`references/pix.md`, `cartao-pci.md`, `boleto-recorrencia.md`) e o PSP por
   ADR (sandbox decente, split nativo, webhook assinado, suporte ao meio).
4. **Webhook e idempotência** (`references/webhooks-idempotencia.md`) antes do primeiro pagamento real.
5. **Conciliação e fiscal** (`references/split-conciliacao-fiscal.md`) fazem parte do "pronto",
   não do "depois".
6. **Prove o piso 1 DESTA skill (na base é o piso 18)** (`references/nao-cobrar-fora-de-prd.md`) antes de ligar qualquer credencial.

Mapa de references:

| Tarefa | Reference |
|---|---|
| Dinheiro inteiro, arredondamento, estados, ledger de dupla entrada, transação e outbox | `references/estado-e-ledger.md` |
| Cobrança imediata e com vencimento, QR dinâmico, `txid`, `endToEndId`, devolução, MED, webhook Pix | `references/pix.md` |
| Nunca tocar PAN, SAQ A, PCI DSS v4.0.1, 3-D Secure, autorização x captura, chargeback | `references/cartao-pci.md` |
| Boleto registrado e híbrido, assinatura, dunning, Pix Automático | `references/boleto-recorrencia.md` |
| Receber webhook, chamar o PSP com idempotência, retry, outbox, o que testar | `references/webhooks-idempotencia.md` |
| Split, conciliação, estorno/devolução/reembolso, NF-e/NFS-e via provedor | `references/split-conciliacao-fiscal.md` |
| Ambiente fail-closed, chaves, sandbox, dado sintético, cap, dry-run, exceção de 5 condições | `references/nao-cobrar-fora-de-prd.md` |
| Normas do BCB, PCI, fiscal: valores, datas e fontes (anexo volátil) | `references/stack-versoes.md` |

Assets: `assets/CLAUDE.md` (sempre-on) · `assets/commands/`.

## Pisos inegociáveis (vetam o atalho)

1. **Nunca cobrar fora de prd.** Cobrança, transferência, estorno, repasse e emissão fiscal são
   efeito externo irreversível: fora de produção só sandbox do PSP e homologação fiscal, por
   construção. Ambiente ausente ou desconhecido ⇒ não-prd; só o valor exato de produção cobra de
   verdade; chave de produção existe só em prd. <!-- herdado:engineering/efeito-externo:invariantes -->**Cap por execução** (`MAIL_MAX_PER_RUN`, default 50) com abort; **fail-closed** (ambiente ausente/desconhecido ⇒ não-prd; só o valor exato de produção entrega de verdade); **chave sandbox** fora de prd. Todo endereço sintético (fixture, seed, persona, demo, carga) é `<papel>+<run-id>-<n>@test.<domain>` — domínio em **rota nula** (null MX RFC 7505 + SPF `-all` + DMARC `p=reject`) ou TLD reservado (`.test`/`.invalid`/`.example`); **VETADO** `@gmail.com`, domínio de cliente/terceiro, e-mail de pessoa real (**inclusive o seu**) e o domínio de produção. A recusa é **erro**, nunca warning nem sucesso silencioso. Entregar de verdade fora de prd exige **as cinco** (ADR + allowlist ≤5 + cap + janela + subdomínio separado). Motivo: bounce/complaint em massa **queima IP e domínio** e derruba o transacional de prd — inclusive o **OTP de login** — com semanas de warm-up e utilidade zero (o incidente dos 5.000 e-mails só existiu porque nada contava).<!-- /herdado -->
2. **Dinheiro é inteiro na menor unidade (centavos) + moeda.** Nunca `float`/`double`/`REAL`;
   percentual em pontos-base; soma das partes (split, parcelas) é igual ao total, com resto
   determinístico.
3. **Nunca tocar PAN.** Captura pelo PSP (página ou campos hospedados), seu sistema vê token, bandeira
   e últimos 4 dígitos. CVV nunca se armazena. PAN em log, coluna ou repositório é incidente.
   Meta: SAQ A.
4. **Estado de pagamento é máquina de estados explícita**, transição como função pura testada em
   tabela, estado terminal não volta, evento desconhecido nunca vira "pago".
5. **Pago só por canal autenticado do PSP.** O redirect do navegador é UX, não prova. Valor e moeda
   confirmados contra o que foi cobrado; divergência vai para exceção humana.
6. **Webhook do PSP é autenticado antes de tudo** (HMAC sobre o corpo bruto em tempo constante, ou
   mTLS) **e deduplicado** por id do evento; fora de ordem e repetido são normais; antes de efeito
   irreversível, reconsulta a API do PSP.
7. **Toda criação de cobrança, transferência ou estorno leva chave de idempotência** persistida antes
   da chamada (`Idempotency-Key`, `txid` no PIX, `id` da devolução). Timeout não é falha: consulta
   ou repete com a mesma chave.
8. **Ledger de dupla entrada, imutável e append-only.** Débito = crédito por transação e moeda;
   correção é lançamento inverso; saldo é derivado; estado + lançamento + evento na mesma
   transação, efeito externo por outbox depois do commit.
9. **Estorno, devolução e chargeback são fluxos de primeira classe**: soma dos estornos ≤ valor
   capturado; chargeback reserva no ledger e guarda evidência desde o dia 0.
10. **Conciliação diária e idempotente** entre ledger, PSP e extrato bancário, com exceções que têm
    dono e prazo; divergência de saldo é incidente, não ajuste.
11. **Documento fiscal por provedor, disparado por evento idempotente**; falha de emissão é estado
    com fila, nunca perde o recebimento. Regra tributária é decisão humana (contador).
12. **Step-up e autorização granular** em ação financeira sensível (repasse manual, troca de conta
    de recebimento, estorno acima de limite): fator forte e papel por tenant (`schematize-iam`;
    `schematize-engineering → references/iam.md`). Sessão comum não move dinheiro.
13. **Segredo de PSP em cofre, por ambiente, rotacionável**; chave exposta ⇒ rotacionar primeiro.
    Dado pessoal (CPF, chave PIX, e-mail) mascarado em log e tela (LGPD).
14. <!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para o executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código; falhou → mesmo subagent corrige, até 2 rodadas) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo) → `park`; **visual vai direto ao Codex**; **imagem nunca pelo Claude: detectar Codex/Gemini e perguntar ao usuário qual usar (Codex é a sugestão), nunca API de imagem paga**; papéis em `agentes.toml`. No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

## Regra de mídia

Esta skill não gera visual. Se o trabalho tocar tela de checkout, diagrama ou imagem, a mídia gerada
**nunca** vem de modelo Claude: detecte Codex e Gemini disponíveis e **pergunte ao usuário qual
usar**. Nenhum disponível: avise sem rodeio que visual gerado pelo Claude tem qualidade
inversamente proporcional à de código (sai ruim de verdade) e ofereça alternativas — instalar Codex
ou Gemini, imagem de banco com licença comercial, ou asset do cliente. Diagrama de fluxo vai em
Mermaid ou texto no repo (`schematize-docs`).

## Relação com as outras skills

- **`schematize-engineering`** — a base: DoD, archive, IAM, efeito externo, fluxo de ambientes.
- **`schematize-api`** — o contrato do webhook e da idempotência como padrão de API.
- **`schematize-data`** — a conciliação como pipeline.
- **`schematize-database`** — schema do ledger, constraints e migrations.
- **`schematize-iam`** — step-up e autorização de ações financeiras.
- **`schematize-institutional`** — LGPD, termos, devolução ao consumidor, retenção.
- **`schematize-qa`** · **`schematize-pentest`** — prova por teste e por ataque.
- **`schematize-observability`** — SLO de pagamento, alerta de chargeback e de webhook parado.

<!-- herdado:engineering/pisos-22-29:bloco -->**Herda os pisos 22–29 da `schematize-engineering`** (texto completo em `assets/CLAUDE.md` dela): 22 tudo no git — sem remote, push falho ou HEAD≠origin a demanda NÃO se conclui; 23 deploy só do git (VETADO scp/rsync/tar|ssh/docker save|load/git bundle); 24 o ops é o gate da IA — a IA nunca muda a VPS direto nem escreve SQL, só operação nomeada (`ssh vps "ops <op>"`); 25 sem agents inúteis (entregou, morreu); 26 relatório a cada 30 min e handoff a cada 6 h; 27 CI remoto só antes do hml, a pedido ou em tag (`workflow_dispatch` + `hml-*`/`v*`; VETADO `pull_request`, `push` em branch, `workflow_run`, cron sem justificativa); 28 microserviço autônomo (fila durável + 7 testes de resiliência); 29 build/teste na máquina dev/hml quando existe (ponte só no workspace de build, nunca prd) + higiene (`scripts/higiene.sh`).<!-- /herdado -->

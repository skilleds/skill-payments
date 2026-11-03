# Piso de pagamentos (schematize-payments) — sempre-on

Pagamento move dinheiro irreversível. O estado é uma máquina; o ledger é a verdade; o PSP é a fonte de prova.

1. **NUNCA cobrar fora de prd.** Fora de produção só sandbox do PSP e homologação fiscal. Ambiente ausente ou desconhecido ⇒ não-prd (fail-closed); só o valor exato de produção cobra; chave de produção só em prd. <!-- herdado:engineering/efeito-externo:invariantes -->**Cap por execução** (`MAIL_MAX_PER_RUN`, default 50) com abort; **fail-closed** (ambiente ausente/desconhecido ⇒ não-prd; só o valor exato de produção entrega de verdade); **chave sandbox** fora de prd. Todo endereço sintético (fixture, seed, persona, demo, carga) é `<papel>+<run-id>-<n>@test.<domain>` — domínio em **rota nula** (null MX RFC 7505 + SPF `-all` + DMARC `p=reject`) ou TLD reservado (`.test`/`.invalid`/`.example`); **VETADO** `@gmail.com`, domínio de cliente/terceiro, e-mail de pessoa real (**inclusive o seu**) e o domínio de produção. A recusa é **erro**, nunca warning nem sucesso silencioso. Entregar de verdade fora de prd exige **as cinco** (ADR + allowlist ≤5 + cap + janela + subdomínio separado). Motivo: bounce/complaint em massa **queima IP e domínio** e derruba o transacional de prd — inclusive o **OTP de login** — com semanas de warm-up e utilidade zero (o incidente dos 5.000 e-mails só existiu porque nada contava).<!-- /herdado -->
2. **Dinheiro é inteiro em centavos + moeda.** Nunca `float`/`double`/`REAL`. Percentual em pontos-base. Soma das partes = total.
3. **Nunca tocar PAN.** Captura pelo PSP (campos ou página hospedados); seu código vê token, bandeira, últimos 4. CVV nunca armazenado. PAN em log/coluna/repo é incidente.
4. **Máquina de estados explícita**; estado terminal não volta; evento desconhecido nunca vira "pago". Redirect do navegador não prova pagamento.
5. **Webhook do PSP:** autentica antes de tudo (HMAC no corpo bruto em tempo constante, ou mTLS), deduplica por id do evento, aceita fora de ordem, reconsulta o PSP antes de efeito irreversível.
6. **Toda cobrança/transferência/estorno leva chave de idempotência** persistida antes da chamada (`Idempotency-Key`, `txid` no PIX, `id` da devolução). Timeout não é falha.
7. **Ledger de dupla entrada, imutável.** Débito = crédito; correção é lançamento inverso; estado + lançamento + evento na mesma transação; efeito externo por outbox.
8. **Estorno/chargeback** de primeira classe (soma dos estornos ≤ capturado); **conciliação diária** idempotente com exceções que têm dono.
9. **Fiscal por provedor**, evento idempotente, regra tributária é decisão humana.
10. **Step-up** em ação financeira sensível; segredo de PSP em cofre por ambiente; dado pessoal mascarado.
11. <!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para o executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código; falhou → mesmo subagent corrige, até 2 rodadas) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo) → `park`; **visual vai direto ao Codex**; **imagem nunca pelo Claude: detectar Codex/Gemini e perguntar ao usuário qual usar (Codex é a sugestão), nunca API de imagem paga**; papéis em `agentes.toml`. No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

Mídia: imagem/visual gerado nunca por modelo Claude; detecte Codex/Gemini e pergunte qual usar.

Gates: `bash .claude/skills/schematize-payments/scripts/check-pay.sh .` e `.../check-external-effects.sh .` (piso 18: nunca cobra fora de prd) — waiver rastreável
`# pay-ok: <motivo>`.

Herda os pisos 22–29 da `schematize-engineering` (git como trava de conclusão, deploy só do git, ops é o gate da IA, sem agents inúteis, relatório 30 min/handoff 6 h, CI remoto só antes do hml, microserviço autônomo, build em dev/hml + higiene).

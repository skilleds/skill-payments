# Changelog — schematize-payments

Todas as mudanças relevantes deste pacote, no formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
com versionamento [SemVer](https://semver.org/lang/pt-BR/).

## [0.3.0] — 2026-11-03
### Adicionado
- `scripts/check-pay-effects.sh` (+ teste vermelho→verde): gate do piso 18, "nunca cobra fora de prd" (gateway real sem guard fail-closed/sandbox default, cobrança sem cap `PAY_MAX_*`, guard por lista negra, default prd, script de reprocesso sem dry-run, credencial/host de prd e chave não-sandbox em env não-prd).
- Piso 28 (resiliência), piso 20 (matriz da rota de webhook), pisos 23/24 (operação em prd é do ops); bloco herdado 22–29.
### Alterado
- Gate do piso 18 renomeado `check-external-effects.sh` -> `check-pay-effects.sh` (+ `.test.sh`): o nome antigo é da cópia canônica herdada da engineering (restaurada por `sync-herdados`). `check-pay.sh` agora CHAMA `check-pay-effects.sh`: rodar o gate principal já cobre o efeito externo (rc 2 do auxiliar não reprova).
### Corrigido
- Citação "piso 1" para efeito externo ⇒ piso 18 da engineering.
- `check-pay.sh`: comentário não satisfaz assinatura/dedupe/idempotência; literal decimal de dinheiro (`price := 19.90`) é acusado; waiver não vale para `pay-chave-live`/`pay-pan-literal`; `HOSTS_PRD` ampliado (Cielo, Rede, Vindi, Adyen live).
- README sem `/tmp` fixo; CI sandbox só por dispatch/tag (piso 27).
- [~] Hosts novos de PSP não conferidos em fonte oficial nesta onda (Stripe, Pagar.me e Iugu usam o mesmo host em teste/live, distinguidos só pela chave); e `stack-versoes.md` ainda sem fonte primária BCB/PCI; Open Finance/DICT por escrever.
- `check-pay-effects.sh`: `trap ... EXIT` remove o temporário do loop mesmo com Ctrl-C.
## [0.2.1] — 2026-10-14
Ponteiro para a skill nova `schematize-bots` (piso curto, sem duplicar).

### Alterado
- ponteiro para cobrança dentro do bot.

## [0.2.0] — 2026-10-14
Integração ao catálogo: orçamento de description e ponteiros entre as irmãs novas.

### Alterado
- `description` <=190 (orçamento do catálogo).
- Divisas: `schematize-postgres` (locks, PITR do ledger), `schematize-incident` (cobrança duplicada, vazamento), `schematize-analytics` (funil sem PAN/PII), `schematize-git` (`/git-leak` para segredo de PSP).
- Motivo: o catálogo estourou o orçamento de listagem com 45 skills; cada fronteira aponta a dona em vez de duplicar.

## [0.1.0] — 2026-10-14
Primeira versão. Pagamento move dinheiro irreversível (PIX não estorna por botão, nota emitida tem efeito
tributário, cartão cobrado gera contestação) e a base só tinha "cobrança é efeito externo" em uma linha.
Faltava a especialista: dinheiro em float, chave de produção em ambiente de teste, webhook sem assinatura,
cobrança sem idempotência e PAN em log são defeitos que viram incidente financeiro e não tinham dono nem gate.

### Adicionado
- `SKILL.md` com 14 pisos, o primeiro absoluto: **nunca cobrar fora de prd** (herda efeito externo da base), fronteira com `schematize-api`, `schematize-data`, `schematize-iam`/base de IAM, `schematize-database`, `schematize-institutional`, `schematize-qa` e `schematize-pentest`.
- `references/`: `estado-e-ledger` (inteiro em centavos, máquina de estados, ledger de dupla entrada), `pix`, `cartao-pci` (nunca tocar PAN, SAQ A, chargeback), `boleto-recorrencia` (boleto, assinatura, dunning, Pix Automático), `webhooks-idempotencia`, `split-conciliacao-fiscal` (split, conciliação, estorno, NF-e/NFS-e via provedor), `nao-cobrar-fora-de-prd` e `stack-versoes` (anexo volátil com fonte e data).
- `scripts/check-pay.sh` + `check-pay.test.sh`: 10 regras estáticas (float em dinheiro, chave live no repo, host/credencial de produção em arquivo não-prd, ambiente com default prd, webhook sem assinatura e sem deduplicação, cobrança sem idempotência, PAN em log, PAN literal por Luhn, PAN/CVV persistido), waiver rastreável `pay-ok:`, casos vermelhos e verdes plantados.
- Comandos: `pay-help`, `pay-load`, `pay-review`, `pay-flow`, `pay-webhook`, `pay-sandbox`, `pay-reconcile`, `pay-claude`, `pay-handoff`, `pay-cc`.

### Não verificado
- Texto primário das normas do BCB, API de qualquer PSP real, sandbox de PSP e emissão fiscal contra provedor (ver `references/stack-versoes.md`, seção "Faltou verificar").

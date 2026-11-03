---
description: Mapa da skill schematize-payments (pagamentos BR — PIX, boleto, cartão, ledger, conciliação; nunca cobrar fora de prd).
---
**schematize-payments** — pagamento é máquina de estados com dinheiro irreversível dentro. Piso 1: nunca cobrar fora de prd.

| Comando | O que faz |
|---|---|
| `/pay-help` | esta lista |
| `/pay-load` | carrega à força TODO o corpo normativo (estado e ledger, PIX, cartão e PCI, boleto e recorrência, webhooks, split e fiscal, não cobrar fora de prd) e passa a aplicá-lo |
| `/pay-review` | revisa o código de pagamento: roda `scripts/check-pay.sh` e lê o que a máquina não lê |
| `/pay-flow` | desenha o fluxo de um meio de pagamento: estados, lançamentos no ledger, idempotência |
| `/pay-webhook` | cria ou audita o receptor de webhook do PSP |
| `/pay-sandbox` | prova que nada cobra fora de prd |
| `/pay-reconcile` | desenha ou audita a conciliação diária |
| `/pay-claude` | cria ou mescla o `CLAUDE.md` sempre-on de pagamentos na raiz do repo |
| `/pay-cc` · `/pay-handoff` | context compact / handoff no archive |

Pareia com: `schematize-api` (webhook e idempotência como contrato), `schematize-data` (conciliação como
pipeline), `schematize-iam` (step-up), `schematize-database` (schema do ledger), `schematize-institutional`
(LGPD e devolução), `schematize-qa` e `schematize-pentest` (prova).

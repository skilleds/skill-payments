---
description: schematize-payments — prova que nada cobra fora de prd (ambiente fail-closed, chaves, dublê, dado sintético)
argument-hint: "[diretório do repo]"
---

# /pay-sandbox — cobrar é ato deliberado, não acidente

Piso 1 da skill. Execute e **mostre a saída**; não declare "seguro" sem prova.

1. **Gates:** `bash .claude/skills/schematize-payments/scripts/check-pay-effects.sh "${ARGUMENTS:-.}"` (piso 18: `pay-gateway-sem-guarda`, `pay-cobranca-sem-cap`, `pay-chave-nao-sandbox`) e `.../check-pay.sh "${ARGUMENTS:-.}"` —
   atenção a `pay-chave-live`, `pay-prd-em-nao-prd` e `pay-default-prd`. Configure
   `PAY_PROD_HOSTS` com os hosts de produção do PSP em uso.
2. **Fail-closed:** localize onde o ambiente é lido. Ausente, vazio, `dev`, `hml`, `prod`,
   `PRODUCTION ` (com espaço) ⇒ gateway sandbox; **só `production`** ⇒ gateway real. Exija teste
   de unidade disso.
3. **Um gateway, duas implementações:** o resto do código não escolhe. O construtor do real recusa
   subir fora de prd.
4. **Credenciais:** a chave de produção do PSP não aparece em segredo de hml/CI (liste os
   segredos por ambiente; `schematize-infra`). Chave exposta ⇒ rotacionar primeiro.
5. **Testes:** nenhum teste chama o PSP real; CI usa dublê; job de sandbox tem credencial sandbox e roda só em `workflow_dispatch` ou tag de promoção (`hml-*`/`v*`), nunca por commit/PR (piso 27); o gate por commit é local.
6. **Webhook e fiscal:** webhook de hml aponta para sandbox; emissão fiscal em homologação.
7. **Dado sintético:** cliente, e-mail (`<papel>+<run-id>-<n>@test.<domínio>` em rota nula), CPF/CNPJ
   de teste; nenhuma pessoa real, **inclusive o desenvolvedor**.
8. **Cap e dry-run:** job que cobra tem teto de valor e quantidade com abort; script operacional é
   dry-run por padrão.
9. **Exceção** (cobrar de verdade fora de prd): só com ADR, allowlist de até 5 contas, cap, janela e
   credencial separada; é item `[H ]`, nunca decisão do agente.

Feche listando o que foi provado por execução e o que ficou como `[H ]`.

---
description: schematize-payments — revisa código de pagamento contra o piso: roda o gate e lê o que a máquina não lê
argument-hint: "[diretório do repo]"
---

# /pay-review — pagamento é código de produção com dinheiro dentro

## 1. A máquina primeiro

```bash
bash .claude/skills/schematize-payments/scripts/check-pay.sh "${ARGUMENTS:-.}"
```
`0` passa · `1` reprova · `2` **nada para verificar** — que não é aprovação.

O gate cobre: dinheiro em float, chave live no repo, host/credencial de produção em arquivo de
ambiente não-prd, ambiente com default prd, webhook sem autenticidade e sem deduplicação, criação de
cobrança sem idempotência, PAN em log, PAN literal e PAN/CVV persistido. Waiver: `pay-ok: <motivo>`
(linha ou linha de cima); regras de arquivo inteiro nomeiam a regra: `pay-ok: <regra> <motivo>`.
Vermelho do próprio gate: `bash scripts/check-pay.test.sh`.

## 2. Depois, o que a máquina não lê

- **Estados:** há enum com transições testadas em tabela? Estado terminal volta? Evento desconhecido
  vira "pago"? O redirect do navegador libera produto?
- **Ledger:** débito = crédito garantido no banco? lançamento é imutável (UPDATE/DELETE revogado)?
  saldo é derivado? estado + lançamento + evento na mesma transação?
- **Webhook:** HMAC sobre o corpo **bruto** em tempo constante, ou mTLS? janela contra replay?
  reconsulta ao PSP antes de efeito irreversível? dois segredos na rotação?
- **Idempotência:** chave persistida **antes** da chamada? retry reaproveita a chave? timeout consulta?
- **Valor:** valor/moeda pagos conferidos contra o cobrado? split fecha no centavo?
- **Cartão:** o PAN chega ao seu backend por algum caminho (formulário próprio, proxy, log de
  requisição, APM)? a página que hospeda o iframe tem inventário de scripts e CSP?
- **Ambiente:** `APP_ENV` ausente cai em prd? há como instanciar o gateway real fora de prd?
  teste chama PSP real?
- **Estorno/chargeback:** soma dos estornos ≤ capturado? evidência guardada? prazo com dono?
- **Conciliação:** roda todo dia? idempotente? exceções têm dono e prazo?
- **Fiscal:** emissão por evento idempotente? homologação fora de prd?
- **Dado pessoal:** CPF, chave PIX e e-mail mascarados em log e tela?

## 3. Feche

Achado vira correção no mesmo PR ou item de checklist com dono. Conformidade PCI e regra tributária
são **revisão humana** (`[H ]`): registre quem e quando.

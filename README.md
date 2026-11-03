# schematize-payments — pagamentos no Brasil

> **Pagamento é uma máquina de estados com dinheiro irreversível dentro.** PIX, boleto, cartão sem
> tocar PAN, assinatura, split, ledger de dupla entrada em centavos, webhooks idempotentes,
> conciliação, documento fiscal por provedor — e o piso absoluto: **nunca cobrar fora de prd**.

Pacote de **skill normativa para [Claude Code](https://claude.com/claude-code)**.
Parte do catálogo **schematize skills**.

## Por que ela existe

A base trata cobrança como efeito externo em uma linha. Faltava a especialista: dinheiro em
`float`, chave de produção num `.env` de teste, webhook sem assinatura forjando "pago", cobrança
repetida por retry sem idempotência, PAN em log, saldo que não fecha. Tudo isso já foi incidente
financeiro em algum lugar e não tinha dono nem gate.

## Instalar

### Pelo app schematize (recomendado)

```bash
schematize install payments    # requer o CLI schematize instalado
```

### Manual

```bash
T="$(mktemp -d)"   # nunca /tmp fixo
git clone https://github.com/schematizeme/skill-payments.git "$T/skill-payments"
bash "$T/skill-payments/install.sh" .        # instala em .claude/ do projeto atual
```

## O que tem dentro

- **SKILL.md** — o contrato: 14 pisos inegociáveis, as fronteiras com `schematize-api`,
  `schematize-data`, `schematize-iam`, `schematize-database` e demais, e o mapa de references.
- **references/** — `estado-e-ledger`, `pix`, `cartao-pci`, `boleto-recorrencia`,
  `webhooks-idempotencia`, `split-conciliacao-fiscal`, `nao-cobrar-fora-de-prd` e `stack-versoes`
  (anexo volátil com fonte, data e o que não foi verificado).
- **scripts/** — `check-pay-effects.sh` (piso 18: nunca cobra fora de prd) e `check-pay.sh`, o gate estático (10 regras, sem depender de linguagem ou SDK de PSP;
  waiver rastreável `pay-ok:`), e `check-pay.test.sh` (casos vermelhos e verdes plantados).
- **assets/** — `commands/` e `CLAUDE.md` sempre-on.

## Comandos

| Comando | O que faz |
|---|---|
| `/pay-help` | lista os comandos |
| `/pay-load` | carrega à força o corpo normativo |
| `/pay-review` | revisa o código de pagamento: gate + leitura humana |
| `/pay-flow` | desenha estados, lançamentos e idempotência de um meio |
| `/pay-webhook` | cria ou audita o receptor de webhook do PSP |
| `/pay-sandbox` | prova que nada cobra fora de prd |
| `/pay-reconcile` | desenha ou audita a conciliação diária |
| `/pay-claude` | `CLAUDE.md` sempre-on de pagamentos |
| `/pay-cc` · `/pay-handoff` | context compact / handoff |

## Verificação

```bash
bash scripts/check-pay.test.sh        # vermelho primeiro do gate
bash scripts/check-pay.sh <repo>      # o gate no seu repo
```

## Aviso

Não é aconselhamento jurídico, fiscal nem de conformidade PCI: enquadramento (SAQ), regra tributária
e revisão final são humanos. Normas e prazos mudam; veja `references/stack-versoes.md`.

## Licença

MIT. Ver `LICENSE` (inclui avisos de marcas de terceiros).

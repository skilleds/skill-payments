---
description: schematize-payments — desenha ou audita a conciliação diária entre ledger, PSP e extrato bancário
argument-hint: "[meio de pagamento ou diretório]"
---

# /pay-reconcile — o saldo que não fecha é incidente

Alvo: `${ARGUMENTS:-.}`. Leia `references/split-conciliacao-fiscal.md` §2.

1. **Fontes:** ledger, relatório/API de liquidação do PSP e extrato bancário. Liste o formato e a
   periodicidade de cada uma.
2. **Chave de casamento por meio:** `endToEndId` (PIX), id da transação (cartão), nosso número
   (boleto). Valor+data só como último recurso, marcado como exceção.
3. **Classes de resultado:** `casado`, `so_no_ledger`, `so_no_psp`, `valor_diferente`, `duplicado`,
   `fora_de_periodo`, cada uma com dono e prazo.
4. **Idempotência:** rodar o mesmo dia duas vezes não duplica nada; o fechamento do mês congela o
   período e correções entram no mês corrente referenciando o original.
5. **Taxas e líquido:** `taxa_psp` como lançamento próprio; bruto x líquido conciliados.
6. **Fuso:** normalize para UTC registrando o fuso de origem.
7. **Pipeline:** contrato do arquivo do PSP, quarentena do que não parseia, lineage até o lançamento
   (`schematize-data`).
8a. **Correção em prd (pisos 23/24):** lançamento corretivo, reprocesso e backfill em prd são OPERAÇÕES NOMEADAS do ops (dry-run, confirmação humana, auditoria append-only); a IA só as implementa no repo do ops, nunca grava lançamento nem roda SQL/script ad hoc em prd.
8. **Alerta:** saldo de exceções acima do limite, ou dia sem conciliar, abre incidente
   (`schematize-observability`).
9. **Entregue** o desenho (ou os achados da auditoria) e o teste de propriedade: reprocessar N vezes
   o mesmo dia produz o mesmo resultado.

---
description: schematize-payments — desenha o fluxo de um meio de pagamento (estados, lançamentos, idempotência) antes de integrar
argument-hint: "<pix | boleto | cartao | assinatura | split>"
---

# /pay-flow — modele antes de integrar

Meio alvo: `${ARGUMENTS}`. **Este comando desenha; não chama PSP.** Saída: um documento Mermaid + tabelas
em `<projeto>/docs/` (ou no archive), pronto para ADR.

1. **Leia** `references/estado-e-ledger.md` e a reference do meio (`pix.md`, `cartao-pci.md` ou
   `boleto-recorrencia.md`).
2. **Estados:** desenhe o diagrama `stateDiagram-v2` com todas as transições, os eventos que as
   disparam (do PSP, do cliente, do tempo) e o estado terminal de cada caminho. Liste o que
   acontece com evento fora de ordem e com estado desconhecido.
3. **Ledger:** para cada transição que move dinheiro, escreva o lançamento (conta debitada, conta
   creditada, valor em centavos, moeda, chave de idempotência = id do evento de origem).
4. **Idempotência:** chave de cada chamada de saída (`Idempotency-Key`, `txid`, `id` da devolução) e
   de cada evento de entrada (`event_id`, `endToEndId`).
5. **Falhas:** timeout, recusa, expiração, pagamento duplicado, a maior, a menor, estorno parcial,
   chargeback; o que o cliente vê e o que o operador faz.
6. **Ambientes:** como o fluxo roda em sandbox (`references/nao-cobrar-fora-de-prd.md`).
7. **Decisões abertas** viram ADR (`schematize-docs`): PSP, regra de arredondamento, quem arca com
   taxa de estorno. Pontos fiscais e de conformidade viram item `[H ]`.
8. **Entregue** o diagrama, as tabelas e a lista de testes de propriedade (soma das parcelas,
   evento repetido N vezes, ordem embaralhada).

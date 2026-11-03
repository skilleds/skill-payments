---
description: schematize-payments — cria ou audita o receptor de webhook do PSP (autenticidade, dedupe, ordem, reconsulta)
argument-hint: "<psp ou caminho do handler>"
---

# /pay-webhook — o webhook é gatilho; a prova é a consulta

Alvo: `${ARGUMENTS}`. Leia `references/webhooks-idempotencia.md` e, para PIX, `references/pix.md` §3.

**Criar** (na linguagem do projeto, escolhida por fit + ADR):

1. **Autentique primeiro:** HMAC sobre o corpo **bruto** comparado em tempo constante e janela
   contra replay, ou mTLS validado no proxy. Falha = `401`/`403`, métrica e alerta. Dois segredos
   aceitos durante a rotação.
2. **Persista o evento bruto** em `eventos_psp` (id único = `event_id`/`endToEndId`),
   `INSERT ... ON CONFLICT DO NOTHING`; já visto = `200` sem refazer o efeito.
3. **Responda `2xx` rápido** e processe em worker (outbox).
4. **Reconsulte o PSP** pelo id antes de efeito irreversível; compare valor e moeda com o cobrado.
5. **Aplique a transição** pela máquina de estados (rejeita transição inválida) e grave o
   lançamento na **mesma transação**.
6. **Testes** (contra dublê, nunca PSP real): evento repetido N vezes ⇒ efeito 1 vez; ordem
   embaralhada ⇒ mesmo estado; corpo alterado/assinatura inválida/replay ⇒ rejeitado.

7. **Matriz de acesso (piso 20)**: a rota `/webhooks/<psp>` entra na matriz (schematize-qa): anônimo sem assinatura ⇒ `401` sem corpo útil; assinatura de outro ambiente ⇒ `401`; método trocado, path alternativo e rota debug ⇒ negados; M == N com o inventário de rotas.

**Auditar:** rode `bash .claude/skills/schematize-payments/scripts/check-pay.sh .`
(`pay-webhook-sem-assinatura`, `pay-webhook-sem-dedupe`) e confira os seis pontos acima no handler.
Contrato genérico de webhook (versionamento, retry de saída): `schematize-api`.

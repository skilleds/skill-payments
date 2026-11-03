# Webhooks de PSP e idempotência

> Parte da skill **schematize-payments**. O contrato genérico de webhook (assinatura, retry,
> replay window, versionamento) é da `schematize-api`; aqui, o que muda quando o evento move
> dinheiro.

## 1. Receber webhook do PSP (o seu endpoint)

1. **Autentique antes de qualquer outra coisa.** Conforme o PSP: **HMAC** sobre o **corpo bruto**
   (não o JSON reparseado) comparado em **tempo constante**, janela de tempo contra replay,
   segredo por ambiente; ou **mTLS** (certificado do cliente validado no proxy). Sem autenticação =
   qualquer um forja "pago". Falha = `401`/`403`, sem corpo útil, métrica e alerta.
2. **Deduplique por id do evento** (`event_id`/`notification_id`/`endToEndId`): tabela
   `eventos_psp(id unico, recebido_em, payload, processado_em)` com `INSERT ... ON CONFLICT DO
   NOTHING`; já visto = `200` sem refazer o efeito.
3. **Responda `2xx` rápido** (grave o evento e enfileire); processe em worker. PSP que não recebe
   `2xx` reenvia: o desenho já é idempotente.
4. **Não confie na ordem.** Eventos chegam fora de ordem e repetidos. A máquina de estados
   (`estado-e-ledger.md`) rejeita transição inválida; para estado final **reconsulte a API do PSP**
   (fonte de verdade) em vez de acreditar no payload do webhook.
5. **Reconsulta antes de efeito irreversível** (liberar produto, creditar saldo, enviar nota): o
   webhook é gatilho, a consulta autenticada é prova.
6. **Payload do webhook é entrada não confiável:** valide o schema; nunca use valor do payload
   (valor, moeda) sem comparar com o que você cobrou.
7. **Segredo/certificado rotacionável** sem downtime (aceite dois segredos durante a janela).
8. **Log sem dado sensível** (nome, documento, chave PIX mascarados; nada de PAN — não deveria
   chegar, mas payload bruto vai para armazenamento com acesso restrito e retenção definida).

O gate acusa handler de webhook sem verificação de autenticidade (`pay-webhook-sem-assinatura`) e
sem deduplicação (`pay-webhook-sem-dedupe`).

## 2. Chamar o PSP (idempotência de saída)

- **Toda criação de cobrança/transferência/estorno leva chave de idempotência** gerada por você e
  **persistida antes da chamada**: `Idempotency-Key` quando o PSP suporta; `txid` (PIX `cob`) e `id`
  da devolução quando o padrão os define como chave.
- **Timeout não é falha.** Após timeout, **consulte** pelo id (ou repita com a mesma chave); nunca
  gere outra chave achando que a primeira morreu.
- **Retry** com backoff exponencial + jitter e teto de tentativas; só em erro retentável
  (rede, `5xx`, `429`); `4xx` de negócio (saldo, recusa) não se retenta.
- **Reuso de chave com payload diferente** é bug seu: o PSP rejeita; trate como erro, não troque a chave.
- Chave por **intenção** (`pedido_id + tentativa` quando o cliente tenta de novo de propósito),
  não por requisição HTTP.
- O gate acusa chamada de criação sem chave/txid (`pay-cobranca-sem-idempotencia`).

## 3. Outbox e consistência

Estado + lançamento + evento recebido na **mesma transação**; chamada a PSP, e-mail de recibo e
emissão de nota saem por **outbox** depois do commit, com a mesma disciplina de idempotência.

## 3.1 Resiliência (piso 28 da engineering)
Webhook perdido = cliente pago sem acesso (ou o inverso). Persista o evento (inbox durável, NUNCA memória)
**antes** de responder 2xx (ack só depois do commit). PSP indisponível ⇒ a cobrança vai para a outbox com
retry (backoff+jitter) e o checkout/serviço segue vivo; mensagem envenenada ⇒ DLQ após N tentativas.
Matriz mínima: (1) boot com PSP fora; (2) timeout/5xx ⇒ outbox, serviço saudável; (3) reinício com fila
cheia ⇒ drena sem perda nem duplicata; (4) reentrega idempotente; (5) envenenada ⇒ DLQ; (6) shutdown
gracioso sem perda; (7) crash entre persistir e confirmar ⇒ sem perda. Gate da base: `check-resilience.sh`.

## 4. Testar

- Teste de propriedade: processar o mesmo evento N vezes ⇒ efeito 1 vez.
- Teste de ordem: eventos embaralhados terminam no mesmo estado.
- Teste de forja: corpo alterado/assinatura inválida/replay fora da janela ⇒ rejeitado.
- Teste de timeout: resposta perdida + retry com a mesma chave ⇒ uma cobrança.
- Tudo contra **sandbox do PSP** ou dublê; teste nunca dispara cobrança real (`schematize-qa`;
  `references/nao-cobrar-fora-de-prd.md`).

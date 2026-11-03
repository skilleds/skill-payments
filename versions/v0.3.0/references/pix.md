# PIX

> Parte da skill **schematize-payments**. Regra do Banco Central muda: o que é número, data e
> versão de manual mora em `references/stack-versoes.md` (com fonte e data). Aqui, o desenho.

## 1. Modelo mental

O PIX é liquidação instantânea e **irrevogável** entre contas. Você, como recebedor, quase nunca
fala com o BCB: fala com o **PSP** (banco/instituição de pagamento) pela API Pix padronizada, que
expõe cobrança, consulta, devolução e webhook. **Dinheiro recebido por PIX não "estorna" por
botão:** a volta é uma **devolução** (nova transferência) ou, em fraude, o fluxo do MED.

## 2. Cobrança

| Tipo | Quando | Ponto de atenção |
|---|---|---|
| **Cobrança imediata** (`cob`) | checkout, pagamento agora | expiração curta (segundos/minutos), QR dinâmico, `txid` seu |
| **Cobrança com vencimento** (`cobv`) | fatura, mensalidade avulsa | datas de vencimento, multa/juros/desconto na cobrança, validade após o vencimento |
| **QR estático** | doação, balcão | sem valor/identificador único: concilia mal; evite para venda com pedido |
| **Pix Automático** | recorrência autorizada pelo pagador | ver `references/boleto-recorrencia.md` |

Regras da casa:

1. **QR dinâmico sempre que houver pedido.** Um QR por cobrança, com `txid` único gerado por você
   (alfanumérico, tamanho dentro do limite do padrão), gravado **antes** de chamar o PSP.
2. **`txid` é a chave de idempotência da cobrança.** `PUT /cob/{txid}` repetido com o mesmo payload
   é seguro; com payload diferente é erro (trate, não gere outro txid em silêncio).
3. **Expiração explícita** e coerente com o pedido; cobrança expirada vira estado `expirado`, e o
   QR antigo **não** pode ser pago (o PSP recusa; seu sistema não "perdoa").
4. **Valor da cobrança manda.** Compare valor pago × valor cobrado na confirmação; divergência vai
   para exceção humana, não para "pago".
5. **Identificador ponta a ponta (`endToEndId`, `E...`)** é a chave da transação PIX: guarde-o no
   pagamento e no lançamento do ledger; é o que a conciliação e a devolução usam.
6. **Chave PIX** (DICT) é dado pessoal: não registre em log, mascare na tela, nunca use como
   identidade (`schematize-iam`/`schematize-engineering → references/iam.md`: identidade ≠ e-mail/CPF).
7. **Não confie no polling para o estado final.** Webhook confirma; consulta (`GET /cob/{txid}`)
   reconcilia (`references/webhooks-idempotencia.md`).

## 3. Webhook do PSP

- O PSP chama uma URL sua quando o PIX é recebido. O padrão exige **TLS mútuo (mTLS)** no
  cadastro do webhook em vários PSPs: valide o certificado do cliente no proxy/ingress, **e** valide
  um segredo/HMAC ou token na URL quando o PSP oferecer (defesa em camadas). O que o PSP não
  assina, **reconsulte** antes de creditar.
- Resposta `2xx` rápida; processamento assíncrono; **idempotente por `endToEndId`**.
- Reenvio do PSP é normal: já processado = `200` sem refazer.
- Detalhe de assinatura, ordem, replay e reconsulta: `references/webhooks-idempotencia.md`.
  Webhook genérico (contrato, retry): `schematize-api`.

## 4. Devolução

- Via API (`PUT /pix/{e2eid}/devolucao/{id}`): o `id` da devolução é **sua chave de idempotência**.
- Parcial ou total, dentro do prazo e das regras do regulamento <!-- reverificar prazo e valor máximo da devolução -->.
- No ledger: lançamento inverso referenciando o recebimento; a devolução tem estado próprio
  (`em_processamento -> devolvido | nao_realizado`), e o saldo só muda no estado final.
- Devolução **nunca** para conta diferente da origem sem fluxo de exceção aprovado (anti-fraude).
- Devolução maior que o recebido: bloqueie no domínio (soma das devoluções ≤ valor recebido).

## 5. Fraude, MED e limites

- O **MED** (Mecanismo Especial de Devolução) permite contestar PIX por fraude/falha operacional;
  versão 2.0 em vigor em 2026 <!-- reverificar detalhes e normas citadas -->. Para o recebedor: pode
  chegar uma solicitação de bloqueio/devolução sobre um recebimento; tenha fila e prazo de resposta,
  e estado `em_disputa` no pagamento.
- Limites noturnos e por transação existem no pagador; não trate recusa por limite como erro do
  seu sistema (mensagem clara ao cliente).
- Conta de recebimento: nunca use a mesma conta para recebimento de clientes e despesa da empresa
  (conciliação); a conta transitória do PSP é a que concilia com o ledger.

## 6. Ambientes

PSP bom tem **sandbox**: use-o fora de prd, com credenciais e certificados **separados** de prd
(`references/nao-cobrar-fora-de-prd.md`). PIX de verdade fora de prd é dinheiro real saindo da
conta de alguém. O gate `check-pay.sh` pega host/credencial de produção em arquivo não-prd.

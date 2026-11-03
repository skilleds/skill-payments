# Dinheiro, estados e ledger

> Parte da skill **schematize-payments**. Pagamento é um sistema de estados com dinheiro dentro:
> o erro mais barato de evitar é o de representação (float) e o mais caro é o de contabilidade
> (saldo que não fecha).

## 1. Dinheiro é inteiro

- **Valor monetário = inteiro na menor unidade da moeda** (centavos de BRL) + **código da moeda**
  (ISO 4217) sempre junto. Tipo `Money { cents: i64, currency }`; nunca `float`/`double`/`f64`, nunca
  `number` do JavaScript para somar (use inteiro seguro ou `BigInt`), nunca `REAL`/`double precision`
  no banco. `NUMERIC(p,s)` no SQL é aceitável para valor, mas o código que o lê converte para inteiro
  na borda.
- **Conversão para reais só na apresentação.** Parse de entrada do usuário (`"10,50"`) vira centavos
  na borda, com rejeição de casa decimal a mais; o resto do sistema nunca vê string de dinheiro.
- **Percentual em pontos-base inteiros** (`taxa_bps = 250` para 2,5%), nunca `0.025`.
- **Arredondamento é decisão escrita, não acidente.** Escolha uma regra (meia-para-par ou para
  baixo), aplique em **um** lugar e registre em ADR. Ao dividir (split, parcelas), **a soma das
  partes tem de ser igual ao total**: distribua o resto de centavos de forma determinística (a
  primeira parcela ou o recebedor principal leva o resto), nunca arredonde cada parte isolada.
- **Parcelamento:** `total = soma(parcelas)`, resto na primeira (ou na última), testado por
  propriedade (para todo total e N, a soma fecha).

## 2. Estados de pagamento são uma máquina de estados explícita

Modele `Pagamento` como enum com transições permitidas e **nenhum outro caminho**:

```
criado -> pendente -> autorizado -> capturado -> liquidado
                 \-> expirado        \-> estornado (parcial/total)
                 \-> recusado        \-> em_disputa -> disputa_perdida | disputa_ganha
                 \-> cancelado
```

(Nomes são da casa; mapeie os do PSP em **uma** camada de tradução.) Regras:

1. **Transição é função pura** `(estado, evento) -> estado | erro`, testada em tabela. Transição
   inválida é erro registrado e ignorado, nunca silenciosamente aceita.
2. **Estado terminal não volta.** `liquidado` não vira `pendente` porque chegou um webhook atrasado;
   o evento fora de ordem é descartado após reconsulta ao PSP (`references/webhooks-idempotencia.md`).
3. **Evento do PSP é fato, não comando.** Guarde o evento bruto (append-only), derive o estado dele.
   O estado é reconstruível; o evento não se perde.
4. **Toda transição grava quem/quando/por quê** (evento de domínio) — é a trilha de auditoria e a
   fonte da conciliação.
5. **Estado desconhecido do PSP** vira `desconhecido` + alerta, nunca mapeamento para "pago".
6. **Pago só quando o PSP confirma por canal autenticado.** O retorno do navegador/app do cliente
   (redirect "sucesso") é dica de UX, nunca prova de pagamento.

## 3. Ledger de dupla entrada

Todo movimento de dinheiro é um **lançamento** que **debita uma conta e credita outra, no mesmo
valor**; saldo é derivado, não mantido à mão.

- **Imutável e append-only.** Corrigir é lançar o **estorno** (lançamento inverso) com referência
  ao original; `UPDATE`/`DELETE` em lançamento é vetado (revogue o privilégio no banco).
- **Invariante:** para cada transação, `soma(débitos) == soma(créditos)`, por moeda. Garanta no banco
  (CHECK/trigger ou função única de inserção) **e** com teste de propriedade.
- **Contas** de passivo/ativo claras: `a_receber_psp`, `caixa_psp`, `receita`, `taxa_psp`,
  `repasse_a_pagar`, `estornos`, `chargebacks`. Cliente/recebedor tem conta própria por tenant.
- **Chave de idempotência por lançamento** (`transacao_id` único, derivado do evento de origem): o
  mesmo webhook processado duas vezes não lança duas vezes.
- **Saldo** = soma dos lançamentos da conta; materialize com saldo de fechamento por período e
  confira contra a soma. Divergência é incidente, não ajuste.
- **Reserva e captura** (autorizar e capturar depois) são lançamentos distintos; reserva expirada é
  lançamento de liberação.
- **Valores sempre em inteiro**, mesma moeda por transação; câmbio é transação explícita com
  taxa registrada.

## 4. Transação de banco

Mudança de estado + lançamento + registro do evento processado ocorrem **na mesma transação** (ou
via outbox). Efeito externo (chamar PSP, enviar e-mail de recibo) acontece **depois do commit**, por
outbox, nunca dentro da transação. Schema relacional e índices: `schematize-database →
references/` (desenho e motor); dado em movimento:
`schematize-data`.

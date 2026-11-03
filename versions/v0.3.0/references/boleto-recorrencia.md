# Boleto, assinatura recorrente e Pix Automático

> Parte da skill **schematize-payments**. Datas e regras do BCB/Febraban: `references/stack-versoes.md`.

## 1. Boleto

- **Boleto registrado** (padrão): gerado via API do PSP/banco, vira título na plataforma de
  cobrança; nunca gere linha digitável "na mão". O PSP devolve linha digitável, código de barras e
  PDF; guarde o **identificador do título (nosso número)** como chave idempotente.
- **Boleto com QR Pix (híbrido)**: o mesmo título aceita boleto ou PIX; concilie pelos dois
  identificadores e baixe o título quando qualquer um pagar (evita pagamento duplo).
- **Compensação não é instantânea:** o pagamento chega em D+0/D+1 útil <!-- reverificar janela de liquidação vigente -->.
  Estado `pendente` convive com `pago_em_compensacao`; só `liquidado` libera o produto de risco.
- **Vencimento** em dia não útil prorroga para o próximo útil; calcule com calendário de feriados
  (nacional + bancário), não com `+3 dias` ingênuo.
- **Multa, juros e desconto** são do título (parâmetros enviados ao registrar), não calculados à
  parte por você; evita divergência entre o que o banco cobra e o que você conta.
- **Cancelar boleto** = baixa do título via API, e só se não pago; boleto pago depois da baixa cai
  em exceção de conciliação.
- **Pagamento a maior/a menor/duplicado** são exceções previstas na conciliação, com fila e dono.

## 2. Assinatura (cobrança recorrente)

Modele **Assinatura** separada de **Cobrança**:

```
assinatura: trial -> ativa -> em_atraso -> suspensa -> cancelada
cobranca(ciclo N): pendente -> paga | falhou -> (retentativa) -> paga | abandonada
```

1. **Uma cobrança por ciclo, idempotente** pela chave `assinatura_id + ciclo` (nunca cobrar o
   mesmo ciclo duas vezes porque o job rodou duas vezes).
2. **Consentimento explícito e registrado** (texto, data, meio) para cobrar de novo — vale para
   cartão salvo e para Pix Automático. Cancelar tem de ser tão fácil quanto assinar.
3. **Dunning** (retentativas) com calendário e comunicação ao cliente: ex. D+1, D+3, D+7, depois
   suspensão com período de graça. Limite de tentativas; falha por cartão recusado "definitivamente"
   (cartão cancelado/roubado) não é retentada.
4. **Upgrade/downgrade** com pró-rata em inteiro (regra de arredondamento do ADR); mudança de plano
   vale no próximo ciclo ou gera cobrança/crédito explícito no ledger.
5. **Fuso e virada de mês:** ciclo ancorado em data do contrato; dia 31 em mês curto tem regra
   escrita. Cobrança em horário de baixo risco para falha do PSP.
6. **Aviso prévio** de reajuste/renovação conforme o CDC e o contrato (`schematize-institutional`).

## 3. Pix Automático

PIX recorrente **autorizado pelo pagador** (jornada de autorização com a instituição dele; depois,
cada cobrança é agendada e debitada na data, sem novo QR). Entrou em operação em 2025 e tem regras
operacionais que o BCB ajusta com frequência (ver `references/stack-versoes.md`).

- Estados próprios: **recorrência** (`criada -> aprovada | rejeitada | cancelada | expirada`) e
  **cobrança da recorrência** (agendada -> paga | falhou | cancelada). Nada disso é "assinatura do
  seu produto": o vínculo é por id, em tabela própria.
- O PSP expõe as chamadas; o prazo de envio da cobrança antes do vencimento e o de retentativa
  são regras do BCB <!-- reverificar prazos e retentativas vigentes -->.
- Cancelamento pelo pagador acontece **fora do seu sistema**: webhook de cancelamento move a
  assinatura para `em_atraso/suspensa` conforme a regra, sem apagar histórico.
- Pareie com cartão/boleto como fallback de cobrança; o ledger não diferencia o meio.

## 4. Fiscal e recorrência

Cada cobrança recorrente paga pode gerar documento fiscal (NFS-e/NF-e): `references/split-conciliacao-fiscal.md`.

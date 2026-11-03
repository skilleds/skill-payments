# Split, conciliação, estorno e documento fiscal

> Parte da skill **schematize-payments**. Pipeline de dados da conciliação: `schematize-data`.

## 1. Split (divisão do pagamento)

- Marketplace/plataforma recebe um pagamento e **repassa a mais de um recebedor** (vendedor,
  plataforma, afiliado). Use o **split nativo do PSP** quando existir (o PSP é quem responde pelo
  repasse e pela retenção); split "manual" por transferências posteriores aumenta risco fiscal e
  operacional.
- Regra de divisão é **dado versionado** (percentual em bps ou valor em centavos fixo), gravada
  **no pedido** no momento da cobrança, nunca recalculada depois com regra nova.
- **Soma das partes = total**, resto de centavos com regra determinística (`estado-e-ledger.md`).
- Estorno/chargeback de venda com split **reverte proporcionalmente** (ou conforme contrato);
  decida quem arca com a taxa do PSP e escreva em ADR.
- Recebedor é entidade **KYC/KYB** do PSP: conta de subadquirente não se cria sem validação;
  dados do recebedor são dado pessoal sensível (LGPD).
- **Repasse** (payout) tem estado e idempotência próprios e passa por **step-up** quando manual
  (`schematize-iam`; autorização por tenant/papel em ReBAC, não só "é admin").

## 2. Conciliação

Conciliar = provar que **o que o seu ledger diz** é **o que o PSP/banco diz**, por período.

1. **Três fontes**: seu ledger, extrato/relatório do PSP (arquivo de liquidação ou API de
   transações) e extrato bancário (o dinheiro que de fato entrou na conta).
2. **Chave de casamento**: `endToEndId` (PIX), id da transação do PSP (cartão), nosso número
   (boleto). Casamento por valor+data é último recurso e vira exceção.
3. **Resultado por item**: `casado`, `so_no_ledger`, `so_no_psp`, `valor_diferente`,
   `duplicado`, `fora_de_periodo`. Cada exceção tem **dono e prazo**; saldo de exceções é
   métrica.
4. **Rodar todo dia (D+1)**, idempotente (reprocessar o mesmo dia não duplica), com relatório
   assinado de fechamento. O fechamento do mês congela o período (correção vira lançamento no mês
   corrente referenciando o original).
5. É um **pipeline de dados**: contrato do arquivo do PSP, quarentena do que não parseia, lineage
   até o lançamento (`schematize-data → /data-pipeline`, `/data-quality`).
6. **Taxa do PSP**: lançamento próprio (`taxa_psp`) por transação; conciliar líquido × bruto.
7. **Fuso**: datas do PSP em fuso do PSP; normalize para UTC com o fuso de origem registrado,
   porque virada de dia é a maior fonte de falso "diferente".

## 3. Estorno, devolução e reembolso (visão única)

| Meio | Operação | Chave de idempotência | Efeito no ledger |
|---|---|---|---|
| PIX | devolução (nova transferência) | `id` da devolução | lançamento inverso após estado final |
| Cartão | estorno/cancelamento (refund) | id do estorno no PSP | lançamento inverso; fatura do cliente é do emissor |
| Boleto | sem estorno automático | — | devolução manual por PIX/TED com ticket e step-up |
| Qualquer | chargeback | id da disputa | reserva em `chargebacks`, depois definitivo |

Regra de domínio: **soma dos estornos ≤ valor capturado**; estorno é sempre parcial ou total de
**um** pagamento identificado, nunca "ajuste de saldo".

## 4. Documento fiscal (NF-e / NFS-e)

- **Emitir via provedor** (API de emissão homologada: plataforma de notas ou o emissor
  nacional/municipal), não construir o XML, o certificado A1/A3 e a comunicação com a SEFAZ/prefeitura
  do zero. A emissão é **efeito externo** e passa pelas mesmas regras: fora de prd só ambiente de
  **homologação** do provedor/SEFAZ, nunca nota real (`references/nao-cobrar-fora-de-prd.md`).
- **NFS-e**: o padrão nacional ganhou obrigatoriedade progressiva a partir de 2026; layout inclui
  campos de IBS/CBS da reforma tributária. Datas e escopo variam: `references/stack-versoes.md`
  <!-- reverificar -->.
- **Gatilho da emissão** é um estado do pagamento (`liquidado` ou `capturado`, conforme a regra
  fiscal do negócio), por **evento idempotente** (`pagamento_id` único por nota): retry não emite
  duas notas.
- **Cancelamento/devolução** gera nota de cancelamento/estorno conforme prazo legal; o fluxo
  fiscal acompanha o de estorno.
- **Dado fiscal** (CNPJ/CPF, endereço, código de serviço/NCM) vem validado no cadastro; falha de
  emissão é estado `fiscal_pendente` com fila, nunca bloqueia o recebimento nem some em silêncio.
- A **regra tributária** (alíquota, CST, município) é do contador e do provedor; esta skill dá o
  desenho de integração, não a interpretação da lei. Revisão humana (`[H ]`) obrigatória.

# Cartão, PCI DSS, tokenização e chargeback

> Parte da skill **schematize-payments**. Versões de norma e datas: `references/stack-versoes.md`.

## 1. Piso: nunca toque o PAN

O **PAN** (número do cartão) e o **CVV** são dados de pagamento sob o PCI DSS. A casa **não toca
PAN** em nenhum serviço: nem recebe, nem processa, nem loga, nem armazena, nem passa em fila.
O objetivo é manter o **escopo mínimo (SAQ A)**:

1. **Captura pelo PSP**: página hospedada (redirect) ou campos hospedados/iframe do PSP. O PAN vai
   do navegador direto ao PSP e volta como **token**.
2. **Seu backend vê só**: token do PSP, bandeira, **últimos 4 dígitos**, validade (mês/ano, se
   necessário), nome do portador conforme exigido. Nada que reconstrua o PAN.
3. **CVV nunca é armazenado**, nem cifrado, nem depois da autorização (regra do PCI DSS).
4. **Chave de PSP "publicável" no front; "secreta" só no backend**, em cofre, por ambiente.
5. **Nada de PAN em log, trace, APM, relatório de erro, dump de requisição, planilha ou ticket.**
   O gate pega variável de cartão em log (`pay-pan-em-log`), coluna de PAN/CVV (`pay-pan-armazenado`)
   e PAN literal com Luhn válido (`pay-pan-literal`); o PAN de teste público do PSP é permitido.
6. **App móvel:** SDK do PSP; nunca monte seu próprio formulário que passe pelo seu backend.

## 2. SAQ A e o que ele exige hoje

- Quem **redireciona totalmente** para página hospedada ou usa iframe/campos hospedados de um PSP
  em conformidade se enquadra, em regra, no **SAQ A** (verifique a elegibilidade no documento
  vigente do PCI SSC; a decisão de enquadramento é do PSP/adquirente e do QSA, não desta skill).
- **PCI DSS v4.0.1** (março de 2025: requisitos futuros viraram obrigatórios): para páginas que
  **incorporam** o formulário do PSP, o SAQ A revisado trocou os itens 6.4.3 e 11.6.1 por um
  **critério de elegibilidade**: o comerciante precisa assegurar que seu site não é suscetível a
  ataque de script (implementando os controles equivalentes ou obtendo confirmação por escrito do
  PSP). Redirect total dispensa esse critério. Fonte e data em `references/stack-versoes.md`.
  <!-- reverificar o texto exato do critério no SAQ A vigente -->
- Consequência de desenho: **a página que hospeda o iframe é escopo**. Inventário de scripts de
  terceiros nela, CSP restritiva, SRI, sem tag manager livre na página de pagamento.
- Esta skill **não substitui** o PCI QSA/AOC: ela mantém o código fora de escopo e prova isso
  com o gate. Certificação é humana.

## 3. Autenticação e risco

- **3-D Secure 2** (autenticação do portador): ativado por padrão no checkout de risco; o ônus da
  fraude migra para o emissor quando autenticado (liability shift) <!-- reverificar regras por bandeira no Brasil -->.
- **Anti-fraude:** score do PSP + regras suas (velocidade, valor, país, e-mail descartável).
  Decisão `revisão manual` é estado, com fila e prazo.
- **Step-up de identidade** em ação de alto valor (trocar cartão, sacar saldo, aumentar limite):
  `schematize-iam` (fator forte), não sessão simples.

## 4. Fluxos de cartão

- **Autorização × captura:** autorizar reserva o limite; capturar cobra. Autorização tem prazo;
  expirada vira `expirado` e libera a reserva no ledger.
- **Cartão salvo (cartão na carteira):** o PSP guarda; você guarda `token + last4 + bandeira`.
  Cobrança recorrente com token exige consentimento registrado do cliente (data, texto, IP/UA).
- **Parcelamento:** com ou sem juros; soma das parcelas fecha o total (`estado-e-ledger.md`).
- **Estorno (cancelamento/refund):** total ou parcial pela API do PSP; idempotente pelo id do
  estorno; vira lançamento inverso. Janela de estorno e prazo de ver na fatura são do emissor.

## 5. Chargeback (contestação)

Chargeback é o portador contestando junto ao emissor: o valor sai de você **imediatamente** e você
tem prazo curto para contestar com evidência.

1. Estado `em_disputa` ao receber o aviso (webhook do PSP); o saldo reserva o valor em
   `chargebacks` (ledger), não o descarta.
2. **Evidência guardada desde o dia 0**: pedido, comprovante de entrega/uso, IP, termos aceitos,
   logs de autenticação (3DS), comunicação com o cliente. Retenção definida com a LGPD
   (`schematize-institutional`).
3. Prazo do PSP/bandeira: fila com dono e alerta antes de vencer. Perdeu: `disputa_perdida` e
   lançamento definitivo; ganhou: `disputa_ganha` e liberação.
4. **Taxa de chargeback** é métrica de saúde (ratio por bandeira): alerta antes do limite do
   programa de monitoramento da bandeira (`schematize-observability`).
5. Chargeback recorrente de um cliente vira regra anti-fraude (bloqueio), não conselho.

## 6. Ambientes

Fora de prd: **PAN de teste público do próprio PSP** em sandbox, nunca cartão real nem o seu
(inclusive o do desenvolvedor). `references/nao-cobrar-fora-de-prd.md`.

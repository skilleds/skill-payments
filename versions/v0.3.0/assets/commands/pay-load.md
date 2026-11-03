---
description: schematize-payments — carrega à força TODO o corpo normativo de pagamentos e passa a aplicá-lo nesta sessão.
---
Carregue **agora** o corpo normativo da skill `schematize-payments`. A partir daqui, nesta sessão,
isto **não é opcional**.

1. **Leia na íntegra, sem trabalhar de memória.** Caminho:
   `.claude/skills/schematize-payments/references/*.md` (projeto) ou
   `~/.claude/skills/schematize-payments/references/*.md` (global):
   - `estado-e-ledger.md` — dinheiro inteiro, arredondamento, máquina de estados, ledger de dupla entrada.
   - `pix.md` — cobrança imediata e com vencimento, QR dinâmico, `txid`, `endToEndId`, devolução, MED.
   - `cartao-pci.md` — nunca tocar PAN, SAQ A, PCI DSS, 3-D Secure, autorização x captura, chargeback.
   - `boleto-recorrencia.md` — boleto, assinatura, dunning, Pix Automático.
   - `webhooks-idempotencia.md` — receber webhook, chamar o PSP com idempotência, outbox, testes.
   - `split-conciliacao-fiscal.md` — split, conciliação, estorno, NF-e/NFS-e via provedor.
   - `nao-cobrar-fora-de-prd.md` — o piso absoluto: ambiente fail-closed, sandbox, chaves, exceção.
   - `stack-versoes.md` — anexo volátil: normas do BCB, PCI, fiscal, com fonte e data.
2. **Rode o gate no repo atual** antes de opinar:
   `bash .claude/skills/schematize-payments/scripts/check-pay.sh .`
3. **Aplique daqui em diante** a todo código de pagamento que você escrever ou tocar, e diga qual
   piso está aplicando quando ele mudar o que você ia fazer. **Nunca cobre, transfira, estorne ou
   emita nota de verdade**: só sandbox/homologação, e só se `APP_ENV` for explicitamente não-prd.

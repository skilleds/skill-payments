# Nunca cobrar fora de prd

> Parte da skill **schematize-payments**. É o piso absoluto da skill e é a aplicação, a
> pagamentos, do efeito externo da base (`schematize-engineering → references/efeitos-externos.md`,
> herdado). Cobrança, transferência, estorno, repasse e emissão de nota são **efeitos externos
> irreversíveis**: dinheiro de verdade sai da conta de alguém e não há `undo`.

## 1. Por que é pior que o e-mail

O incidente-modelo da casa (milhares de e-mails de teste) queimou reputação de domínio. Cobrança é
mais grave por construção: **PIX é irrevogável**, boleto emitido vira dívida registrada em nome de
uma pessoa, cartão cobrado gera contestação, nota fiscal emitida tem efeito tributário. Um laço de
teste, um seed mal escrito ou uma credencial de produção copiada para `.env.local` bastam.

## 2. O desenho: seguro por construção, cobrar é ato deliberado

1. **Fail-closed no ambiente.** `APP_ENV` (ou equivalente) ausente ou desconhecido ⇒ **não-prd** ⇒
   sandbox/dublê. **Só o valor exato `production` cobra de verdade.** Nunca `?? "production"`,
   `or "prod"` ou `unwrap_or("prod")` como default (o gate acusa: `pay-default-prd`).
2. **Credencial de PSP por ambiente, em cofre, nunca no repo.** A chave de produção existe **só no
   ambiente prd**; hml/dev/CI recebem credencial **sandbox** do PSP. Chave `live` literal em
   qualquer arquivo é incidente: rotacionar primeiro, limpar depois (`pay-chave-live`).
3. **Host de produção do PSP em arquivo de ambiente não-prd é erro** (`pay-prd-em-nao-prd`). Cada
   PSP tem base URL/credencial de sandbox separada; configure o gate com `PAY_PROD_HOSTS` para o seu.
4. **Camada anticorrupção única** (`PspGateway`) com duas implementações: **real** (só instanciada
   quando o ambiente é prd) e **sandbox/fake** (default). O resto do código nunca escolhe.
   O construtor da real **recusa** subir com ambiente ≠ prd.
5. **Sandbox do PSP, não prod "pequeno".** Valor de R$ 0,01 em produção continua sendo cobrança
   real. PAN de teste público do PSP em cartão; PIX de teste via simulador do sandbox; boleto de
   teste não é registrado de verdade.
6. **Testes automatizados nunca chamam o PSP real.** Dublê/contrato no CI; sandbox em job
   separado com credencial sandbox. Teste que precisa de produção não existe (`schematize-qa`:
   teste nunca dispara efeito externo real).
7. **Webhook de hml/dev aponta para o sandbox**, nunca para a URL de prd, e o contrário: a URL de
   webhook de prd só aceita assinatura/certificado de prd.
8. **Nota fiscal:** fora de prd só **homologação** do provedor/SEFAZ/prefeitura; nunca emitir
   nota real em teste. O CNPJ de teste é o do ambiente de homologação.
9. **Dados de teste sintéticos:** cliente, e-mail (`<papel>+<run-id>-<n>@test.<domínio>` em rota
   nula), CPF/CNPJ de teste válidos pelo dígito mas inexistentes. **Vetado** CPF/cartão/chave PIX
   de pessoa real, **inclusive a sua**.
10. **Cap por execução** em qualquer job que cobra (recorrência, repasse, reprocessamento): teto
    de valor e de quantidade com abort, e **janela** para rodar. Em prd o cap alerta antes do abort.
11. **Dry-run por padrão** em script operacional que mexe em dinheiro (reprocessar cobranças,
    repasse manual, backfill): imprime o que faria; executar exige flag explícita **e** confirmação
    humana em prd.
11a. **Operação em prd é do ops (pisos 23/24).** Reprocesso, repasse, backfill e lançamento corretivo
    de ledger em prd são **operações nomeadas** do `<projeto>_ops` (dry-run, confirmação humana,
    auditoria append-only). A IA só as implementa no repo do ops, via git; nunca roda SQL, script ad
    hoc nem `ssh` mutável em prd. Gate: `pay-script-sem-dryrun`.
12. **Cobrar de verdade fora de prd** (ex.: validar um PSP novo com cartão real) exige **ADR +
    allowlist ≤ 5 contas + cap de valor e quantidade + janela + conta/credencial separada** e
    estorno planejado. É exceção humana (`[H ]`), nunca decisão do agente.

## 3. Invariantes herdadas (efeito externo)

Cap por execução com abort, fail-closed, chave sandbox fora de prd, dado sintético em domínio de
rota nula e a exceção de cinco condições valem aqui sem cópia local: bloco herdado no `SKILL.md`
(piso 18 da engineering; o "piso 1" desta skill é o local) e texto integral em `schematize-engineering → references/efeitos-externos.md`.

## 4. Como provar (não basta declarar)

- `bash scripts/check-pay-effects.sh .` sem achados (`pay-gateway-sem-guarda`, `pay-cobranca-sem-cap`,
  `pay-guard-nao-fail-closed`, `pay-chave-nao-sandbox`, `pay-script-sem-dryrun`), mais
- `bash scripts/check-pay.sh .` sem achados de `pay-chave-live`, `pay-prd-em-nao-prd` e
  `pay-default-prd`.
- Teste de unidade: `ambiente ∈ {ausente, "", "dev", "hml", "PRODUCTION ", "prod"}` ⇒ gateway
  sandbox; **só** o valor exato de prd ⇒ gateway real (o guard fica DENTRO do construtor do real).
- Teste de integração em sandbox: cobrança de teste cria, confirma por webhook, estorna e fecha o
  ledger a zero.
- Auditoria de credencial: a chave live **não** aparece em nenhum segredo de hml/CI
  (`schematize-infra → references/segredos.md`).
- `/pay-sandbox` roda este checklist.

Cobrança dentro de bot de chat: o bot nunca toca PAN nem cobra fora de prd; ver `schematize-bots → references/ambientes-e-efeito-externo.md`.

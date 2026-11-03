#!/usr/bin/env bash
# check-pay-effects.sh — gate do piso 18 da schematize-engineering aplicado a PAGAMENTOS:
# "nunca cobra fora de prd". Prova por varredura que o gateway real tem guard fail-closed DENTRO
# dele, sink/sandbox por default, cap por execução e que script operacional tem dry-run.
# (O piso 1 DESTA skill é outro: dinheiro/PAN. O de efeito externo é o 18 da base.)
#
# Regras (`arquivo:linha: [regra] msg`):
#   pay-default-prd           ambiente com default de produção (ausente deve cair no sandbox/sink)
#   pay-guard-nao-fail-closed guard por lista negra (`env != "dev"`): só "prd" EXATO libera cobrança real
#   pay-gateway-sem-guarda    arquivo com gateway real/chamada que cria cobrança sem, NO MESMO arquivo:
#                               (a) comparação exata com prd, (b) recusa (raise/throw/panic/Err/exit)
#                               fora de prd, (c) gateway sandbox/sink/fake como alternativa
#   pay-cobranca-sem-cap      cobrança sem cap por execução (PAY_MAX_AMOUNT_CENTS / PAY_MAX_CHARGES_PER_RUN)
#   pay-script-sem-dryrun     script de reprocesso/backfill/repasse/estorno em lote sem --dry-run
#                               (em prd é operação NOMEADA do ops, pisos 23/24; a IA não roda SQL)
#   pay-prd-em-nao-prd        credencial/segredo de prd em arquivo de ambiente não-prd (sem waiver)
#   pay-chave-nao-sandbox     chave de PSP em arquivo não-prd que não é sandbox/teste nem referência a cofre
# Comentários NÃO contam como guard. Waiver `pay-ok: <motivo>` (linha ou acima); NÃO vale para
# pay-prd-em-nao-prd nem pay-chave-nao-sandbox. Entrada: $1 = diretório (default .).
# Saída: 0 passa · 1 reprova · 2 nada a verificar. Estático: o teste de unidade do guard continua obrigatório.
set -euo pipefail

raiz="${1:-.}"
[ -d "$raiz" ] || { echo "check-pay-effects: diretório inexistente: $raiz" >&2; exit 2; }

CODE_RE='\.(go|rs|ex|exs|cs|rb|py|ts|tsx|js|jsx|mjs|cjs|php|java|kt|swift|dart|zig|sh)$'
CONF_RE='(\.(env|ya?ml|toml|json|tf|tfvars|properties|conf|ini)$|(^|/)\.env[^/]*$)'
TEST_RE='(^|/)(test|tests|spec|specs|__tests__|e2e|fixtures)(/|$)|(_test|\.test|\.spec|_spec)\.[a-z]+$'
NAO_PRD_RE='(^|/|[._-])(dev|development|hml|homolog|homologacao|stg|staging|test|tests|sandbox|local|e2e|qa)([._/-]|$)'
PRD_RE='(^|/|[._-])(prd|prod|production)([._/-]|$)'
OPS_RE='(reprocess|backfill|repasse|payout|estorno[_-]?lote|refund[_-]?all|reembolso[_-]?lote|ajuste|corretiv)'
HOSTS_PRD='pix\.api\.efipay\.com\.br|cobrancas\.api\.efipay\.com\.br|api\.asaas\.com|www\.asaas\.com|api\.pagseguro\.com|api\.mercadopago\.com|api\.cieloecommerce\.cielo\.com\.br|api\.userede\.com\.br|app\.vindi\.com\.br|checkout-live\.adyen\.com|-checkout-live\.adyenpayments\.com'
GATEWAY_REAL_RE='((class|struct|type|impl|def|func|fn|module)[[:space:]]+[A-Za-z0-9_]*(Real|Live|Prod|Production)[A-Za-z0-9_]*(Gateway|Psp|PSP|Provider|Client)|(Real|Live)(Psp|PSP|Gateway)[[:space:]]*(\(|::new|\{)|new[[:space:]]+(Real|Live)[A-Za-z]*(Gateway|Psp))'
COBRA_RE='(payment_intents|/charges|/payments|/orders|create_?charge|criar_?cobranca|create_?payment|createPayment|/cob\b|/cobv\b|/transfers|/payouts)'
POST_RE='(\.post\(|http\.post|post[_ ]?json|requests\.post|fetch\(|Net::HTTP::Post|HttpMethod\.Post|PostAsync|reqwest|Req\.post|method:[[:space:]]*["'"'"']POST)'
PRD_CMP='((==|===|=~)[[:space:]]*["'"'"'](prd|prod|production)["'"'"']|["'"'"'](prd|prod|production)["'"'"'][[:space:]]*(==|===)|(equals|eq\?|\.eq|isEqual|is_prd|isProd|is_production)[^;]{0,40}["'"'"'](prd|prod|production)["'"'"'])'
RECUSA_RE='(raise|throw|panic!?|Err\(|exit[[:space:]]*\(?[1-9]|abort|fatal|PermissionError|RuntimeError|recus|refus|Forbidden)'
SINK_RE='(Sandbox|Sink|sink|Fake|Null|Noop|DryRun|dry_run|dry-run)[A-Za-z_]*'
CAP_RE='(PAY_MAX_AMOUNT_CENTS|PAY_MAX_CHARGES_PER_RUN|PAY_MAX_[A-Z_]+|max_amount_cents|max_charges_per_run)'

mapfile -d '' arquivos < <(find "$raiz" \( -name .git -o -name node_modules -o -name vendor -o -name target \
  -o -name _build -o -name deps -o -name dist -o -name .next \) -prune -o -type f -print0 | sort -z)

achados=0; verificados=0

achado() {
  local f="$1" n="$2" regra="$3" msg="$4"
  case "$regra" in pay-prd-em-nao-prd|pay-chave-nao-sandbox) ;; *)
    if [ "$n" -gt 0 ]; then
      sed -n "${n}p" "$f" | grep -qE 'pay-ok:[[:space:]]*[^[:space:]]' && return 0
      if [ "$n" -gt 1 ]; then sed -n "$((n - 1))p" "$f" | grep -qE 'pay-ok:[[:space:]]*[^[:space:]]' && return 0; fi
    else
      grep -qE "pay-ok:[[:space:]]*${regra}[[:space:]]+[^[:space:]]" "$f" && return 0
    fi ;;
  esac
  echo "${f}:${n}: [${regra}] ${msg}"
  achados=$((achados + 1))
}
limpo() { sed -E 's/^[[:space:]]*(\/\/|#|--|\*|\/\*).*$//; s/[[:space:]](\/\/|#)[[:space:]].*$//' "$1"; }

for f in "${arquivos[@]}"; do
  rel="${f#"$raiz"/}"
  grep -qI . "$f" 2>/dev/null || continue
  case "$rel" in *.lock|*package-lock.json|*.sum|*.min.js) continue ;; esac
  codigo=0; conf=0
  [[ "$rel" =~ $CODE_RE ]] && codigo=1
  [[ "$rel" =~ $CONF_RE ]] && conf=1
  [ "$codigo" = 1 ] || [ "$conf" = 1 ] || continue
  verificados=$((verificados + 1))

  # --- arquivo de ambiente não-prd: credencial/host de prd e chave que não é sandbox (sem waiver)
  if [ "$conf" = 1 ] && [[ "$rel" =~ $NAO_PRD_RE ]] && ! [[ "$rel" =~ $PRD_RE ]]; then
    tmp="$(mktemp)"; limpo "$f" >"$tmp"
    while IFS=: read -r n _; do
      [ -n "$n" ] || continue
      achado "$f" "$n" pay-prd-em-nao-prd 'credencial/host de PSP de PRODUÇÃO em arquivo de ambiente não-prd: fora de prd só sandbox do PSP (nunca cobrar fora de prd)'
    done < <(grep -nIiE "(_(PRD|PROD|PRODUCTION|LIVE)[A-Z_]*(KEY|TOKEN|SECRET)|(KEY|TOKEN|SECRET)[A-Z_]*_(PRD|PROD|PRODUCTION|LIVE))[[:space:]]*[=:]|$HOSTS_PRD|sk_live_|rk_live_|ak_live_|APP_USR-" "$tmp" || true)
    while IFS=: read -r n resto; do
      [ -n "$n" ] || continue
      val="${resto#*[=:]}"
      printf '%s' "$val" | grep -qiE '(sandbox|sbx|test|teste|homolog|hml|dummy|changeme|placeholder|xxx|example|\$\{|vault:|secret:|op://|^[[:space:]"'"'"']*$)' && continue
      achado "$f" "$n" pay-chave-nao-sandbox 'chave de PSP em ambiente não-prd sem marca de sandbox/teste: use a credencial SANDBOX do PSP (ou referência a cofre)'
    done < <(grep -nIiE '^[[:space:]"]*[A-Z0-9_]*(API_?KEY|ACCESS_?TOKEN|SECRET_?KEY|CLIENT_?SECRET|PSP_?(KEY|TOKEN|SECRET))[A-Z0-9_]*"?[[:space:]]*[=:]' "$tmp" || true)
    rm -f "$tmp"
  fi

  [ "$codigo" = 1 ] || continue
  [[ "$rel" =~ $TEST_RE ]] && continue
  tmp="$(mktemp)"; limpo "$f" >"$tmp"

  while IFS=: read -r n _; do
    [ -n "$n" ] || continue
    achado "$f" "$n" pay-default-prd 'ambiente com default de PRODUÇÃO: ausente/desconhecido deve cair no sandbox/sink (fail-closed)'
  done < <(grep -nIE "(APP_ENV|PAY_ENV|PSP_ENV|PAYMENT_ENV|PAYMENTS_ENV|ENVIRONMENT|NODE_ENV|RAILS_ENV|MIX_ENV|[Ee]nv(ironment)?)[^#]{0,60}(\|\||\?\?|unwrap_or(_else)?\(|:-|, *|\bor |default[:=] *)[[:space:]]*[\"']?(production|prod|prd)[\"']" "$tmp" || true)

  while IFS=: read -r n _; do
    [ -n "$n" ] || continue
    achado "$f" "$n" pay-guard-nao-fail-closed 'guard por lista negra de ambientes: ambiente novo/typo cobra de verdade; inverta (só "prd" exato cobra, o resto é sandbox/sink)'
  done < <(grep -nIiE "(env|environment)[A-Za-z_.()]*[[:space:]]*(!=|!==|is not|not in)[[:space:]]*[\"'](dev|development|test|hml|staging|local|sandbox)[\"']" "$tmp" || true)

  real=0; cobra=0
  grep -qE "$GATEWAY_REAL_RE" "$tmp" && real=1
  if grep -qiE "$COBRA_RE" "$tmp" && grep -qiE "$POST_RE" "$tmp"; then cobra=1; fi

  if [ "$real" = 1 ] || [ "$cobra" = 1 ]; then
    faltam=""
    grep -qE "$PRD_CMP" "$tmp" || faltam="$faltam comparação-exata-com-prd"
    grep -qiE "$RECUSA_RE" "$tmp" || faltam="$faltam recusa-fora-de-prd(raise/throw/Err)"
    grep -qE "$SINK_RE" "$tmp" || faltam="$faltam gateway-sandbox/sink-como-default"
    if [ -n "$faltam" ]; then
      n="$(grep -nIiE "$GATEWAY_REAL_RE|$COBRA_RE" "$tmp" | head -1 | cut -d: -f1)"
      achado "$f" "${n:-0}" pay-gateway-sem-guarda "gateway real/cobrança sem guard fail-closed DENTRO dele; faltam:${faltam}. Piso 18 da engineering: nunca cobrar fora de prd"
    fi
    if ! grep -qE "$CAP_RE" "$tmp"; then
      n="$(grep -nIiE "$GATEWAY_REAL_RE|$COBRA_RE" "$tmp" | head -1 | cut -d: -f1)"
      achado "$f" "${n:-0}" pay-cobranca-sem-cap 'cobrança sem cap por execução (PAY_MAX_AMOUNT_CENTS / PAY_MAX_CHARGES_PER_RUN) com abort'
    fi
  fi

  # --- script operacional em lote sem dry-run
  if [[ "$rel" =~ $OPS_RE ]] && { [ "$cobra" = 1 ] || [ "$real" = 1 ] || grep -qiE '(insert[[:space:]]+into|update[[:space:]]+[a-z_]+[[:space:]]+set|delete[[:space:]]+from)' "$tmp"; }; then
    grep -qiE '(dry[_-]?run)' "$tmp" || achado "$f" 0 pay-script-sem-dryrun 'script de reprocesso/backfill/repasse/estorno sem --dry-run por padrão; em prd isto é operação nomeada do ops (a IA não escreve SQL nem roda script ad hoc)'
  fi
  rm -f "$tmp"
done

if [ "$verificados" -eq 0 ]; then
  echo "check-pay-effects: nenhum arquivo de código/config em $raiz (exit 2: isto NÃO é aprovação)" >&2
  exit 2
fi
if [ "$achados" -gt 0 ]; then
  echo "check-pay-effects: $achados achado(s) em $verificados arquivo(s)" >&2
  exit 1
fi
echo "check-pay-effects: ok ($verificados arquivo(s) verificados)"
echo "check-pay-effects: estático; teste de unidade ambiente ∈ {ausente,\"dev\",\"prod\"} ⇒ sandbox continua obrigatório" >&2

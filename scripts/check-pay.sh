#!/usr/bin/env bash
# check-pay.sh — gate estático do piso de pagamentos da schematize-payments.
#
# Motivo: dinheiro em float, chave de produção em ambiente de teste, webhook sem assinatura,
# cobrança sem idempotência e PAN em log são os defeitos que viram incidente financeiro. Este
# gate os pega por varredura de texto, sem depender de nenhuma linguagem ou SDK de PSP.
# Como funciona: percorre o repo (ignora .git, node_modules, vendor, target, _build, deps, dist),
# aplica as regras abaixo e imprime `arquivo:linha: [regra] mensagem`. Waiver rastreável, na linha
# ou na linha de cima: `pay-ok: <motivo>` (o motivo é obrigatório); nas regras de arquivo inteiro
# (webhook, idempotência) o waiver nomeia a regra (NÃO vale para pay-chave-live nem pay-pan-literal): `pay-ok: pay-webhook-sem-assinatura <motivo>`.
# Regras: pay-float-dinheiro · pay-chave-live · pay-prd-em-nao-prd · pay-default-prd ·
#   pay-webhook-sem-assinatura · pay-webhook-sem-dedupe · pay-cobranca-sem-idempotencia ·
#   pay-pan-em-log · pay-pan-literal · pay-pan-armazenado
# Entrada: $1 = diretório do repo (default: .). PAY_PROD_HOSTS = hosts de PSP de produção extras
#   (separados por espaço) para a regra pay-prd-em-nao-prd.
# Saída: 0 passa · 1 reprova · 2 nada para verificar (que NÃO é aprovação).
set -euo pipefail

raiz="${1:-.}"
[ -d "$raiz" ] || { echo "check-pay: diretório inexistente: $raiz" >&2; exit 2; }

CODE_RE='\.(go|rs|ex|exs|cs|rb|py|ts|tsx|js|jsx|mjs|cjs|php|java|kt|swift|dart|zig|sql)$'
CONF_RE='(\.(env|ya?ml|toml|json|tf|tfvars|tofu|properties|conf|ini)$|(^|/)\.env[^/]*$)'
TEST_RE='(^|/)(test|tests|spec|specs|__tests__|e2e|fixtures)(/|$)|(_test|\.test|\.spec|_spec)\.[a-z]+$'
NAO_PRD_RE='(^|/|[._-])(dev|development|hml|homolog|homologacao|stg|staging|test|tests|sandbox|local|e2e|qa)([._/-]|$)'
HOSTS_PRD='pix\.api\.efipay\.com\.br|cobrancas\.api\.efipay\.com\.br|api\.asaas\.com|www\.asaas\.com|api\.pagseguro\.com|api\.mercadopago\.com/v1/payments|api\.cieloecommerce\.cielo\.com\.br|api\.userede\.com\.br|app\.vindi\.com\.br|checkout-live\.adyen\.com|-checkout-live\.adyenpayments\.com'
if [ -n "${PAY_PROD_HOSTS:-}" ]; then
  extra="$(printf '%s' "$PAY_PROD_HOSTS" | sed 's/[.[\*^$/]/\\&/g; s/ /|/g')"
  HOSTS_PRD="$HOSTS_PRD|$extra"
fi
PANS_TESTE=' 4242424242424242 4111111111111111 5555555555554444 5105105105105100 378282246309005 6011111111111117 4000000000000002 4012888888881881 '

mapfile -d '' arquivos < <(find "$raiz" \( -name .git -o -name node_modules -o -name vendor -o -name target \
  -o -name _build -o -name deps -o -name dist -o -name .next \) -prune -o -type f -print0 | sort -z)

achados=0
verificados=0

# achado <arquivo> <linha> <regra> <mensagem> — respeita o waiver `pay-ok:` na linha ou na de cima.
achado() {
  local f="$1" n="$2" regra="$3" msg="$4"
  # segredo/PAN literal: nenhum waiver vale (rotacione/remova)
  if [ "$regra" = pay-chave-live ] || [ "$regra" = pay-pan-literal ]; then
    echo "${f}:${n}: [${regra}] ${msg}"; achados=$((achados + 1)); return 0
  fi
  if [ "$n" -gt 0 ]; then
    if sed -n "${n}p" "$f" | grep -qE 'pay-ok:[[:space:]]*[^[:space:]]'; then return 0; fi
    if [ "$n" -gt 1 ] && sed -n "$((n - 1))p" "$f" | grep -qE 'pay-ok:[[:space:]]*[^[:space:]]'; then return 0; fi
  else
    # regra de arquivo inteiro: o waiver nomeia a regra (`pay-ok: <regra> <motivo>`)
    if grep -qE "pay-ok:[[:space:]]*${regra}[[:space:]]+[^[:space:]]" "$f"; then return 0; fi
  fi
  echo "${f}:${n}: [${regra}] ${msg}"
  achados=$((achados + 1))
}

# por_linha <arquivo> <regex> <regra> <mensagem> [-i] — um achado por linha casada.
por_linha() {
  local f="$1" re="$2" regra="$3" msg="$4" flag="${5:--}" n gflags="-nIE"
  [ "$flag" = "-i" ] && gflags="-nIEi"
  while IFS=: read -r n _; do
    [ -n "$n" ] || continue
    achado "$f" "$n" "$regra" "$msg"
  done < <(grep "$gflags" -e "$re" "$f" 2>/dev/null || true)
}

# código sem comentários (linha inteira e cauda): comentário NÃO prova assinatura/dedupe/idempotência
limpo() { sed -E 's/^[[:space:]]*(\/\/|#|--|\*|\/\*).*$//; s/[[:space:]](\/\/|#)[[:space:]].*$//' "$1"; }

luhn_ok() {
  awk -v n="$1" 'BEGIN{s=0;d=0;for(i=length(n);i>=1;i--){c=substr(n,i,1)+0;if(d%2==1){c*=2;if(c>9)c-=9};s+=c;d++};exit (s%10==0)?0:1}'
}

DINHEIRO='(amount|valor|preco|price|total|saldo|balance|fee|taxa|desconto|discount|troco|subtotal|montante|cents|centavos|payout|refund|reembolso)'
TIPO_FLOAT='(float|double|f32|f64|float32|float64|Float|Double|real|REAL)'

for f in "${arquivos[@]}"; do
  rel="${f#"$raiz"/}"
  codigo=0; conf=0
  [[ "$rel" =~ $CODE_RE ]] && codigo=1
  [[ "$rel" =~ $CONF_RE ]] && conf=1
  teste=0; [[ "$rel" =~ $TEST_RE ]] && teste=1
  grep -qI . "$f" 2>/dev/null || continue
  case "$rel" in *.lock|*package-lock.json|*.sum|*.min.js) continue ;; esac
  verificados=$((verificados + 1))

  # --- chave live (qualquer arquivo de texto): segredo de produção nunca no repo
  por_linha "$f" '(sk_live_|rk_live_|ak_live_)[A-Za-z0-9]{16,}|APP_USR-[0-9a-f]{8,}-[0-9a-f-]{8,}' pay-chave-live \
    'chave de PSP de PRODUÇÃO literal no repositório: rotacione agora e leia a chave de um cofre, só em prd'

  # --- PAN literal (Luhn válido, prefixo de bandeira, fora da lista de PAN de teste público)
  if [ "$codigo" = 1 ] || [ "$conf" = 1 ] || [[ "$rel" == *.md ]]; then
    while IFS=: read -r n resto; do
      [ -n "$n" ] || continue
      for cand in $(printf '%s' "$resto" | grep -oE '(^|[^0-9.])[0-9]{13,19}([^0-9]|$)' | grep -oE '[0-9]{13,19}' || true); do
        [[ "$cand" =~ ^(4[0-9]{12,18}|5[1-5][0-9]{14}|2[2-7][0-9]{14}|3[47][0-9]{13}|6011[0-9]{12}|65[0-9]{14}|636368[0-9]{10}|3(0[0-5]|[68])[0-9]{11,12})$ ]] || continue
        case "$PANS_TESTE" in *" $cand "*) continue ;; esac
        luhn_ok "$cand" || continue
        achado "$f" "$n" pay-pan-literal 'número de cartão (PAN) real-looking no repositório: nunca toque PAN; use token do PSP ou o PAN de teste público do PSP'
      done
    done < <(grep -nIE '[0-9]{13,19}' "$f" 2>/dev/null || true)
  fi

  # --- configuração: host de produção de PSP em arquivo de ambiente não-prd
  if [ "$codigo" = 1 ] || [ "$conf" = 1 ]; then
    if [[ "$rel" =~ $NAO_PRD_RE ]] && ! [[ "$rel" =~ (^|/|[._-])(prd|prod|production)([._/-]|$) ]]; then
      por_linha "$f" "$HOSTS_PRD" pay-prd-em-nao-prd \
        'host de PSP de PRODUÇÃO em arquivo de ambiente não-prd: fora de prd só sandbox do PSP (nunca cobrar fora de prd)'
      por_linha "$f" '(sk_live|rk_live|pk_live|live_key|LIVE_KEY|PROD_KEY|production_key)' pay-prd-em-nao-prd \
        'referência a credencial de produção em arquivo não-prd: fora de prd só credencial sandbox'
    fi
  fi

  [ "$codigo" = 1 ] || [ "$conf" = 1 ] || continue

  # --- ambiente com default prd (fail-closed ao contrário)
  por_linha "$f" "(APP_ENV|PAY_ENV|PSP_ENV|PAYMENT_ENV|PAYMENTS_ENV|ENVIRONMENT|NODE_ENV|RAILS_ENV|MIX_ENV|[Ee]nv(ironment)?)[^#]{0,60}(\|\||\?\?|unwrap_or(_else)?\(|:-|, *|\bor |default[:=] *)[[:space:]]*[\"']?(production|prod|prd)[\"']" pay-default-prd \
    'ambiente com default de PRODUÇÃO: ausente/desconhecido deve ser não-prd (fail-closed); só o valor exato de prd cobra de verdade'

  [ "$codigo" = 1 ] || continue

  # --- dinheiro em ponto flutuante
  por_linha "$f" "${DINHEIRO}[A-Za-z0-9_]*[\"']?[[:space:]]*[:=]?[[:space:]]*${TIPO_FLOAT}\b|\b${TIPO_FLOAT}(32|64)?[[:space:]]+[A-Za-z0-9_]*${DINHEIRO}|parseFloat\([^)]*${DINHEIRO}|float\([^)]*${DINHEIRO}|${DINHEIRO}[A-Za-z0-9_]*[[:space:]]+(double precision|float|real)\b" pay-float-dinheiro \
    'dinheiro em float/double: use inteiro em centavos (ou o menor unidade da moeda) + moeda explícita' -i

  # --- literal decimal atribuído a nome de dinheiro (price := 19.90; total = 19.9), sem tipo explícito
  por_linha "$f" "\\b[A-Za-z0-9_]*${DINHEIRO}[A-Za-z0-9_]*[\"']?[[:space:]]*(:=|=|:)[[:space:]]*[0-9]+\\.[0-9]+\\b" pay-float-dinheiro \
    'literal decimal em valor monetário: use inteiro em centavos (1990, não 19.90)' -i

  # --- PAN/CVV em log
  por_linha "$f" '(log|logger|logging|print|println|printf|puts|console|debug!|info!|warn!|error!|trace!|inspect|dump|dd\(|IO\.puts|fmt\.).*(card_?number|cardnumber|numero_?cartao|\bpan\b|\bcvv2?\b|\bcvc2?\b|security_?code|card\.number)' pay-pan-em-log \
    'PAN/CVV em log ou saída: dado de cartão nunca é registrado (PCI DSS); registre só o token e os 4 últimos dígitos' -i

  # --- PAN/CVV persistido
  por_linha "$f" '(^|[^A-Za-z_])(cvv2?|cvc2?|card_?number|numero_?cartao|pan)[A-Za-z_]*[[:space:]"'"'"':]+(varchar|text|char|string|bytea|binary)|(t\.(string|text)|field|add_column|add|column)[[:space:](:,"'"'"']+[^#]*(cvv2?|cvc2?|card_?number|numero_?cartao)\b' pay-pan-armazenado \
    'coluna/campo de PAN ou CVV: CVV nunca se armazena (nem cifrado); PAN só no PSP/cofre PCI, o seu banco guarda token' -i

  [ "$teste" = 0 ] || continue

  # --- webhook: assinatura e deduplicação
  src="$(limpo "$f")"
  if grep -qiE 'webhook' "$f" && grep -qiE '(post|route|router|handler|controller|endpoint|@app\.|app\.(post|put)|def |func |fn |function |async )' "$f"; then
    if grep -qiE '(webhook|notification|notificacao)[a-z_]*(handler|controller|route|endpoint|receiver|receber)|(handler|controller|route|endpoint|receiver|receber)[a-z_]*(webhook|notification|notificacao)|["/]webhooks?["/]' "$f"; then
      if ! grep -qiE '(hmac|signature|assinatura|constant[_-]?time|timingSafeEqual|compare_digest|ConstantTimeCompare|secure_compare|verify_?sig|construct_?event|x-hub|mtls|client[_ -]?cert|ssl_client)' <<<"$src"; then
        achado "$f" 0 pay-webhook-sem-assinatura \
          'handler de webhook sem verificação de autenticidade (HMAC em tempo constante ou mTLS): qualquer um forja "pago"'
      fi
      if ! grep -qiE '(idempot|event_?id|notification_?id|dedup|on conflict|insert or ignore|insert_all|already[_ ]processed|processed_events|unique)' <<<"$src"; then
        achado "$f" 0 pay-webhook-sem-dedupe \
          'handler de webhook sem deduplicação por id do evento: o PSP reenvia e o efeito acontece duas vezes'
      fi
    fi
  fi

  # --- criação de cobrança sem idempotência
  if grep -qiE '(payment_intents|/charges|/payments|/orders|create_?charge|criar_?cobranca|create_?payment|createPayment|/cob\b|/cobv\b|/transfers|/payouts)' "$f" \
     && grep -qiE '(\.post\(|http\.post|post[_ ]?json|requests\.post|fetch\(|Net::HTTP::Post|HttpMethod\.Post|PostAsync|reqwest|Req\.post|method:[[:space:]]*["'"'"']POST)' "$f"; then
    if ! grep -qiE '(idempot|txid|x-request-id|dedup)' <<<"$src"; then
      achado "$f" 0 pay-cobranca-sem-idempotencia \
        'chamada que cria cobrança/transferência sem idempotency key (ou txid no PIX): retry do cliente cobra duas vezes'
    fi
  fi
done

if [ "$verificados" -eq 0 ]; then
  echo "check-pay: nenhum arquivo de texto para verificar em $raiz (exit 2: isto NÃO é aprovação)" >&2
  exit 2
fi
if [ "$achados" -gt 0 ]; then
  echo "check-pay: $achados achado(s) em $verificados arquivo(s)" >&2
  exit 1
fi
echo "check-pay: ok ($verificados arquivo(s) verificados)"
echo "check-pay: o gate é estático; ele não prova o fluxo em sandbox nem a conciliação (veja /pay-review)" >&2

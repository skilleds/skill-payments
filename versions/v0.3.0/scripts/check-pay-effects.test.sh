#!/usr/bin/env bash
# Vermelho->verde do gate check-pay-effects.sh (payments, piso 18: nunca cobra fora de prd).
# EXCEÇÃO DECLARADA (schematize-shell): harness `set -u` sem `-e` para reportar todos os casos.
set -u
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="$AQUI/check-pay-effects.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP:?}"' EXIT INT TERM
ok=0; fail=0; D=""; NOME=""
novo() { D="$TMP/$1"; mkdir -p "$D"; NOME="$1"; }
f() { mkdir -p "$(dirname "$D/$1")"; sed 's/@@LIVE@@/sk_live_/g' >"$D/$1"; }
esperar() {
  local esp="$1" agulha="$2" saida rc
  saida="$(bash "$G" "$D" 2>&1)"; rc=$?
  if [ "$rc" != "$esp" ]; then echo "  ✖ $NOME: exit $rc, esperado $esp"; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  if [ -n "$agulha" ] && ! grep -qF -- "$agulha" <<<"$saida"; then echo "  ✖ $NOME: saída sem \"$agulha\""; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  echo "  ✔ $NOME"; ok=$((ok+1))
}
echo "== gate external-effects (pay) =="
novo vazio; mkdir -p "$D"; esperar 2 "nenhum arquivo"

GW_OK='import os
ENV = os.environ.get("PAY_ENV", "dev")
CAP = int(os.environ.get("PAY_MAX_CHARGES_PER_RUN", "10"))
class SandboxGateway:
    def charge(self, cents): return {"id": "sbx"}
class RealGateway:
    def __init__(self):
        if ENV != "prd":
            raise PermissionError("gateway real recusa subir fora de prd")
    def charge(self, cents):
        return requests.post("https://psp.example/payments", json={"amount": cents}, headers={"Idempotency-Key": "k"})
def gateway():
    return RealGateway() if ENV == "prd" else SandboxGateway()
'
novo verde-gateway-guardado
printf '%s' "$GW_OK" | f src/gateway.py
esperar 0 "ok ("

novo vermelho-real-nos-dois-ramos
f src/gateway.py <<'FIX'
import os
ENV = os.environ.get("PAY_ENV")
CAP = os.environ.get("PAY_MAX_CHARGES_PER_RUN")
class RealGateway: pass
if ENV == "production":
    gw = RealGateway()
else:
    gw = RealGateway()
FIX
esperar 1 "pay-gateway-sem-guarda"

novo vermelho-cobranca-direta-sem-guard
f src/checkout.js <<'FIX'
await fetch(`${PSP}/payments`, { method: "POST", body: JSON.stringify({ amount }) });
FIX
esperar 1 "pay-gateway-sem-guarda"

novo vermelho-guard-so-em-comentario
f src/checkout.py <<'FIX'
# if ENV == "prd": raise PermissionError  PAY_MAX_CHARGES_PER_RUN Sandbox
requests.post(PSP + "/payments", json={})
FIX
esperar 1 "pay-gateway-sem-guarda"

novo vermelho-sem-cap
printf '%s' "$GW_OK" | grep -v PAY_MAX | f src/gateway.py
esperar 1 "pay-cobranca-sem-cap"

novo vermelho-default-prd
printf '%s' "$GW_OK" | sed 's/"PAY_ENV", "dev"/"PAY_ENV", "production"/' | f src/gateway.py
esperar 1 "pay-default-prd"

novo vermelho-lista-negra
printf '%s\n' "$GW_OK" 'def z(env):' '    if env != "dev": return RealGateway()' | f src/gateway.py
esperar 1 "pay-guard-nao-fail-closed"

novo vermelho-reprocesso-sem-dryrun
f scripts/reprocessar_cobrancas.py <<'FIX'
import requests
for c in pendentes:
    requests.post(PSP + "/payments", json=c)
FIX
esperar 1 "pay-script-sem-dryrun"

novo vermelho-chave-live-em-env-hml
f .env.hml <<'FIX'
PSP_API_KEY_PROD=abc
FIX
esperar 1 "pay-prd-em-nao-prd"

novo vermelho-host-prd-em-staging
f config/staging.yaml <<'FIX'
psp_url: https://api.cieloecommerce.cielo.com.br/1/sales
FIX
esperar 1 "pay-prd-em-nao-prd"

novo vermelho-chave-sem-marca-sandbox
f .env.dev <<'FIX'
PSP_API_KEY=9f8e7d6c5b4a
FIX
esperar 1 "pay-chave-nao-sandbox"

novo vermelho-waiver-nao-vale-em-env
f .env.dev <<'FIX'
# pay-ok: preciso
PSP_API_KEY_LIVE=abc
FIX
esperar 1 "pay-prd-em-nao-prd"

novo verde-chave-sandbox-em-env-dev
f .env.dev <<'FIX'
PSP_API_KEY=sandbox_9f8e7d
FIX
esperar 0 "ok ("

novo verde-reprocesso-com-dryrun
f scripts/reprocessar_cobrancas.py <<'FIX'
import sys
DRY_RUN = "--apply" not in sys.argv
for c in pendentes:
    print("faria", c) if DRY_RUN else None
FIX
esperar 0 "ok ("

echo "== $ok ok, $fail falha(s) =="
[ "$fail" -eq 0 ]

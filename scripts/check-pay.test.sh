#!/usr/bin/env bash
# Vermelho primeiro do gate check-pay.sh. Cada fixture é um mini-repo com UM defeito (vermelho)
# ou um uso correto parecido (verde plantado, que NÃO pode ser acusado).
#
# EXCEÇÃO DECLARADA (piso da schematize-shell, strict mode): harness de teste roda `set -u` sem `-e`
# — precisa continuar depois de um caso vermelho para reportar todos, em vez de parar no primeiro.
set -u
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="$AQUI/check-pay.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP:?}"' EXIT INT TERM
ok=0; fail=0
D=""; NOME=""

novo() { D="$TMP/$1"; mkdir -p "$D"; NOME="$1"; }
# f aplica marcadores: a chave de teste não pode existir literal no fonte (push protection do GitHub).
f() { mkdir -p "$(dirname "$D/$1")"; sed 's/@@LIVE@@/sk_live_/g; s/@@TEST@@/sk_test_/g; s/@@APP@@/APP_USR-/g' >"$D/$1"; }
esperar() {
  local esp="$1" agulha="$2" saida rc
  saida="$(bash "$G" "$D" 2>&1)"; rc=$?
  if [ "$rc" != "$esp" ]; then echo "  ✖ $NOME: exit $rc, esperado $esp"; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  if [ -n "$agulha" ] && ! grep -qF -- "$agulha" <<<"$saida"; then echo "  ✖ $NOME: exit certo, saída sem \"$agulha\""; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  echo "  ✔ $NOME"; ok=$((ok+1))
}
# nao_ter <agulha>: o caso verde não pode citar a regra.
esperar_sem() {
  local agulha="$1" saida
  saida="$(bash "$G" "$D" 2>&1)"
  if grep -qF -- "$agulha" <<<"$saida"; then echo "  ✖ $NOME: acusou \"$agulha\" indevidamente"; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  echo "  ✔ $NOME"; ok=$((ok+1))
}

echo "== gate pay =="

# ---------------- nada para verificar
novo vazio; mkdir -p "$D"
esperar 2 "nenhum arquivo"
novo dir-inexistente; D="$TMP/nao-existe"
esperar 2 "inexistente"

# ---------------- verde completo: tudo certo junto
novo verde-completo
f src/dinheiro.ts <<'FIX'
export type Money = { cents: number; currency: "BRL" };
export function somar(a: Money, b: Money): Money {
  return { cents: a.cents + b.cents, currency: a.currency };
}
FIX
f src/webhook.ts <<'FIX'
import { createHmac, timingSafeEqual } from "node:crypto";
export function handlerWebhook(req: Req) {
  const esperado = createHmac("sha256", process.env.WEBHOOK_SECRET!).update(req.rawBody).digest();
  if (!timingSafeEqual(esperado, Buffer.from(req.headers["x-signature"], "hex"))) throw new Error("assinatura");
  // dedupe por event_id: INSERT ... ON CONFLICT DO NOTHING
  return inserirEventoUnico(req.body.event_id);
}
FIX
f src/cobranca.ts <<'FIX'
export async function criarCobranca(c: Cliente, valorCentavos: number, chave: string) {
  return c.post("/payments", { amount: valorCentavos }, { headers: { "Idempotency-Key": chave } });
}
FIX
f config/env.ts <<'FIX'
const ambiente = process.env.APP_ENV ?? "dev";
export const cobrarDeVerdade = ambiente === "production";
FIX
f config/hml.env <<'FIX'
PSP_BASE_URL=https://sandbox.asaas.com/api/v3
PSP_KEY=sandbox_chave_de_teste
FIX
f src/logger.ts <<'FIX'
logger.info("pagamento autorizado", { token: tk, last4: "4242" });
FIX
esperar 0 "ok"

# ---------------- pay-float-dinheiro
novo float-ts
f src/p.ts <<'FIX'
const amount: number = parseFloat(req.body.amount);
FIX
esperar 1 "pay-float-dinheiro"
novo float-rust
f src/p.rs <<'FIX'
pub struct Charge { pub amount: f64, pub currency: String }
FIX
esperar 1 "pay-float-dinheiro"
novo float-go
f p.go <<'FIX'
type Cobranca struct { Valor float64 }
FIX
esperar 1 "pay-float-dinheiro"
novo float-sql
f db/001.sql <<'FIX'
CREATE TABLE cobranca (id bigint primary key, valor double precision NOT NULL);
FIX
esperar 1 "pay-float-dinheiro"
novo float-java
f P.java <<'FIX'
double totalPedido = 10.5;
FIX
esperar 1 "pay-float-dinheiro"
novo float-verde-inteiro
f p.rs <<'FIX'
pub struct Charge { pub amount_cents: i64, pub taxa_bps: u32, pub ratio: f64 }
FIX
esperar_sem "pay-float-dinheiro"
novo float-waiver
f p.rs <<'FIX'
// pay-ok: métrica de exibição, nunca entra em cálculo de saldo
let total_exibicao: f64 = 0.0;
FIX
esperar_sem "pay-float-dinheiro"
novo float-waiver-sem-motivo
f p.rs <<'FIX'
// pay-ok:
let total_exibicao: f64 = 0.0;
FIX
esperar 1 "pay-float-dinheiro"

# ---------------- pay-chave-live
novo chave-live-stripe
f src/k.ts <<'FIX'
const k = "@@LIVE@@51HxYzAbCdEfGhIjKlMnOpQrStUv";
FIX
esperar 1 "pay-chave-live"
novo chave-live-mp
f config.yaml <<'FIX'
token: @@APP@@1234567890123456-101010-abcdef0123456789abcdef0123456789-123456
FIX
esperar 1 "pay-chave-live"
novo chave-live-no-md
f docs/ops.md <<'FIX'
use @@LIVE@@4eC39HqLyjWDarjtT1zdp7dcAbCdEf para cobrar
FIX
esperar 1 "pay-chave-live"
novo chave-teste-verde
f src/k.ts <<'FIX'
const k = "@@TEST@@4eC39HqLyjWDarjtT1zdp7dc";
const exemplo = "@@LIVE@@xxx";
FIX
esperar_sem "pay-chave-live"

# ---------------- pay-prd-em-nao-prd
novo prd-em-hml-host
f config/hml.env <<'FIX'
PSP_BASE_URL=https://api.asaas.com/v3
FIX
esperar 1 "pay-prd-em-nao-prd"
novo prd-em-staging-yaml
f deploy/staging.yaml <<'FIX'
psp:
  url: https://pix.api.efipay.com.br
FIX
esperar 1 "pay-prd-em-nao-prd"
novo prd-em-test-credencial
f tests/setup.ts <<'FIX'
const key = process.env.PROD_KEY;
FIX
esperar 1 "pay-prd-em-nao-prd"
novo prd-em-prd-verde
f config/prd.env <<'FIX'
PSP_BASE_URL=https://api.asaas.com/v3
FIX
esperar_sem "pay-prd-em-nao-prd"
novo prd-host-extra
f config/dev.env <<'FIX'
PSP_BASE_URL=https://api.meupsp.com.br
FIX
PAY_PROD_HOSTS="api.meupsp.com.br" bash "$G" "$D" >"$TMP/o" 2>&1; rc=$?
if [ "$rc" = 1 ] && grep -q "pay-prd-em-nao-prd" "$TMP/o"; then echo "  ✔ prd-host-extra (PAY_PROD_HOSTS)"; ok=$((ok+1)); else echo "  ✖ prd-host-extra rc=$rc"; fail=$((fail+1)); fi

# ---------------- pay-default-prd
novo default-prd-js
f src/e.ts <<'FIX'
const ambiente = process.env.APP_ENV || "production";
FIX
esperar 1 "pay-default-prd"
novo default-prd-rust
f src/e.rs <<'FIX'
let env = std::env::var("APP_ENV").unwrap_or("prod".into());
FIX
esperar 1 "pay-default-prd"
novo default-prd-shell
f run.sh.env <<'FIX'
APP_ENV=${APP_ENV:-"production"}
FIX
esperar 1 "pay-default-prd"
novo default-prd-python
f e.py <<'FIX'
env = os.environ.get("APP_ENV", "prod")
FIX
esperar 1 "pay-default-prd"
novo default-dev-verde
f src/e.ts <<'FIX'
const ambiente = process.env.APP_ENV ?? "dev";
if (ambiente === "production") cobrar();
FIX
esperar_sem "pay-default-prd"

# ---------------- pay-webhook-sem-assinatura / dedupe
novo webhook-sem-assinatura
f src/hook.ts <<'FIX'
router.post("/webhooks/psp", async (req, res) => {
  const ev = req.body;
  await registrarEventoUnico(ev.event_id); // dedupe: ON CONFLICT
  await marcarPago(ev.paymentId);
});
FIX
esperar 1 "pay-webhook-sem-assinatura"
novo webhook-sem-dedupe
f src/hook.ts <<'FIX'
router.post("/webhooks/psp", async (req, res) => {
  verificarHmac(req); // hmac signature
  await marcarPago(req.body.paymentId);
});
FIX
esperar 1 "pay-webhook-sem-dedupe"
novo webhook-elixir
f lib/webhook_controller.ex <<'FIX'
defmodule PayWeb.WebhookController do
  def receber(conn, params) do
    Pay.marcar_pago(params["id"])
  end
end
FIX
esperar 1 "pay-webhook-sem-assinatura"
novo webhook-rust-mtls-verde
f src/webhook_handler.rs <<'FIX'
// webhook do PSP Pix: mTLS exigido no proxy (client cert verificado); dedupe por event_id
async fn webhook_handler(req: Req) { require_client_cert(&req)?; insert_event(req.event_id).await; }
FIX
esperar_sem "pay-webhook-"
novo webhook-em-teste-verde
f tests/webhook_test.ts <<'FIX'
router.post("/webhooks/psp", async (req, res) => { await marcarPago(req.body.paymentId); });
FIX
esperar_sem "pay-webhook-"
novo webhook-waiver
f src/hook.ts <<'FIX'
// pay-ok: handler de eco só em dev, atrás de feature flag desligada em prd
router.post("/webhooks/eco", async (req, res) => { res.json(req.body); });
FIX
esperar 1 "pay-webhook-sem-assinatura"   # waiver sem nomear a regra não cobre regra de arquivo inteiro
novo webhook-waiver-nomeado
f src/hook.ts <<'FIX'
// pay-ok: pay-webhook-sem-assinatura eco só em dev, atrás de flag desligada em prd
// pay-ok: pay-webhook-sem-dedupe eco não tem efeito financeiro
router.post("/webhooks/eco", async (req, res) => { res.json(req.body); });
FIX
esperar 0 "ok"

# ---------------- pay-cobranca-sem-idempotencia
novo cobranca-sem-idem
f src/c.ts <<'FIX'
export async function cobrar(c: Cliente, cents: number) {
  return c.post("/payments", { amount: cents });
}
FIX
esperar 1 "pay-cobranca-sem-idempotencia"
novo cobranca-py-sem-idem
f c.py <<'FIX'
def criar_cobranca(v):
    return requests.post(f"{BASE}/charges", json={"amount_cents": v})
FIX
esperar 1 "pay-cobranca-sem-idempotencia"
novo cobranca-com-idem-verde
f src/c.ts <<'FIX'
return c.post("/payments", body, { headers: { "Idempotency-Key": k } });
FIX
esperar_sem "pay-cobranca-sem-idempotencia"
novo cobranca-pix-txid-verde
f src/c.go <<'FIX'
func criarCob(txid string) { http.Post(base+"/cob/"+txid, "application/json", body) }
FIX
esperar_sem "pay-cobranca-sem-idempotencia"

# ---------------- pay-pan-em-log
novo pan-log-ts
f src/l.ts <<'FIX'
console.log("pagando com", card.number);
FIX
esperar 1 "pay-pan-em-log"
novo pan-log-python
f l.py <<'FIX'
logger.info("cvv recebido: %s", cvv)
FIX
esperar 1 "pay-pan-em-log"
novo pan-log-rust
f l.rs <<'FIX'
info!("cartao {}", card_number);
FIX
esperar 1 "pay-pan-em-log"
novo pan-log-verde
f l.ts <<'FIX'
logger.info("cartao tokenizado", { token, last4 });
const panelaDePressao = 1; console.log("panorama");
FIX
esperar_sem "pay-pan-em-log"

# ---------------- pay-pan-literal
novo pan-literal-real
f src/seed.ts <<'FIX'
const cartao = "4532015112830366";
FIX
esperar 1 "pay-pan-literal"
novo pan-literal-teste-publico-verde
f src/seed.ts <<'FIX'
const cartaoDeTeste = "4242424242424242";
const timestamp = 1699999999999;
const outro = "4532015112830367"; // Luhn inválido
FIX
esperar_sem "pay-pan-literal"

# ---------------- pay-pan-armazenado
novo pan-coluna-sql
f db/002.sql <<'FIX'
CREATE TABLE cartao (id bigint, card_number varchar(19), cvv varchar(4));
FIX
esperar 1 "pay-pan-armazenado"
novo pan-coluna-rails
f db/migrate/1.rb <<'FIX'
    t.string :cvv
FIX
esperar 1 "pay-pan-armazenado"
novo pan-coluna-ecto
f priv/m.exs <<'FIX'
add :card_number, :string
FIX
esperar 1 "pay-pan-armazenado"
novo pan-coluna-token-verde
f db/003.sql <<'FIX'
CREATE TABLE cartao (id bigint, psp_token text NOT NULL, last4 char(4), brand text);
FIX
esperar_sem "pay-pan-armazenado"

# ---------------- falsos verdes corrigidos (G8b)
novo webhook-assinatura-so-em-comentario
f src/hook.ts <<'FIX'
router.post("/webhooks/pix", async (req, res) => {
  // verifica hmac depois; unique no banco
  await db.paid(req.body.txid);
});
FIX
esperar 1 "pay-webhook-sem-assinatura"
novo cobranca-idempotency-so-em-comentario
f src/cobra.py <<'FIX'
psp.post("/payments", json={"amount": 10})  # idempotency
FIX
esperar 1 "pay-cobranca-sem-idempotencia"
novo literal-decimal-go
f src/preco.go <<'FIX'
price := 19.90
FIX
esperar 1 "pay-float-dinheiro"
novo literal-decimal-ts
f src/preco.ts <<'FIX'
const total = 19.9;
FIX
esperar 1 "pay-float-dinheiro"
novo literal-centavos-verde
f src/preco.go <<'FIX'
price := 1990
version := 1.5
FIX
esperar_sem "pay-float-dinheiro"
novo waiver-nao-vale-chave-live
f src/cfg.ts <<'FIX'
// pay-ok: so em teste
const k = "@@LIVE@@abcdefghijklmnop1234";
FIX
esperar 1 "pay-chave-live"
novo host-cielo-em-staging
f config/staging.yaml <<'FIX'
psp: https://api.cieloecommerce.cielo.com.br/1/sales
FIX
esperar 1 "pay-prd-em-nao-prd"

echo "== resultado: $ok ok, $fail falhas =="
[ "$fail" -eq 0 ]

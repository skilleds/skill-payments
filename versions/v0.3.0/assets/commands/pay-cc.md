---
description: schematize-payments — context compact: grava o handoff no archive e roda /compact.
---
Antes de compactar, **grave o handoff** em `<projeto>/<projeto>_archive/context/` no par
**context + checklist** do padrão da `schematize-archive` (prefixo `AAAA-MM-DD-<slug>-`), FEITO vs
ABERTO. Inclua: fluxos desenhados ou revisados, achados do `scripts/check-pay.sh` ainda abertos,
exceções (`pay-ok:`) declaradas com o motivo, decisões pendentes (PSP, arredondamento, fiscal) e o
que depende de humano. Nunca inclua chave de PSP, PAN, token ou dado pessoal. Só então rode `/compact`.

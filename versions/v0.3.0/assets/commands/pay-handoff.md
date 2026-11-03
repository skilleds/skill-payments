---
description: schematize-payments — gera o handoff (context.md + checklist.md) no archive, sem compactar.
---
Gere o handoff em `<projeto>/<projeto>_archive/context/`: `AAAA-MM-DD-<slug>-context.md` (o que foi
feito, decisões de PSP e de arredondamento, o que o gate acusou, estado dos fluxos) e
`AAAA-MM-DD-<slug>-checklist.md` (FEITO vs ABERTO, nas três classes da casa: `- [ ]` máquina ·
`- [H ]` humano · `- [~]` on-hold). Não compacte — só grave. Nunca grave chave de PSP, PAN, token de
cartão, CPF ou payload de webhook no handoff.

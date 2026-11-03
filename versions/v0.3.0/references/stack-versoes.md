# Anexo volátil — regras e versões de pagamentos (BR)

> Parte da skill **schematize-payments**. **Fonte volátil:** número de manual, data de vigência,
> norma e prazo mudam. O corpo normativo diz **princípio**; o número mora aqui, com fonte e data.
>
> **Verificado em: 2026-10-14.** Cadência: trimestral e antes de cada release. Método: busca web
> (WebSearch) com cruzamento entre fontes; **fonte primária (bcb.gov.br, pcisecuritystandards.org,
> nfse.gov.br) não foi aberta nesta rodada**, então toda linha abaixo é "relatado por veículo" e
> exige conferência antes de virar decisão contratual ou fiscal. Itens sem confirmação estão
> marcados com `<!-- reverificar -->` no corpo e listados em "Não verificado".

## PIX (Banco Central do Brasil)

| Fato | Valor relatado | Fonte (via busca) | Confiança |
|---|---|---|---|
| Manual de Padrões para Iniciação do Pix | versão **2.10.0**, publicada pela Instrução Normativa BCB nº 769, de 2026-08-19, que revoga a IN BCB nº 658, de 2025-09-05 | LegisWeb (IN BCB 769/2026) | média: não conferido no texto do BCB |
| Pix Automático | entrou em operação em **junho de 2025**; obrigatório para participantes em **outubro de 2025**; prazo de adequação de contratos em janeiro de 2026; nova expansão citada para julho de 2027 | Celcoin (blog), Fórum Pix (apresentação BCB, 2025-06-26) | média |
| Ajustes do Pix Automático | "ajustes pontuais" nas regras operacionais divulgados em 2026-09 | Agência Gov (2026-09) | média; ler a norma |
| MED 2.0 (Mecanismo Especial de Devolução) | obrigatório a partir de **2026-02-02**; a norma-base aparece como Resolução BCB nº 482/2025 (Fórum Pix) ou nº 493/2025 (blog): **divergência** | Agência Brasil (2026-02), Fórum Pix | média-baixa na norma |
| Manual Operacional do DICT | versão **8.2** (IN BCB 722/2026): endpoints antigos de infração descontinuados, contestação de fraude centralizada no Fluxo de Recuperação de Valores | agregador (cadoc.ai) | baixa-média |
| Resolução BCB nº 587/2026 (Pix Automático em conta-salário) | citada por um agregador | não verificada em fonte primária | baixa |

## Cartão — PCI DSS

| Fato | Valor relatado | Fonte | Confiança |
|---|---|---|---|
| Versão vigente | **PCI DSS v4.0.1**; requisitos "futuros" de 4.0 tornaram-se obrigatórios em **2025-03-31** | Akamai, Jscrambler, Compass IT (blogs) | média-alta |
| SAQ A revisado | publicado em **janeiro de 2025**: 6.4.3, 11.6.1 e a análise de risco 12.3.1 saíram do questionário e entrou **critério de elegibilidade** (site não suscetível a ataque de script: controles próprios ou confirmação escrita do PSP); não se aplica a redirect total | Akamai, Reflectiz, Adyen (docs de elegibilidade) | média-alta; texto exato no SAQ A do PCI SSC |
| 6.4.3 / 11.6.1 | continuam obrigatórios para SAQ A-EP, SAQ D e provedores de serviço | Jscrambler, Compass IT | média-alta |

## Fiscal

| Fato | Valor relatado | Fonte | Confiança |
|---|---|---|---|
| NFS-e padrão nacional | LC 214/2025 estabelece o padrão nacional para os municípios a partir de **2026-01-01**; leiaute com campos de IBS e CBS | MRS Advogados, CRCSP | média |
| Prazo para ME/EPP do Simples Nacional | **2026-09-01** (Contábeis) ou prorrogado para **2026-11-01** pela Resolução CGSN nº 191/2026 (Tecnospeed): a segunda é a mais recente, **conferir no texto oficial** | Contábeis, Tecnospeed | baixa |
| MEI | NFS-e nacional obrigatória para serviço a pessoa jurídica desde 2023-09 | ContaAzul | média |
| IBS/CBS nas notas | campos devem constar; ausência não impede a autorização no início | CRCSP, Tecnospeed | média |

## PSPs e provedores

Versões de API e SDK de PSPs (Efí, Asaas, Mercado Pago, Pagar.me, Stripe, Adyen e outros),
suporte a Pix Automático por PSP, janelas de liquidação e taxas **não foram verificados** nesta
rodada <!-- reverificar -->. Regra: **consulte a documentação do PSP escolhido antes de codar**
e registre versão da API e data no ADR do PSP.

## Faltou verificar

- Texto primário das normas do BCB (IN 769/2026, resoluções do MED 2.0 e do Pix Automático).
- Prazo e valor máximo da devolução Pix vigentes; prazos de envio/retentativa do Pix Automático.
- Janela de liquidação de boleto (D+0/D+1) e regras da plataforma de cobrança vigentes.
- Regras de liability shift do 3-D Secure por bandeira no Brasil.
- Cronograma definitivo da NFS-e nacional por tipo de contribuinte e a NT de IBS/CBS da NF-e.
- Qualquer versão de API de PSP.

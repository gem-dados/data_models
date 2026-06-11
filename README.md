# data_models — Transformações SQL (Dataform)

Modelos do data lake `gem-dados` em **Dataform**: transformam os dados crus
(camada `raw`, gravada pelo [`data_ingestion`](https://github.com/gem-dados/data_ingestion))
em `staging` e `marts` dentro do **BigQuery**.

> O repositório Dataform no GCP é criado pelo [`cloud_iac`](https://github.com/gem-dados/cloud_iac).
> Aqui ficam apenas as definições SQL.

---

## Camadas

```
raw  (data_ingestion)  ──►  staging (views, limpeza)  ──►  marts (tabelas finais)
   declaration                  stg_*.sqlx                    mart_*.sqlx
```

| Pasta | Camada | Tipo | Para quê |
|---|---|---|---|
| `definitions/sources/` | raw | `declaration` | registra tabelas cruas existentes |
| `definitions/staging/` | staging | `view` | limpeza/normalização + assertions |
| `definitions/marts/` | marts | `table` | modelos finais para consumo |

Materialização por ambiente: o **mesmo código** roda contra
`gem-dados-lake-stg` ou `gem-dados-lake-prd` trocando o `defaultProject`
(via execução do Dataform / variável).

---

## Estrutura

```
data_models/
├── workflow_settings.yaml      # config do Dataform Core (projeto, location, datasets)
├── definitions/
│   ├── sources/raw_example.sqlx
│   ├── staging/stg_example.sqlx
│   └── marts/mart_example.sqlx
├── includes/                   # funções JS reutilizáveis (opcional)
├── .pre-commit-config.yaml     # gitleaks + checagens
└── .gitignore
```

---

## Desenvolver

**Recomendado:** workspace do Dataform no Console GCP (ligado a este repo pelo
`cloud_iac`) — compila e roda contra o BigQuery sem setup local.

**CLI local** (opcional):
```bash
npm i -g @dataform/cli
dataform compile
dataform run --dry-run        # valida sem materializar
```

> A credencial local fica em `.df-credentials.json` — **já está no
> `.gitignore`**. Nunca commite.

---

## Criar um modelo novo

1. Fonte nova? Declare em `definitions/sources/`.
2. Crie a view de `staging/` referenciando a fonte com `${ref("nome")}`.
3. Crie a tabela de `marts/` agregando o staging.
4. Adicione **assertions** (nonNull, uniqueKey) para qualidade.
5. PR → valida em `stg` → PR para `main` (prd).

---

## Segurança

- `pre-commit` com **gitleaks** (anti-segredo) — `pip install pre-commit && pre-commit install`.
- `.df-credentials.json` e chaves nunca vão para o git.
- Sem credenciais nos `.sqlx`: o acesso ao BigQuery é da SA do Dataform.

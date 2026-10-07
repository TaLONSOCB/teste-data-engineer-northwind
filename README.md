# Teste Técnico — Data Engineer · Northwind em arquitetura medalhão

Pipeline de ponta a ponta sobre a base Northwind: ingestão com **Apache Hop**
(Bronze), transformação com **dbt** (Silver e Gold), testes de qualidade e
documentação. Destino: **Google BigQuery**.

```
PostgreSQL (Northwind)            Google BigQuery — conjunto northwind_arruda
┌──────────────────┐  Apache Hop  ┌────────────┐   dbt    ┌────────────┐   dbt    ┌───────────────┐
│ customers        │ ───────────▶ │  BRONZE    │ ───────▶ │  SILVER    │ ───────▶ │  GOLD         │
│ orders           │  cópia fiel  │  raw_*     │  limpeza │  stg_*     │ modelo   │  ft_vendas    │
│ order_details    │              │ (tabelas)  │  tipagem │  (views)   │ dimens.  │  dm_cliente   │
│ products         │              │            │  nomes   │            │          │  dm_produto   │
└──────────────────┘              └────────────┘          └────────────┘          │  dm_calendario│
                                                                                   └───────────────┘
```

## Estrutura do repositório

| Caminho | Conteúdo |
|---|---|
| `hop/` | Projeto do Apache Hop: `bronze_main.hpl` (orquestra), `bronze_load.hpl` (carga genérica) e as conexões em `metadata/` |
| `northwind/` | Projeto dbt: fontes (Bronze), modelos `stg_` (Silver), `dm_`/`ft_` (Gold), testes e macros |
| `sql/bronze_ddl.sql` | DDL de referência das tabelas `raw_` |
| `run.sh` | Orquestração: ingestão → testes → transformação → documentação |
| `docs/erros-e-solucoes.md` | Diário dos erros encontrados no caminho, com causa e solução |

## Como executar

### Pré-requisitos

- Docker e docker-compose (origem)
- Apache Hop 2.19 e Java 17+
- Python 3.9+ 
- Um projeto no Google Cloud com BigQuery e uma conta de serviço com os papéis
  de administrador do BigQuery (ou *Job User* + *Data Editor*), com a chave JSON baixada

### 1. Subir a origem

```bash
git clone https://github.com/pthom/northwind_psql.git
cd northwind_psql && docker-compose up -d
```

O PostgreSQL fica em `localhost:55432` (banco `northwind`, usuário e senha `postgres`).

> Se o contêiner `db` não subir (erro `in 18+, these Docker images...` em
> `docker-compose logs db`), fixe `image: postgres:16` no serviço `db` do
> `docker-compose.yml`, rode `docker-compose down -v` e suba de novo.

### 2. Instalar o driver do BigQuery no Hop

O Hop não traz o driver JDBC do BigQuery. Baixe o driver Simba (JDBC 4.2) em
<https://cloud.google.com/bigquery/docs/reference/odbc-jdbc-drivers> e copie para
`$HOP_HOME/lib/jdbc/` apenas estes arquivos do zip:

```
GoogleBigQueryJDBC42.jar  api-common-*.jar  gax-*.jar  json-*.jar  threetenbp-*.jar
google-api-services-bigquery-v2-*.jar  google-cloud-bigquerystorage-*.jar
grpc-google-cloud-bigquerystorage-*.jar  proto-google-cloud-bigquerystorage-*.jar
```

Não copie `grpc-alts`, `grpc-api`, `grpc-core` e `grpc-netty-shaded`: conflitam com
as bibliotecas do próprio Hop. Também não misture com o driver
`google-cloud-bigquery-jdbc-*-all.jar` na mesma pasta.

### 3. Instalar o dbt

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install "dbt-core>=1.9,<1.10" "dbt-bigquery>=1.9,<1.10"
```

### 4. Configurar

```bash
export HOP_HOME=/caminho/para/hop
export DBT_KEYFILE=/caminho/para/chave-da-conta-de-servico.json
```

Projeto, conjunto de dados e região estão em dois lugares, e devem ser ajustados
se você não usar os meus: `northwind/profiles.yml` (dbt) e `hop/project-config.json` (Hop).
A chave nunca é versionada: o caminho dela entra só por variável de ambiente.

### 5. Rodar tudo

```bash
./run.sh
```

| Etapa | Comando executado | O que faz |
|---|---|---|
| 0 | `dbt run-operation criar_tabelas_bronze` | Garante o conjunto de dados e as tabelas `raw_` |
| 1 | `hop-run.sh ... bronze_main.hpl` | Ingestão das 4 tabelas (Bronze) |
| 2 | `dbt test --select "source:*"` | Valida a ingestão antes de transformar |
| 3 | `dbt run` | Constrói Silver e Gold |
| 4 | `dbt test --exclude "source:*"` | Testa Silver e Gold |
| 5 | `dbt docs generate` | Gera a documentação |

Para navegar na documentação e no grafo de dependências: `cd northwind && dbt docs serve`.

> Na primeira execução em um ambiente novo, as tabelas `raw_` acabam de ser criadas
> e a API de gravação do BigQuery pode levar alguns minutos para enxergá-las
> (erro `NOT_FOUND` na etapa 1). Basta rodar de novo.

## Decisões tomadas

### Bronze (Apache Hop)

- **Carga orientada a metadados.** Um único pipeline genérico (`bronze_load`),
  parametrizado por `TABLE_NAME`, lê `SELECT * FROM ${TABLE_NAME}` e grava em
  `raw_${TABLE_NAME}`. O `bronze_main` percorre uma lista de tabelas e chama o
  genérico para cada uma. Incluir uma tabela nova é acrescentar uma linha na lista.
- **Cópia fiel, sem regra de negócio.** Mesmas colunas e mesmos nomes da origem.
- **Idempotência.** Cada carga faz `TRUNCATE` da tabela de destino antes de gravar;
  reexecutar não duplica dados. Carga completa é adequada ao volume (cerca de 3 mil linhas).
- **Conexão genérica com o driver Simba.** O transform *Table output* do Hop recusa
  conexões do tipo "Google BigQuery". A gravação usa uma conexão genérica com o mesmo
  driver, com sessão (`EnableSession=1`, exigida pelo controle de transação do Hop) e
  Storage Write API (`EnableWriteAPI=1`). Sem a Write API o driver envia um `INSERT`
  por linha: a carga de 91 clientes levava 3,5 minutos e passou a levar 5 segundos.
- **Datas como `DATETIME` na Bronze.** A Write API não aceita, em colunas `DATE`, o
  formato de data com hora que o Hop envia. As três datas de `raw_orders` ficam como
  `DATETIME` (sempre à meia-noite) e são convertidas para `DATE` na Silver. É o único
  desvio de tipo em relação à origem.

### Silver (dbt)

- **Um modelo `stg_` por tabela, materializado como view**: sempre reflete a Bronze
  atual e não ocupa armazenamento.
- **Nomes de negócio em português** (`id_cliente`, `data_pedido`, `valor_frete`...).
- **A Silver não inventa valores.** Campos opcionais não preenchidos continuam `NULL`;
  textos são aparados e texto vazio vira `NULL`.
- **Valores monetários e percentuais em `NUMERIC`**, não em ponto flutuante, para que
  as somas da Gold sejam exatas.

### Gold (dbt)

- **`ft_vendas` no grão de item do pedido**, com chaves para cliente, produto e data
  do pedido. Métricas: `valor_bruto = preço × quantidade`,
  `valor_desconto = valor_bruto × percentual` (arredondado a centavos) e
  `valor_liquido = valor_bruto − valor_desconto`.
- **Frete fora da fato.** O frete pertence ao pedido, não ao item; trazê-lo para este
  grão duplicaria o valor a cada item.
- **Preço de venda × preço de tabela.** A fato usa o preço praticado no item; o preço
  de tabela atual fica na `dm_produto`. Eles diferem em parte das vendas, o que é esperado.
- **Chaves naturais nas dimensões.** A origem não guarda histórico de alterações, então
  chaves substitutas não agregariam nada neste escopo.
- **"Não informado" nas dimensões.** Atributos nulos recebem um rótulo explícito na
  Gold para não sumirem de filtros e agrupamentos nas ferramentas de análise.
- **`dm_calendario` gerada no dbt** com `GENERATE_DATE_ARRAY`, cobrindo os anos
  completos entre o primeiro e o último pedido (1996 a 1998), para que análises por
  trimestre e ano não fiquem truncadas.
- **Tudo em um conjunto de dados**, separado por prefixo (`raw_`, `stg_`, `dm_`, `ft_`),
  como no enunciado.

## Inconsistências encontradas e tratamento

O perfil dos dados foi feito sobre a Bronze antes de modelar. A base é íntegra na
estrutura — sem chaves duplicadas, sem registros órfãos, sem quantidades ou preços
negativos — e os problemas encontrados são de preenchimento e de tipo:

| # | Achado | Ocorrências | Tratamento |
|---|---|---|---|
| 1 | Região do cliente não preenchida | 60 de 91 clientes | Campo opcional (muitos países não usam). `NULL` na Silver; "Não informado" na `dm_cliente` |
| 2 | Fax e CEP do cliente não preenchidos | 22 e 1 | Mantidos `NULL` na Silver |
| 3 | Pedidos sem data de envio | 21 de 830 | São os pedidos mais recentes, ainda não enviados. Data mantida `NULL` (inventar uma data distorceria prazos) e indicador `pedido_enviado` criado |
| 4 | Região e CEP de entrega não preenchidos | 507 e 19 pedidos | Mantidos `NULL` na Silver |
| 5 | Clientes sem nenhum pedido | 2 | Mantidos na `dm_cliente`: a dimensão descreve todos os clientes, não só os que compraram |
| 6 | Preço, desconto e frete em ponto flutuante (`real`) | todas as linhas | Convertidos para `NUMERIC` e arredondados |
| 7 | `discontinued` como inteiro 0/1 | 77 produtos | Convertido para `BOOL`, mais o atributo `situacao` na `dm_produto` |
| 8 | Datas como `DATETIME` na Bronze | 830 pedidos | Convertidas para `DATE` na Silver |
| 9 | Pedidos enviados depois do prazo | 37 | Não é erro de dado, é fato de negócio. Sem tratamento; registrado aqui |

## Qualidade

94 verificações no total (`dbt build`): 86 testes de dados sobre 8 modelos.

- **Nativos:** `not_null` e `unique` nas chaves; `relationships` entre as fontes, entre
  os modelos da Silver e da fato para as três dimensões; `accepted_values` em domínios fechados.
- **Genéricos customizados** (`northwind/tests/generic/`): `nao_negativo`,
  `entre_zero_e_um` e `chave_composta_unica` (garante o grão de `stg_order_details`).
- **Singulares customizados** (`northwind/tests/`):
  - `assert_ft_vendas_reconcilia_com_bronze` — a fato tem as mesmas linhas e o mesmo
    valor bruto total da Bronze (nada perdido ou duplicado nos joins);
  - `assert_valores_da_venda_consistentes` — líquido = bruto − desconto, sem negativos;
  - `assert_calendario_sem_lacunas` — um registro por dia, sem buracos;
  - `assert_envio_nao_antecede_pedido`.
- **Testes nas fontes** rodam antes da transformação, para barrar uma ingestão ruim.

Todas as tabelas e colunas da Silver e da Gold têm descrição (`silver.yml`, `gold.yml`).

## Erros encontrados no caminho

Registrei em [`docs/erros-e-solucoes.md`](docs/erros-e-solucoes.md) os 21 erros
que apareceram durante a construção, com a causa e a solução de cada um. Os que
mais influenciaram o desenho final:

- o *Table output* do Hop recusa conexões do tipo BigQuery, o que levou à conexão genérica;
- transações do BigQuery exigem sessão (`EnableSession=1`) e região explícita (`Location`);
- a carga linha a linha era inviável (3,5 min para 91 linhas) e passou a 5 s com a Storage Write API;
- a Write API não aceita o formato de data do Hop em colunas `DATE`, daí o `DATETIME` na Bronze.

## O que eu faria com mais tempo

- **Carga incremental** na Bronze e modelos incrementais no dbt, em vez de carga completa.
- **Chaves substitutas e histórico (SCD tipo 2)** nas dimensões, com snapshots do dbt.
- **Mais dimensões e fatos:** categoria, fornecedor, funcionário e transportadora (fora
  das 4 tabelas do teste) e uma fato de pedidos com frete e atraso de entrega.
- **Carga em lote por arquivo** (extração para Parquet + *load job*) no lugar do JDBC,
  que é o padrão recomendado para volumes maiores no BigQuery.
- **Conjuntos de dados separados por camada**, com permissões distintas.
- **Orquestrador de verdade** (Airflow ou workflow do Hop) com agendamento, novas
  tentativas e alertas, no lugar do `run.sh`.
- **Hop e dbt em contêineres**, para o ambiente todo subir com um `docker-compose up`.
- **CI** rodando `dbt build` a cada alteração, e `source freshness` para monitorar a ingestão.
- **Atualizar Python e dbt** para as versões correntes (usei dbt 1.9 pela compatibilidade
  com o Python 3.9 do ambiente).

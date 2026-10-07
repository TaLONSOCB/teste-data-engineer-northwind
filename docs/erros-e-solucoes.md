# Diário de erros e soluções

Registro, em ordem cronológica, dos erros encontrados durante a construção do
projeto, da causa de cada um e de como foi resolvido. Serve como memória do
passo a passo e como guia para quem for reproduzir o ambiente.

Ambiente: macOS (Apple Silicon), Docker Desktop, Apache Hop 2.19.0, driver
Simba JDBC para BigQuery 1.8.1, Python 3.9.6, dbt-core 1.9.11.

## Resumo

| # | Etapa | Erro | Causa | Solução |
|---|---|---|---|---|
| 1 | Origem | `Connection refused` na porta 55432 | Imagem `postgres` mais recente (18) incompatível com o volume do compose | Fixar `image: postgres:16` |
| 2 | Origem | pgAdmin: `superuser password is not specified` | Linha `image` colada no bloco errado do YAML | Corrigir a indentação do compose |
| 3 | Hop → BigQuery | `No suitable driver found for jdbc:bigquery://Parameter Value...` | Cabeçalho da tabela da documentação colado nas opções | Usar só o campo *Manual connection URL* |
| 4 | Hop → BigQuery | Conexão apontava para projeto inexistente | Nome do conjunto de dados no campo *Database name* | O campo recebe o ID do projeto |
| 5 | Hop → BigQuery | Botão *Test* não reagia (`NoSuchMethodError`) | Dois drivers do BigQuery na mesma pasta | Deixar só o Simba e suas dependências |
| 6 | Hop → BigQuery | `403 ... bigquery.jobs.create` | Papel preso a uma conta de serviço excluída | Conceder o papel à conta recriada |
| 7 | Hop → PostgreSQL | `password authentication failed for user "localhost"` | Valores digitados nos campos errados | Reposicionar host e usuário |
| 8 | Pipeline | `Not receiving any fields from previous transforms` | Transforms sem ligação | Criar o hop entre eles |
| 9 | Pipeline | `Could not load SQL from file` | Consulta digitada no campo de arquivo | Colar a consulta na caixa de SQL |
| 10 | Pipeline | `does not support regular DDL statements` | *Table output* bloqueia conexões do tipo BigQuery | Conexão do tipo *Generic database* |
| 11 | Pipeline | `Transaction control statements are supported only in scripts or sessions` | Hop abre transação; BigQuery só aceita em sessão | `EnableSession=1` na URL |
| 12 | Pipeline | `Dataset ... was not found in location US` | Sessão aberta na região padrão | `Location=southamerica-east1` na URL |
| 13 | Pipeline | Carga de 91 linhas em 3 min 34 s | Um `INSERT` (um job) por linha | Storage Write API (`EnableWriteAPI=1`) |
| 14 | Pipeline | Parâmetros da URL sem efeito | Espaços no meio da URL | Remover os espaços |
| 15 | Pipeline | Transform errado para o `TRUNCATE` | *Execute row SQL script* no lugar de *Execute SQL script* | Trocar o transform |
| 16 | Pipeline | `syntax error at or near "$"` | Substituição de variáveis desligada no *Table input* | Marcar *Replace variables in script* |
| 17 | Pipeline | `Append serialization failed` em `orders` | Colunas `DATE` não aceitam data com hora pela Write API | Colunas `DATETIME` na Bronze |
| 18 | Pipeline | `NOT_FOUND: Requested entity was not found` | Tabela recém-recriada ainda não propagada | Aguardar alguns minutos |
| 19 | dbt | `python3` pedia a licença do Xcode | Licença das ferramentas da Apple não aceita | Aceitar a licença |
| 20 | dbt | Instalou `dbt-core 2.0.0-alpha` | Versões estáveis novas exigem Python mais recente | Fixar a linha 1.9 |
| 21 | dbt | Muitos avisos a cada comando | Python 3.9 fora de suporte | `PYTHONWARNINGS=ignore` |

## Detalhes

### Origem (PostgreSQL em Docker)

**1. `connection to server at "127.0.0.1", port 55432 failed: Connection refused`**

O contêiner `db` não subia. O log (`docker-compose logs db`) mostrava:
`Error: in 18+, these Docker images are configured to store database data in a format which is compatible with "pg_ctlcluster"`.
O `docker-compose.yml` do repositório de origem não fixa a versão da imagem; ao
baixar a mais recente (PostgreSQL 18), o ponto de montagem do volume
(`/var/lib/postgresql/data`) deixa de ser compatível.

Solução: fixar `image: postgres:16` no serviço `db`, apagar os volumes da
tentativa anterior com `docker-compose down -v` e subir de novo.

**2. pgAdmin: `Database is uninitialized and superuser password is not specified`**

Ao editar o compose, a linha `image: postgres:16` foi parar no bloco do serviço
`pgadmin`, que passou a tentar subir um PostgreSQL sem senha. YAML depende da
indentação: a linha precisa estar dentro do bloco `db`.

### Conexão do Hop com o BigQuery

**3. `No suitable driver found for jdbc:bigquery://Parameter Value OAuthType 0 ...`**

Os parâmetros foram copiados da tabela da documentação junto com o cabeçalho
("Parameter", "Value") para a aba *Options*, o que corrompeu a URL montada pelo
Hop. Solução: limpar a aba *Options*, deixar os campos da aba *General* vazios e
informar a URL completa no campo *Manual connection URL*.

**4. Conjunto de dados no campo *Database name***

O campo estava com `northwind_arruda` (o conjunto de dados). O Hop usa esse campo
como `ProjectId`, então a conexão apontava para um projeto que não existe. O
conjunto de dados não faz parte da conexão: é informado como *schema* no pipeline.
Outro detalhe: renomear um projeto no Google Cloud muda só o nome de exibição; o
ID (`rruda-data-test`) é permanente e é ele que vale.

**5. Botão *Test* sem nenhuma reação**

Nem sucesso, nem erro na tela. O erro só aparecia no terminal de onde o Hop foi
iniciado (`./hop-gui.sh`):
`java.lang.NoSuchMethodError: 'void com.google.api.services.bigquery.Bigquery$Builder.<init>(...)'`.
Havia dois drivers em `lib/jdbc`: `google-cloud-bigquery-jdbc-1.4.0-all.jar` e o
Simba (`GoogleBigQueryJDBC42.jar`). O Simba carregava classes de dentro do
primeiro, incompatíveis com ele.

Solução: tirar o `...-all.jar` da pasta e copiar do zip do Simba apenas as
dependências listadas na documentação do Hop, sem os arquivos `grpc-alts`,
`grpc-api`, `grpc-core` e `grpc-netty-shaded`, que conflitam com o Hop.

Lição: quando a interface do Hop não mostra nada, o erro está no terminal.

**6. `403 Forbidden ... User does not have bigquery.jobs.create permission`**

A conta de serviço autenticava, mas não tinha permissão. Na tela de IAM, o papel
"Administrador do BigQuery" aparecia ligado a
`hop-service-account@...?uid=1142...`, com ícone riscado: é como o Google mostra
uma conta **excluída**. A conta tinha sido apagada e recriada com o mesmo e-mail;
para o Google são identidades diferentes, e a nova não herdou o papel.

Solução: *Permitir acesso* → informar o e-mail da conta → atribuir o papel de novo.

### Conexão do Hop com o PostgreSQL

**7. `FATAL: password authentication failed for user "localhost"`**

`localhost` foi digitado no campo *Username* em vez de *Server host name*.

### Pipeline da Bronze

**8. `Not receiving any fields from previous transforms`**

O *Table output* não estava ligado ao *Table input*. A ligação (hop) é criada
arrastando de um transform ao outro com a tecla Shift pressionada.

**9. `Could not load SQL from file: SELECT * FROM customers`**

A consulta foi digitada no campo de nome de arquivo do *Table input*, e o Hop
tentou abrir um arquivo com esse nome. A consulta vai na caixa de texto de SQL.

**10. `The Simba driver for a Google Big Query database connection does not support regular DDL statements. Please use the GBQ Bulk Loader transform to create your table.`**

A primeira hipótese foi a opção *Truncate table*; desmarcá-la não resolveu. A
causa real está no código do Hop: o tipo de conexão "Google BigQuery" declara que
não suporta o *Table output*, e o transform se recusa a iniciar com essa mensagem
fixa, quaisquer que sejam as opções. O "GBQ Bulk Loader" citado não existe no Hop.

Solução: criar uma segunda conexão do tipo *Generic database*, com a classe
`com.simba.googlebigquery.jdbc42.Driver` e a mesma URL. O projeto ficou com duas
conexões para o BigQuery: `BQ` (tipo nativo, usada para executar SQL) e
`BQ_generic` (usada pelo *Table output*).

Consequência: a opção *Truncate table* do *Table output* não é usada. A limpeza é
feita por um transform *Execute SQL script* com
`TRUNCATE TABLE ${BQ_DATASET}.raw_${TABLE_NAME}`.

**11. `Transaction control statements are supported only in scripts or sessions`**

Com *Commit size* maior que zero, o Hop desliga o autocommit e o driver tenta
abrir uma transação; o BigQuery só aceita transações dentro de uma sessão.
Solução: `EnableSession=1` na URL.

**12. `Not found: Dataset rruda-data-test:northwind_arruda was not found in location US`**

A sessão era aberta na região padrão (US), e o conjunto de dados está em
`southamerica-east1`. Solução: `Location=southamerica-east1` na URL.

**13. Carga muito lenta: 91 linhas em 3 min 34 s**

Funcionava, mas a cerca de 2,3 segundos por linha, porque o driver enviava cada
`INSERT` como um job separado. Nesse ritmo `order_details` (2.155 linhas) levaria
perto de 1 h 25 min.

Solução: ativar a Storage Write API do driver com
`EnableWriteAPI=1;SWA_ActivationRowCount=1;SWA_AppendRowCount=1000;`.
A mesma carga passou a levar 5 segundos; as quatro tabelas, 33 segundos.

**14. Os parâmetros da Write API não surtiram efeito na primeira tentativa**

Ao colar, ficaram três espaços entre `Location=southamerica-east1;` e
`EnableWriteAPI=1`. O driver não reconheceu o nome do parâmetro e o ignorou sem
avisar. A URL não pode ter espaços.

**15. Transform errado para o `TRUNCATE`**

Foi adicionado o *Execute row SQL script*, que espera o SQL vindo de uma coluna
de dados. O correto é o *Execute SQL script*, solto no pipeline (sem hop): assim
ele roda uma única vez na inicialização, antes de as linhas começarem a fluir.

**16. `ERROR: syntax error at or near "$"`**

O PostgreSQL recebeu o texto literal `SELECT * FROM ${TABLE_NAME}`. Faltava
marcar *Replace variables in script* no *Table input*.

**17. `INVALID_ARGUMENT: Append serialization failed for writer` (tabela `orders`)**

`customers` carregava e `orders` não. A diferença eram as colunas de data: o Hop
envia datas sempre com hora (`1996-07-04 00:00:00`), formato que a Write API não
aceita em colunas `DATE`.

Solução: recriar `raw_orders` com as três datas como `DATETIME`. A conversão para
`DATE` é feita na Silver (`stg_orders`). As tabelas sem datas (`order_details` e
`products`) carregaram sem ajuste, o que confirmou o diagnóstico.

**18. `io.grpc.StatusRuntimeException: NOT_FOUND: Requested entity was not found`**

Logo depois de apagar e recriar `raw_orders`. A tabela existia (o `TRUNCATE` do
mesmo pipeline funcionava), mas a Write API leva alguns minutos para enxergar uma
tabela recém-recriada com o mesmo nome. Solução: aguardar e rodar de novo.

### dbt

**19. `You have not agreed to the Xcode and Apple SDKs license`**

O `python3` do macOS vem das ferramentas de linha de comando da Apple e só roda
depois que a licença é aceita (Enter, avançar até o fim e digitar `agree`).

**20. `pip install dbt-bigquery` instalou `dbt-core 2.0.0-alpha.5`**

As versões estáveis mais novas do dbt exigem um Python mais recente que o 3.9 do
sistema; o `pip` acabou resolvendo para uma pré-versão. Solução: fixar a linha
estável compatível:
`pip install "dbt-core>=1.9,<1.10" "dbt-bigquery>=1.9,<1.10"`.

**21. Dezenas de avisos (`FutureWarning`, `NotOpenSSLWarning`) a cada comando**

São avisos das bibliotecas do Google sobre o Python 3.9 estar fora de suporte, não
erros. Para silenciar: `export PYTHONWARNINGS="ignore"`. A solução definitiva é
atualizar o Python e, com ele, o dbt.

## Lições

- Ler o log do terminal antes de mexer na interface: quase todos os erros do Hop
  estavam explicados ali.
- Testar com a menor tabela primeiro (`customers`, 91 linhas) e só então generalizar.
- Mudar uma coisa por vez e repetir o teste: os erros 10 a 18 estavam empilhados, e
  cada correção revelou o seguinte.
- Fixar versões (imagem do PostgreSQL, dbt): "a mais recente" quebrou duas vezes.

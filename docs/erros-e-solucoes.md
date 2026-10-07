# Erros que tive no caminho e como resolvi

Aqui eu anotei, na ordem em que foram aparecendo, os erros que tive enquanto montava o projeto, o que estava causando cada um e o que eu fiz para resolver. Serve para eu lembrar do passo a passo e para ajudar quem for montar o mesmo ambiente.

Meu ambiente: MacBook (Apple Silicon), Docker Desktop, Apache Hop 2.19.0, driver Simba 1.8.1 para o BigQuery, Python 3.9.6 e dbt-core 1.9.11.

## Resumo

| # | Onde | Erro | Causa | Como resolvi |
|---|---|---|---|---|
| 1 | Origem | `Connection refused` na porta 55432 | O compose baixou o PostgreSQL 18, incompatível com o volume | Fixei `image: postgres:16` |
| 2 | Origem | pgAdmin pedindo senha de superusuário | Colei a linha da imagem no bloco errado do YAML | Corrigi a indentação |
| 3 | Conexão BigQuery | `No suitable driver found for jdbc:bigquery://Parameter Value...` | Colei o cabeçalho da tabela da documentação junto com os parâmetros | Passei a usar só a URL manual |
| 4 | Conexão BigQuery | Conexão apontando para projeto que não existe | Coloquei o conjunto de dados no campo Database name | Esse campo é o ID do projeto |
| 5 | Conexão BigQuery | Botão Test não fazia nada | Dois drivers do BigQuery na mesma pasta | Deixei só o Simba |
| 6 | Conexão BigQuery | `403 ... bigquery.jobs.create` | O papel estava na conta de serviço antiga, que eu tinha excluído | Dei o papel de novo para a conta nova |
| 7 | Conexão PostgreSQL | `password authentication failed for user "localhost"` | Digitei os valores nos campos errados | Corrigi os campos |
| 8 | Pipeline | `Not receiving any fields from previous transforms` | Os dois transforms não estavam ligados | Criei a ligação |
| 9 | Pipeline | `Could not load SQL from file` | Digitei a consulta no campo de arquivo | Coloquei na caixa de SQL |
| 10 | Pipeline | `does not support regular DDL statements` | O Table output não aceita conexão do tipo BigQuery | Criei uma conexão genérica |
| 11 | Pipeline | `Transaction control statements are supported only in scripts or sessions` | O BigQuery só aceita transação dentro de sessão | `EnableSession=1` na URL |
| 12 | Pipeline | `Dataset ... was not found in location US` | A sessão abria na região padrão | `Location=southamerica-east1` na URL |
| 13 | Pipeline | 91 linhas em 3 min 34 s | O driver mandava um insert por linha | Storage Write API |
| 14 | Pipeline | Parâmetros novos da URL sem efeito | Ficaram espaços no meio da URL | Tirei os espaços |
| 15 | Pipeline | Truncate não funcionava | Usei o transform errado | Troquei para o Execute SQL script |
| 16 | Pipeline | `syntax error at or near "$"` | Faltou ligar a substituição de variáveis | Marquei Replace variables in script |
| 17 | Pipeline | `Append serialization failed` na tabela orders | Coluna DATE não aceita a data com hora que o Hop envia | Colunas DATETIME na Bronze |
| 18 | Pipeline | `NOT_FOUND: Requested entity was not found` | Tabela tinha acabado de ser recriada | Esperei alguns minutos |
| 19 | dbt | `python3` pedindo a licença do Xcode | Licença das ferramentas da Apple não aceita | Aceitei a licença |
| 20 | dbt | Instalou o `dbt-core 2.0.0-alpha` | As versões novas pedem Python mais recente | Fixei a versão 1.9 |
| 21 | dbt | Muitos avisos em todo comando | Python 3.9 fora de suporte | `PYTHONWARNINGS=ignore` |

## Origem (PostgreSQL no Docker)

**1. `connection to server at "127.0.0.1", port 55432 failed: Connection refused`**

* Subi o `docker-compose up -d` do repositório do Northwind e não consegui conectar no banco. Olhando o `docker-compose logs db` apareceu: `Error: in 18+, these Docker images are configured to store database data in a format which is compatible with "pg_ctlcluster"`.
* O compose do repositório não fixa a versão da imagem, então ele baixou o PostgreSQL 18, que mudou o lugar onde guarda os dados e não funciona com o volume configurado (`/var/lib/postgresql/data`).
* Resolvi colocando `image: postgres:16` no serviço `db`, apagando os volumes da tentativa anterior com `docker-compose down -v` e subindo de novo.
* Por causa disso o projeto tem um `docker-compose.yml` próprio na raiz, já com a versão fixada, para ninguém mais passar por esse erro.

**2. pgAdmin com `Database is uninitialized and superuser password is not specified`**

* Quando fui editar o compose, a linha `image: postgres:16` foi parar dentro do bloco do `pgadmin`, e ele tentou subir um PostgreSQL sem senha. O YAML depende da indentação, a linha precisa ficar dentro do bloco do `db`.

## Conexão do Hop com o BigQuery

**3. `No suitable driver found for jdbc:bigquery://Parameter Value OAuthType 0 ...`**

* Copiei os parâmetros da tabela da documentação do Hop e o cabeçalho ("Parameter" e "Value") veio junto para a aba Options, o que bagunçou a URL que o Hop monta.
* Resolvi limpando a aba Options, deixando os campos da aba General vazios e colocando a URL inteira no campo Manual connection URL. Fica bem mais fácil de conferir.

**4. Conjunto de dados no campo Database name**

* Eu tinha colocado `northwind_arruda` (o conjunto de dados) no campo Database name. O Hop usa esse campo como o ID do projeto, então a conexão ia para um projeto que não existe. O conjunto de dados não entra na conexão, ele é informado como schema lá no pipeline.
* Outra coisa que aprendi aqui: quando eu renomeei o projeto no Google Cloud, só mudou o nome de exibição. O ID continuou `rruda-data-test` e é ele que vale.

**5. O botão Test não fazia nada**

* Clicava em Test e não aparecia nem sucesso nem erro. Só descobri o motivo quando abri o Hop pelo terminal (`./hop-gui.sh`) e vi o erro lá: `java.lang.NoSuchMethodError: 'void com.google.api.services.bigquery.Bigquery$Builder.<init>(...)'`.
* Eu tinha instalado dois drivers na pasta `lib/jdbc`: primeiro o `google-cloud-bigquery-jdbc-1.4.0-all.jar` e depois o da Simba (`GoogleBigQueryJDBC42.jar`). Um estava usando as classes do outro e dava conflito.
* Resolvi tirando o `-all.jar` da pasta e copiando do zip da Simba só os arquivos que a documentação do Hop lista, sem os `grpc-alts`, `grpc-api`, `grpc-core` e `grpc-netty-shaded`.
* Ficou a lição: quando o Hop não mostra nada na tela, o erro está no terminal.

**6. `403 Forbidden ... User does not have bigquery.jobs.create permission`**

* A conta de serviço conectava mas não tinha permissão. Fui na tela de IAM e o papel de Administrador do BigQuery estava lá, só que ligado a `hop-service-account@...?uid=1142...` com um ícone riscado. É assim que o Google mostra uma conta que foi excluída.
* Eu tinha apagado a conta de serviço e criado outra com o mesmo e-mail. Para o Google são duas contas diferentes, e a nova não herdou o papel.
* Resolvi clicando em Permitir acesso, informando o e-mail da conta e dando o papel de novo.

## Conexão do Hop com o PostgreSQL

**7. `FATAL: password authentication failed for user "localhost"`**

* Erro meu de digitação: coloquei `localhost` no campo Username em vez do Server host name.

## Pipeline da Bronze

**8. `Not receiving any fields from previous transforms`**

* O Table output não estava ligado ao Table input. A ligação se cria arrastando de um para o outro com o Shift pressionado.

**9. `Could not load SQL from file: SELECT * FROM customers`**

* Digitei a consulta no campo de nome de arquivo do Table input, e o Hop tentou abrir um arquivo com esse nome. A consulta vai na caixa grande de SQL.

**10. `The Simba driver for a Google Big Query database connection does not support regular DDL statements. Please use the GBQ Bulk Loader transform to create your table.`**

* Esse foi o que mais demorou. No começo achei que era a opção Truncate table, desmarquei e o erro continuou igual.
* A causa de verdade é que o Hop bloqueia o Table output para qualquer conexão do tipo "Google BigQuery". A mensagem é fixa e aparece independente das opções marcadas. E o "GBQ Bulk Loader" que ela sugere nem existe no Hop.
* Resolvi criando uma segunda conexão, do tipo Generic database, com a classe `com.simba.googlebigquery.jdbc42.Driver` e a mesma URL. Por isso o projeto tem duas conexões para o BigQuery: a `BQ` (que eu uso para executar SQL) e a `BQ_generic` (que o Table output usa).
* Como a opção Truncate table do Table output não funciona nesse cenário, a limpeza da tabela é feita por um Execute SQL script com `TRUNCATE TABLE ${BQ_DATASET}.raw_${TABLE_NAME}`.

**11. `Transaction control statements are supported only in scripts or sessions`**

* Com o Commit size maior que zero o Hop desliga o autocommit e o driver tenta abrir uma transação. O BigQuery só aceita transação dentro de uma sessão.
* Resolvi acrescentando `EnableSession=1` na URL.

**12. `Not found: Dataset rruda-data-test:northwind_arruda was not found in location US`**

* A sessão estava abrindo na região padrão (US) e o meu conjunto de dados está em `southamerica-east1`.
* Resolvi acrescentando `Location=southamerica-east1` na URL.

**13. Carga muito lenta: 91 linhas em 3 minutos e 34 segundos**

* Funcionou, mas levando uns 2,3 segundos por linha, porque o driver mandava cada insert como um job separado no BigQuery. Fiz a conta e a tabela `order_details`, com 2.155 linhas, ia levar quase 1 hora e meia.
* Resolvi ativando a Storage Write API do driver, com `EnableWriteAPI=1;SWA_ActivationRowCount=1;SWA_AppendRowCount=1000;` na URL. A mesma carga passou para 5 segundos, e as 4 tabelas juntas para 33 segundos.

**14. Os parâmetros da Write API não fizeram efeito na primeira vez**

* Quando colei os parâmetros ficaram três espaços entre `Location=southamerica-east1;` e `EnableWriteAPI=1`. O driver não reconheceu o nome do parâmetro e ignorou sem avisar nada. A URL não pode ter espaço.

**15. Transform errado para o truncate**

* Adicionei o "Execute row SQL script", que espera receber o SQL de uma coluna. O certo é o "Execute SQL script", que fica solto no pipeline (sem ligação) e por isso roda uma vez só na inicialização, antes de as linhas começarem a passar.

**16. `ERROR: syntax error at or near "$"`**

* O PostgreSQL recebeu o texto `SELECT * FROM ${TABLE_NAME}` sem trocar a variável. Faltava marcar a opção Replace variables in script no Table input.

**17. `INVALID_ARGUMENT: Append serialization failed for writer` na tabela orders**

* A tabela `customers` carregava e a `orders` não. A diferença entre as duas eram as colunas de data. O Hop sempre manda a data com hora (`1996-07-04 00:00:00`) e a Write API não aceita esse formato em coluna do tipo `DATE`.
* Resolvi recriando a `raw_orders` com as três datas como `DATETIME` e fazendo a conversão para `DATE` na Silver (`stg_orders`). As tabelas `order_details` e `products`, que não têm data, carregaram sem precisar mexer em nada, o que confirmou que o problema era esse.

**18. `io.grpc.StatusRuntimeException: NOT_FOUND: Requested entity was not found`**

* Apareceu logo depois que eu apaguei e recriei a `raw_orders`. A tabela existia (o truncate do mesmo pipeline funcionava), mas a Write API demora alguns minutos para enxergar uma tabela que foi recriada com o mesmo nome.
* Esperei alguns minutos, rodei de novo e funcionou.

## dbt

**19. `You have not agreed to the Xcode and Apple SDKs license`**

* O `python3` do Mac vem das ferramentas de linha de comando da Apple e só roda depois de aceitar a licença (Enter, ir até o fim do texto e digitar `agree`).

**20. O `pip install dbt-bigquery` instalou o `dbt-core 2.0.0-alpha.5`**

* As versões estáveis mais novas do dbt pedem um Python mais recente que o 3.9 da minha máquina, e o pip acabou instalando uma versão alpha.
* Resolvi fixando a versão: `pip install "dbt-core>=1.9,<1.10" "dbt-bigquery>=1.9,<1.10"`.

**21. Vários avisos (`FutureWarning`, `NotOpenSSLWarning`) em todo comando do dbt**

* Não são erros, são as bibliotecas do Google avisando que o Python 3.9 está fora de suporte. Para parar de aparecer usei `export PYTHONWARNINGS="ignore"`. O certo mesmo é atualizar o Python, e coloquei isso na lista do que eu faria com mais tempo.

## O que eu levo disso

* Olhar o log do terminal antes de sair mexendo na tela. Quase todos os erros do Hop estavam explicados lá.
* Testar primeiro com a menor tabela (`customers`, 91 linhas) e só depois generalizar para as outras.
* Mudar uma coisa de cada vez e testar de novo. Os erros 10 a 18 estavam um atrás do outro, cada correção mostrava o próximo.
* Fixar as versões (imagem do PostgreSQL, dbt). Pegar "a mais recente" me deu problema duas vezes.

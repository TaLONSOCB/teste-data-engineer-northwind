#!/usr/bin/env bash
# Roda o pipeline inteiro: ingestão -> testes -> transformação -> documentação.
#
# Variáveis de ambiente que precisam estar definidas:
#   HOP_HOME     pasta de instalação do Apache Hop (onde está o hop-run.sh)
#   DBT_KEYFILE  caminho do arquivo JSON da conta de serviço do Google Cloud
#
# Uso:  ./run.sh
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJETO_HOP="northwind_bronze"

: "${HOP_HOME:?Defina HOP_HOME com a pasta de instalacao do Apache Hop}"
: "${DBT_KEYFILE:?Defina DBT_KEYFILE com o caminho da chave JSON da conta de servico}"
[ -f "$DBT_KEYFILE" ] || { echo "Chave nao encontrada: $DBT_KEYFILE"; exit 1; }

export PYTHONWARNINGS="ignore"
# O Hop recebe o caminho da chave como propriedade de sistema (variável GCP_KEYFILE).
export HOP_OPTIONS="${HOP_OPTIONS:-} -DGCP_KEYFILE=${DBT_KEYFILE}"

etapa() { echo; echo "==== $1 ===="; }

etapa "0/5 Preparacao: tabelas raw_ e registro do projeto Hop"
( cd "$RAIZ/northwind" && dbt run-operation criar_tabelas_bronze )
"$HOP_HOME/hop-conf.sh" --project="$PROJETO_HOP" --project-create \
    --project-home="$RAIZ/hop" --project-config-file="project-config.json" \
    >/dev/null 2>&1 || true   # já estava registrado de uma execução anterior

etapa "1/5 Ingestao (Bronze) - Apache Hop"
"$HOP_HOME/hop-run.sh" --project="$PROJETO_HOP" \
    --file="$RAIZ/hop/bronze_main.hpl" --runconfig=local

cd "$RAIZ/northwind"

etapa "2/5 Testes da ingestao (fontes Bronze) - dbt"
dbt test --select "source:*"

etapa "3/5 Transformacao (Silver e Gold) - dbt"
dbt run

etapa "4/5 Testes das camadas Silver e Gold - dbt"
dbt test --exclude "source:*"

etapa "5/5 Documentacao - dbt"
dbt docs generate

echo
echo "Pipeline concluido. Para abrir a documentacao: cd northwind && dbt docs serve"

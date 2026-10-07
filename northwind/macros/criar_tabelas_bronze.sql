{#
  Cria o conjunto de dados e as tabelas raw_ da camada Bronze, caso ainda nao
  existam. O Apache Hop grava nessas tabelas, mas nao as cria: o Table output
  do Hop nao gera DDL para o BigQuery. Uso:

      dbt run-operation criar_tabelas_bronze

  As datas de raw_orders sao DATETIME porque a gravacao em lote do driver
  (Storage Write API) nao aceita o formato enviado pelo Hop em colunas DATE.
  A conversao para DATE acontece na Silver (stg_orders).
#}
{% macro criar_tabelas_bronze() %}

  {% set destino = '`' ~ target.project ~ '`.`' ~ target.schema ~ '`' %}

  {% set comandos = [
    "create schema if not exists " ~ destino,

    "create table if not exists " ~ destino ~ ".raw_customers (
        customer_id string, company_name string, contact_name string,
        contact_title string, address string, city string, region string,
        postal_code string, country string, phone string, fax string
     )",

    "create table if not exists " ~ destino ~ ".raw_orders (
        order_id int64, customer_id string, employee_id int64,
        order_date datetime, required_date datetime, shipped_date datetime,
        ship_via int64, freight float64, ship_name string, ship_address string,
        ship_city string, ship_region string, ship_postal_code string,
        ship_country string
     )",

    "create table if not exists " ~ destino ~ ".raw_order_details (
        order_id int64, product_id int64, unit_price float64,
        quantity int64, discount float64
     )",

    "create table if not exists " ~ destino ~ ".raw_products (
        product_id int64, product_name string, supplier_id int64,
        category_id int64, quantity_per_unit string, unit_price float64,
        units_in_stock int64, units_on_order int64, reorder_level int64,
        discontinued int64
     )"
  ] %}

  {% for comando in comandos %}
    {% do run_query(comando) %}
  {% endfor %}

  {{ log("Tabelas raw_ garantidas em " ~ target.project ~ "." ~ target.schema, info=True) }}

{% endmacro %}

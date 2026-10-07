-- DDL das tabelas da Bronze (deixei aqui como referência).
-- Na prática elas são criadas com:  dbt run-operation criar_tabelas_bronze
-- Se for usar outro projeto ou conjunto de dados, precisa trocar os nomes abaixo.

create table if not exists `rruda-data-test.northwind_arruda.raw_customers` (
  customer_id string, company_name string, contact_name string,
  contact_title string, address string, city string, region string,
  postal_code string, country string, phone string, fax string
);

create table if not exists `rruda-data-test.northwind_arruda.raw_orders` (
  order_id int64, customer_id string, employee_id int64,
  order_date datetime, required_date datetime, shipped_date datetime,
  ship_via int64, freight float64, ship_name string, ship_address string,
  ship_city string, ship_region string, ship_postal_code string, ship_country string
);

create table if not exists `rruda-data-test.northwind_arruda.raw_order_details` (
  order_id int64, product_id int64, unit_price float64,
  quantity int64, discount float64
);

create table if not exists `rruda-data-test.northwind_arruda.raw_products` (
  product_id int64, product_name string, supplier_id int64, category_id int64,
  quantity_per_unit string, unit_price float64, units_in_stock int64,
  units_on_order int64, reorder_level int64, discontinued int64
);


create database if not exists sanitize default character set utf8;

-- Add create statements for the databases defined in aws_sanitizer.sh
create database if not exists sanitize_products default character set utf8;
create database if not exists sanitize_categories default character set utf8;
create database if not exists sanitize_products_categories default character set utf8;


use sanitize_products;

-- Use the sanitization process to restore application defaults for development and testing.
update sanitize_products set quantity = 100 where products_id in (1,2,3,4,5);

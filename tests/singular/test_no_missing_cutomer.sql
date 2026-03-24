-- tests/singular/test_no_missing_customers.sql
-- Fails if any transaction's account cannot be matched to a customer

select transaction_id
from {{ ref('int_customer_transactions') }}
where is_missing_customer = true
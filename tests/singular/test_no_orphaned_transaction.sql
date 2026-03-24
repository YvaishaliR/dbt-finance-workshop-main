-- tests/singular/test_no_orphaned_transactions.sql
-- Fails if any transaction cannot be matched to an account

select transaction_id
from {{ ref('int_customer_transactions') }}
where is_orphaned_transaction = true
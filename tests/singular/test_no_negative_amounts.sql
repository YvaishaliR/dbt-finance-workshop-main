-- Test: Transaction amounts should never be negative
-- A negative amount would indicate a data quality issue upstream

select
    transaction_id,
    amount
from {{ ref('stg_transactions') }}
where amount < 0
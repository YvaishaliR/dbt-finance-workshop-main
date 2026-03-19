-- Singular test: Ensure transaction dates are not in the future
-- TODO: Module 2 - This test should return zero rows if passing

select
    transaction_id,
    transaction_date,
    current_date as today
from {{ ref('stg_transactions') }}
where transaction_date > current_date

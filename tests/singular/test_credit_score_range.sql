-- Test: Credit scores must be within the valid 300-850 range

select
    customer_id,
    credit_score
from {{ ref('stg_customers') }}
where credit_score < 300
   or credit_score > 850
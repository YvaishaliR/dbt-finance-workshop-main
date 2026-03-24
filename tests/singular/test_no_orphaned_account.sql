-- Hint: Use a LEFT JOIN and filter WHERE c.customer_id IS NULL
select
    a.account_id,
    a.customer_id
from {{ ref('stg_accounts') }} a
left join {{ ref('stg_customers') }} c on a.customer_id = c.customer_id
where c.customer_id is null
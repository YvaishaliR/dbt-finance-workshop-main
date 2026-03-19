# Workshop Solutions Reference

This document contains completed solutions for all DIY exercises across modules. Use these as reference if you get stuck, but try to complete the exercises yourself first!

---

## Module 1 Solutions

### Solution: stg_transactions.sql

```sql
-- Staging model for transactions
-- This is the first transformation layer (Bronze -> Silver)
-- Purpose: Clean and standardize transaction data

with source_data as (
    
    -- Using ref() to reference the seed
    -- In Module 2, we'll replace this with source()
    select * from {{ ref('transactions') }}

),

renamed as (

    select
        -- Primary key
        transaction_id,
        
        -- Foreign key (to accounts - customer accessed through account)
        account_id,
        
        -- Transaction details
        transaction_date,
        cast(amount as decimal(10,2)) as amount,
        transaction_type,
        status,
        merchant_name,
        category,
        
        -- Calculated fields
        current_date - transaction_date as transaction_age_days,
        
        -- Audit fields
        current_timestamp as loaded_at

    from source_data
    where status != 'failed'  -- Exclude failed transactions

)

select * from renamed
```

### Solution: stg_accounts.sql

```sql
-- Staging model for accounts

with source_data as (
    
    select * from {{ ref('accounts') }}

),

renamed as (

    select
        -- Primary key
        account_id,
        
        -- Foreign key
        customer_id,
        
        -- Account details
        account_type,
        account_status,
        cast(open_date as date) as open_date,
        cast(credit_limit as decimal(10,2)) as credit_limit,
        cast(current_balance as decimal(10,2)) as current_balance,
        
        -- Calculated fields
        current_date - cast(open_date as date) as account_age_days,
        
        -- Audit fields
        current_timestamp as loaded_at
        
    from source_data

)

select * from renamed
```

### Solution: stg_customers.sql

```sql
-- Staging model for customers

with source_data as (
    
    select * from {{ ref('customers') }}

),

renamed as (

    select
        -- Primary key
        customer_id,
        
        -- Customer details
        customer_name as full_name,
        email,
        customer_type,
        risk_category,
        cast(created_at as date) as created_at,
        city,
        state,
        age_group,
        cast(credit_score as integer) as credit_score,
        
        -- Calculated fields
        current_date - cast(created_at as date) as customer_age_days,
        
        -- Audit fields
        current_timestamp as loaded_at
        
    from source_data

)

select * from renamed
```

---

## Module 2 Solutions

### Solution: sources.yml

```yaml
version: 2

sources:
  - name: bronze
    description: Bronze layer - raw data from CSV seeds
    database: main
    schema: bronze
    
    tables:
      - name: transactions
        description: Raw transaction data from banking system
        columns:
          - name: transaction_id
            description: Unique identifier for each transaction
            tests:
              - unique
              - not_null
          
          - name: account_id
            description: Foreign key to accounts table (customer accessed through account)
            tests:
              - not_null
          
          - name: amount
            description: Transaction amount in USD
            tests:
              - not_null
          
          - name: transaction_date
            description: Date when transaction occurred
            tests:
              - not_null
      
      - name: accounts
        description: Account master data
        columns:
          - name: account_id
            description: Unique account identifier
            tests:
              - unique
              - not_null
          
          - name: customer_id
            description: Foreign key to customers
            tests:
              - not_null
          
          - name: account_type
            description: Type of account
            tests:
              - accepted_values:
                  arguments:
                    values: ['checking', 'savings', 'credit_card']
      
      - name: customers
        description: Customer master data
        columns:
          - name: customer_id
            description: Unique customer identifier
            tests:
              - unique
              - not_null
          
          - name: email
            description: Customer email address
            tests:
              - unique
              - not_null
```

### Solution: Update stg_transactions.sql with source()

```sql
-- Update the source_data CTE:
with source_data as (
    
    -- Using source() instead of ref()
    select * from {{ source('bronze', 'transactions') }}

),
-- ... rest remains the same
```

### Solution: Complete schema.yml with all tests

```yaml
version: 2

models:
  - name: stg_transactions
    description: Staging layer for transaction data - cleaned and standardized
    columns:
      - name: transaction_id
        description: Unique identifier for each transaction
        tests:
          - unique
          - not_null
      
      - name: account_id
        description: Foreign key to accounts (customer accessed through account)
        tests:
          - not_null
          - relationships:
              to: ref('stg_accounts')
              field: account_id
      
      - name: amount
        description: Transaction amount in USD
        tests:
          - not_null
      
      - name: transaction_type
        description: Type of transaction
        tests:
          - accepted_values:
              arguments:
                values: ['debit', 'credit', 'transfer']
      
      - name: status
        description: Transaction status
        tests:
          - accepted_values:
              arguments:
                values: ['completed', 'pending']

  - name: stg_accounts
    description: Staging layer for account data
    columns:
      - name: account_id
        description: Unique account identifier
        tests:
          - unique
          - not_null
      
      - name: customer_id
        description: Foreign key to customers
        tests:
          - not_null
          - relationships:
              to: ref('stg_customers')
              field: customer_id
      
      - name: account_type
        description: Type of account
        tests:
          - accepted_values:
              arguments:
                values: ['checking', 'savings', 'credit_card']
      
      - name: account_status
        description: Current status of account
        tests:
          - accepted_values:
              arguments:
                values: ['active', 'closed', 'suspended']
      
      - name: current_balance
        description: Current account balance
        tests:
          - not_null

  - name: stg_customers
    description: Staging layer for customer data
    columns:
      - name: customer_id
        description: Unique customer identifier
        tests:
          - unique
          - not_null
      
      - name: email
        description: Customer email address
        tests:
          - unique
          - not_null
      
      - name: customer_type
        description: Type of customer
        tests:
          - accepted_values:
              arguments:
                values: ['individual', 'business']
      
      - name: risk_category
        description: Risk assessment category
        tests:
          - accepted_values:
              arguments:
                values: ['low', 'medium', 'high']
      
      - name: credit_score
        description: Customer credit score
        tests:
          - not_null
```

### Solution: Singular test - negative amounts

Create `tests/singular/test_no_negative_amounts.sql`:

```sql
-- Test that no transactions have negative amounts
select
    transaction_id,
    amount
from {{ ref('stg_transactions') }}
where amount < 0
```

---

## Module 3 Solutions

### Solution: int_customer_transactions.sql

```sql
-- Intermediate model: Customer transactions enriched with account and customer data

{{
    config(
        materialized='ephemeral'
    )
}}

with transactions as (

    select * from {{ ref('stg_transactions') }}

),

accounts as (

    select * from {{ ref('stg_accounts') }}

),

customers as (

    select * from {{ ref('stg_customers') }}

),

joined as (

    select
        -- Transaction fields
        t.transaction_id,
        t.transaction_date,
        t.amount,
        t.transaction_type,
        t.status,
        t.category,
        t.merchant_name,
        
        -- Account fields
        a.account_id,
        a.account_type,
        a.account_status,
        a.current_balance,
        
        -- Customer fields (accessed through account)
        c.customer_id,
        c.full_name as customer_name,
        c.customer_type,
        c.risk_category,
        c.credit_score,
        c.city,
        c.state,
        
        -- Calculated fields
        case when t.amount > 1000 then true else false end as is_high_value,
        case 
            when c.risk_category = 'high' or c.credit_score < 650 
            then true 
            else false 
        end as risk_flag
        
    -- Left joins preserve ALL transactions.
    -- Orphaned rows surface as nulls rather than being silently dropped.
    from transactions t
    left join accounts  a on t.account_id  = a.account_id
    left join customers c on a.customer_id = c.customer_id
    
)

select * from joined
```

### Solution: int_account_balances.sql

```sql
-- Intermediate model: Calculate running account balances

{{
    config(
        materialized='ephemeral'
    )
}}

with transactions as (

    select * from {{ ref('int_customer_transactions') }}

),

account_summary as (

    select
        account_id,
        account_type,
        customer_id,
        customer_name,
        
        -- Transaction counts
        count(*) as transaction_count,
        count(distinct transaction_date) as active_days,
        
        -- Amount aggregations
        sum(case when transaction_type = 'credit' then amount else 0 end) as total_credits,
        sum(case when transaction_type = 'debit' then amount else 0 end) as total_debits,
        sum(case when transaction_type = 'transfer' then amount else 0 end) as total_transfers,
        
        -- Date boundaries
        min(transaction_date) as first_transaction_date,
        max(transaction_date) as last_transaction_date,
        
        -- Calculated balance impact
        sum(case 
            when transaction_type = 'credit' then amount
            when transaction_type = 'debit' then -amount
            else 0
        end) as net_balance_change
        
    from transactions
    where status = 'completed'
    group by 1, 2, 3, 4

)

select * from account_summary
```

---

## Module 4 Solutions

### Solution: fct_daily_transactions.sql

```sql
-- Fact table: Daily transaction summary

{{
    config(
        materialized='table',
        schema='marts'
    )
}}

with customer_transactions as (

    select * from {{ ref('int_customer_transactions') }}

),

daily_summary as (

    select
        transaction_date,
        customer_id,
        customer_name,
        customer_type,
        
        -- Transaction counts
        count(*) as transaction_count,
        count(distinct account_id) as unique_accounts,
        count(distinct category) as unique_categories,
        
        -- Amount aggregations
        sum(amount) as total_amount,
        avg(amount) as avg_amount,
        min(amount) as min_amount,
        max(amount) as max_amount,
        
        -- By transaction type
        sum(case when transaction_type = 'debit' then amount else 0 end) as total_debits,
        sum(case when transaction_type = 'credit' then amount else 0 end) as total_credits,
        sum(case when transaction_type = 'transfer' then amount else 0 end) as total_transfers,
        
        -- High value flag
        sum(case when is_high_value then 1 else 0 end) as high_value_transaction_count,
        
        -- Using macro for fees
        sum({{ calculate_transaction_fee('amount', 'transaction_type') }}) as total_fees
        
    from customer_transactions
    where status = 'completed'
    group by 1, 2, 3, 4

)

select * from daily_summary
```

### Solution: dim_customers.sql

```sql
-- Dimension table: Customer dimension with lifetime metrics

{{
    config(
        materialized='table',
        schema='marts'
    )
}}

with customers as (

    select * from {{ ref('stg_customers') }}

),

customer_metrics as (

    select
        customer_id,
        count(*) as total_transactions,
        sum(amount) as total_lifetime_value,
        avg(amount) as avg_transaction_amount,
        min(transaction_date) as first_transaction_date,
        max(transaction_date) as last_transaction_date,
        count(distinct account_id) as account_count,
        count(distinct category) as category_count
        
    from {{ ref('int_customer_transactions') }}
    where status = 'completed'
    group by customer_id
    
),

final as (

    select
        c.customer_id,
        c.full_name as customer_name,
        c.email,
        c.customer_type,
        c.risk_category,
        c.credit_score,
        c.city,
        c.state,
        c.age_group,
        c.created_at as customer_since,
        c.customer_age_days,
        
        -- Metrics from transactions
        coalesce(m.total_transactions, 0) as total_transactions,
        coalesce(m.total_lifetime_value, 0) as total_lifetime_value,
        coalesce(m.avg_transaction_amount, 0) as avg_transaction_amount,
        m.first_transaction_date,
        m.last_transaction_date,
        coalesce(m.account_count, 0) as account_count,
        coalesce(m.category_count, 0) as category_count,
        
        -- Customer segments
        case
            when m.total_lifetime_value >= 10000 then 'high_value'
            when m.total_lifetime_value >= 5000 then 'medium_value'
            else 'low_value'
        end as customer_segment
        
    from customers c
    left join customer_metrics m on c.customer_id = m.customer_id
    
)

select * from final
```

### Solution: Incremental fct_daily_transactions.sql

```sql
-- Incremental version of fact table

{{
    config(
        materialized='incremental',
        unique_key='transaction_date||customer_id',
        on_schema_change='fail'
    )
}}

with customer_transactions as (

    select * from {{ ref('int_customer_transactions') }}
    
    {% if is_incremental() %}
    -- Only process new or updated transactions
    where transaction_date >= (select max(transaction_date) from {{ this }})
    {% endif %}

),

daily_summary as (

    select
        transaction_date,
        customer_id,
        customer_name,
        customer_type,
        count(*) as transaction_count,
        sum(amount) as total_amount,
        avg(amount) as avg_amount,
        -- ... (rest of aggregations)
        
    from customer_transactions
    where status = 'completed'
    group by 1, 2, 3, 4

)

select * from daily_summary
```

---

## Module 5 Solutions

### Solution: Advanced tests with dbt_expectations

Add to `schema.yml`:

```yaml
# After installing dbt_expectations package

models:
  - name: stg_transactions
    tests:
      - dbt_expectations.expect_table_row_count_to_be_between:
          min_value: 1
          max_value: 10000
    
    columns:
      - name: amount
        tests:
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 100000
          
          - dbt_expectations.expect_column_mean_to_be_between:
              min_value: 50
              max_value: 5000
      
      - name: transaction_date
        tests:
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: "'2020-01-01'"
              max_value: "current_date"
      
      - name: email
        tests:
          - dbt_expectations.expect_column_values_to_match_regex:
              regex: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
```

### Solution: Custom generic test

Create `tests/generic/test_valid_account_number.sql`:

```sql
{% test valid_account_number(model, column_name) %}

-- Account IDs should follow pattern: ACC### where ### is a number

select {{ column_name }}
from {{ model }}
where 
    {{ column_name }} not like 'ACC%'
    or length({{ column_name }}) != 6

{% endtest %}
```

Usage in schema.yml:
```yaml
columns:
  - name: account_id
    tests:
      - valid_account_number
```

---

## Module 6 Solutions

### Solution: selectors.yml

```yaml
selectors:
  - name: daily_refresh
    description: Models that should run daily
    definition:
      union:
        - method: tag
          value: daily
        - method: path
          value: marts/finance
  
  - name: hourly_refresh
    description: Models for hourly updates
    definition:
      tag: hourly
  
  - name: staging_layer
    description: All staging models
    definition:
      path: staging
```

### Solution: .sqlfluff configuration

Create `.sqlfluff`:

```ini
[sqlfluff]
dialect = duckdb
templater = dbt
max_line_length = 100

[sqlfluff:indentation]
indent_unit = space
tab_space_size = 4

[sqlfluff:rules:capitalisation.keywords]
capitalisation_policy = lower

[sqlfluff:rules:capitalisation.functions]
capitalisation_policy = lower

[sqlfluff:rules:capitalisation.literals]
capitalisation_policy = lower
```

---

## Validation Queries

Use these to verify your solutions:

```sql
-- Check staging layer row counts
SELECT 'stg_transactions' as model, count(*) as rows FROM staging.stg_transactions
UNION ALL
SELECT 'stg_accounts', count(*) FROM staging.stg_accounts
UNION ALL
SELECT 'stg_customers', count(*) FROM staging.stg_customers;

-- Verify joins worked in intermediate
SELECT count(*) as enriched_transactions 
FROM {{ ref('int_customer_transactions') }}
WHERE customer_name IS NOT NULL;

-- Check mart aggregations
SELECT 
    count(*) as daily_records,
    sum(transaction_count) as total_transactions
FROM marts.fct_daily_transactions;

-- Verify dimension table
SELECT 
    customer_segment,
    count(*) as customer_count,
    avg(total_lifetime_value) as avg_ltv
FROM marts.dim_customers
GROUP BY customer_segment;
```

---

## Tips for Success

1. **Don't skip the DIY exercises** - typing the code yourself builds muscle memory
2. **Run tests frequently** - `dbt test` after each model
3. **Check query results** - always verify the data looks correct
4. **Read error messages carefully** - dbt provides helpful error context
5. **Use dbt docs** - `dbt docs generate && dbt docs serve` to visualize lineage

---

## Need Help?

If you're stuck:
1. Check the error message carefully
2. Review the relevant module documentation
3. Compare your code to these solutions
4. Ask in DataGrokr Slack: #dbt-training

Remember: It's better to struggle a bit and learn than to copy solutions immediately! 💪

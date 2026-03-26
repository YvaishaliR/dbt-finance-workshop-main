{{
    config(
        materialized='incremental',
        unique_key=dbt_utils.generate_surrogate_key(
            ['transaction_date', 'customer_id', 'account_id']
        ),
        on_schema_change='fail'
    )
}}

with customer_transactions as (

    select * from {{ ref('int_customer_transactions') }}

    {% if is_incremental() %}
    -- On incremental runs, only process transactions since the last run
    -- We look back 1 day to catch any late-arriving data
        where transaction_date >= (
            select date_add(max(transaction_date), interval '-1 day')
            from {{ this }}
        )
    {% endif %}

),

daily_summary as (

    select
        transaction_date,
        customer_id,
        customer_name,
        customer_type,
        account_id,
        account_type,

        -- Transaction counts
        count(*) as transaction_count,
        count(distinct account_id) as unique_accounts,
        count(distinct category) as unique_categories,

        -- Amount aggregations
        sum(amount) as total_amount,
        avg(amount) as avg_amount,
        min(amount) as min_amount,
        max(amount) as max_amount,

        -- Split by transaction type
        sum(case when transaction_type = 'debit' then amount else 0 end) as total_debits,
        sum(case when transaction_type = 'credit' then amount else 0 end) as total_credits,
        sum(case when transaction_type = 'transfer' then amount else 0 end) as total_transfers,

        -- Risk and value flags
        sum(case when is_high_value then 1 else 0 end) as high_value_count,
        sum(case when risk_flag then 1 else 0 end) as risk_flagged_count,

        -- Transaction fee (using macro — added in Part 3) 
        sum({{ calculate_transaction_fee('amount', 'transaction_type') }}) as total_fees,
        {{ audit_columns() }}

    from customer_transactions
    where status = 'completed'
    group by
        transaction_date,
        customer_id,
        customer_name,
        customer_type,
        account_id,
        account_type

)

select * from daily_summary

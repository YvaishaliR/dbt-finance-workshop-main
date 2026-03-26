-- Staging model for transactions
-- This is the first transformation layer (Bronze -> Silver)
-- Purpose: Clean and standardize transaction data

with source_data as (

    -- NOTE [Module 1]: Using ref() to reference the seed for now
    -- NOTE [Module 2]: Replace ref() with source('bronze', 'transactions') in double curly braces
    select * from {{ source('bronze', 'transactions') }}
),

renamed as (

    select
        -- Primary key
        transaction_id,

        -- Foreign key (to accounts - customer is accessed through account)
        account_id,

        -- Transaction details
        transaction_date,
        -- TODO [Module 1]: Cast amount to decimal(10,2)
        cast(amount as decimal(10, 2)) as amount,
        transaction_type,
        status,
        merchant_name,
        category,

        -- TODO [Module 1]: Add a calculated field for transaction_age_days
        -- Hint: Use current_date - transaction_date
        current_date - transaction_date as transaction_age_days,

        -- Audit fields
        current_timestamp as loaded_at

    from source_data
    where status != 'failed'

    -- TODO [Module 1]: Add a filter to exclude failed transactions
    -- Hint: where status != 'failed'

)

select * from renamed

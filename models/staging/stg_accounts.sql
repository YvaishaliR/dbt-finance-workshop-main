-- Staging model for accounts
-- TODO [Module 1]: Complete this staging model following the pattern from stg_transactions.sql

with source_data as (
    
    -- TODO [Module 1]: Reference the accounts seed table
     select * from {{ source('bronze', 'accounts') }}
    -- NOTE [Module 2]: Replace ref() with source('bronze', 'accounts') in double curly braces

),

renamed as (

    select
        -- TODO [Module 1]: Select and rename columns as needed
        account_id, customer_id, account_type, account_status,
                 open_date, credit_limit, current_balance,
        
        -- TODO [Module 1]: Add calculated field for account_age_days
        -- Hint: Use current_date - open_date
         current_date - open_date as account_age_days,
        
        -- TODO [Module 1]: Add loaded_at timestamp
        current_timestamp as loaded_at
        
    from source_data

)

-- TODO [Module 1]: Complete the final select
select * from renamed

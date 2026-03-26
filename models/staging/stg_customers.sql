-- Staging model for customers
-- TODO [Module 1]: Complete this staging model

with source_data as (

    -- TODO [Module 1]: Reference the customers seed table
    select * from {{ source('bronze', 'customers') }}
    -- NOTE [Module 2]: Replace ref() with source('bronze', 'customers') in double curly braces

),

renamed as (

    select
        -- TODO [Module 1]: Select all columns
        customer_id,
        customer_name,
        email,
        customer_type,
        risk_category,
        created_at,
        city,
        state,
        age_group,
        credit_score,

        -- TODO [Module 1]: Rename customer_name to full_name
        customer_name as full_name,

        -- TODO [Module 1]: Add loaded_at timestamp
        current_timestamp as loaded_at

    from source_data

)

-- TODO [Module 1]: Complete the final select
select * from renamed

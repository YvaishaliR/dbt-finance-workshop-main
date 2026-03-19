# Module 3: Medallion Architecture — Silver Layer

---

**Duration:** 90 minutes  
**Prerequisites:** Completed Module 2 — sources configured, all staging tests passing  
**Deliverable:** Two intermediate models with joins, business logic, and passing tests

---

## 🎯 Learning Objectives

By the end of this module, you will:
- ✅ Build intermediate models that join across entities
- ✅ Understand when and why to use ephemeral materialization
- ✅ Navigate the transaction → account → customer join chain correctly
- ✅ Apply business logic: calculated fields, categorisation, null handling
- ✅ Understand how CTEs structure complex transformations

---

## 📋 Module Overview

1. **Understanding the Silver Layer** (10 mins)
2. **Building `int_customer_transactions`** (35 mins)
3. **Building `int_account_balances`** (25 mins)
4. **DIY Exercise** (20 mins)

---

## Part 1: Understanding the Silver Layer (10 mins)

### The Medallion Architecture

This project follows the medallion architecture pattern:

```
Bronze  →  Silver  →  Gold
(raw)     (clean)   (analytics-ready)
```

In dbt terms:

| Layer | Folder | Materialization | Purpose |
|-------|--------|----------------|---------|
| Bronze | `seeds/` | Table | Raw source data, untouched |
| Silver | `models/staging/` | View | Clean, typed, renamed |
| Silver | `models/intermediate/` | Ephemeral | Business logic, joins |
| Gold | `models/marts/` | Table | Analytics-ready facts and dimensions |

Staging and intermediate together form the silver layer. Staging handles structural cleanup (renaming, casting, filtering). Intermediate handles business logic (joins, aggregations, derived fields).

### Why ephemeral for intermediate models?

Ephemeral models are never created in the database. Instead, dbt inlines them as CTEs inside whatever model references them. This means:

- No extra tables or views cluttering your database
- Intermediate logic is encapsulated and reusable
- Performance is the same — the SQL is identical, just inlined

The tradeoff: you can't query ephemeral models directly in DuckDB. If you need to inspect intermediate data during development, temporarily change the materialization to `table`, query it, then change it back.

```sql
-- Temporarily override in the model for debugging:
{{ config(materialized='table') }}
```

---

## Part 2: Building `int_customer_transactions` (35 mins)

### What this model does

This is the core enrichment model for the workshop. It joins the three staging models together so downstream mart models have everything they need in one place:

```
stg_transactions
      ↓ (inner join on account_id)
stg_accounts
      ↓ (inner join on customer_id)
stg_customers
```

This is the correct join path — remember from the data model, transactions don't have a direct `customer_id`. You must go through accounts.

### Step 1: Open the scaffold

Open `models/intermediate/int_customer_transactions.sql`. The joins are already stubbed in — your job is to complete the SELECT list and add the calculated fields.

### Step 2: Complete the SELECT list

```sql
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
        t.transaction_age_days,

        -- Account fields
        a.account_id,
        a.account_type,
        a.account_status,
        a.current_balance,
        a.account_age_days,

        -- Customer fields (accessed through account)
        c.customer_id,
        c.full_name          as customer_name,
        c.email,
        c.customer_type,
        c.risk_category,
        c.credit_score,
        c.city,
        c.state,
        c.age_group,

        -- Calculated fields
        case
            when t.amount > 1000 then true
            else false
        end                  as is_high_value,

        case
            when c.risk_category = 'high' or c.credit_score < 650
            then true
            else false
        end                  as risk_flag,

        case
            when t.amount >= 1000 then 'large'
            when t.amount >= 100  then 'medium'
            else 'small'
        end                  as transaction_size_band

    from transactions t
    inner join accounts  a on t.account_id  = a.account_id
    inner join customers c on a.customer_id = c.customer_id

)

select * from joined
```

### Step 3: Why `left join` not `inner join`?

This is an important data engineering decision. An `inner join` silently drops any transaction that doesn't have a matching account, and any account that doesn't have a matching customer. The silver layer would look clean — no errors, correct row counts — but data would be missing with no warning.

**This is dangerous in financial data.** A missing transaction is far worse than a visible null.

`left join` preserves ALL transactions and surfaces data quality problems as nulls rather than hiding them:

```
inner join  →  orphaned rows silently dropped, silver layer looks clean, data is incomplete
left join   →  orphaned rows preserved with nulls, issues are visible, tests can catch them
```

The model adds two explicit data quality flags for this purpose:

```sql
case when a.account_id  is null then true else false end as is_orphaned_transaction,
case when c.customer_id is null then true else false end as is_missing_customer,
```

These flags let you:
- Write tests that **fail the build** if orphaned records exist
- Query the model to **investigate** data quality issues
- Pass the flags downstream so marts can **exclude or flag** problematic rows

**The relationship tests in Module 2 are not enough on their own.** They test the seed data, which is clean. In a real pipeline with live ingestion, source data can arrive with referential integrity issues that your staging tests won't catch. The left join + quality flags strategy catches problems at the point they enter the transformation layer.

Add these singular tests to catch orphaned records:

```sql
-- tests/singular/test_no_orphaned_transactions.sql
-- Fails if any transaction cannot be matched to an account

select transaction_id
from {{ ref('int_customer_transactions') }}
where is_orphaned_transaction = true
```

```sql
-- tests/singular/test_no_missing_customers.sql
-- Fails if any transaction's account cannot be matched to a customer

select transaction_id
from {{ ref('int_customer_transactions') }}
where is_missing_customer = true
```

With our clean sample data these tests will pass. But in production they become your early warning system for upstream data quality issues.

### Step 4: Verify by temporarily materializing as a table

Since ephemeral models can't be queried directly, temporarily override:

```sql
{{ config(materialized='table') }}
```

Then run and query:

```bash
dbt run --select int_customer_transactions
```

```sql
-- Verify the join produced the right row count
SELECT count(*) FROM intermediate.int_customer_transactions;
-- Should be 96 (100 transactions minus 4 failed ones filtered in staging)

-- Verify customer data came through
SELECT
    customer_name,
    account_type,
    count(*) as transaction_count,
    sum(amount) as total_amount
FROM intermediate.int_customer_transactions
GROUP BY customer_name, account_type
ORDER BY total_amount DESC;

-- Check calculated fields
SELECT
    transaction_size_band,
    count(*) as count,
    avg(amount) as avg_amount
FROM intermediate.int_customer_transactions
GROUP BY transaction_size_band;
```

**Revert to ephemeral** once satisfied:
```sql
{{ config(materialized='ephemeral') }}
```

---

## Part 3: Building `int_account_balances` (25 mins)

This model aggregates transaction activity per account — the basis for account-level analytics in the gold layer.

Create `models/intermediate/int_account_balances.sql`:

```sql
-- Intermediate model: Account-level transaction summary
-- Aggregates completed transactions per account for use in gold layer marts

{{
    config(
        materialized='ephemeral'
    )
}}

with customer_transactions as (

    select * from {{ ref('int_customer_transactions') }}

),

account_summary as (

    select
        account_id,
        account_type,
        customer_id,
        customer_name,

        -- Transaction counts
        count(*)                                    as transaction_count,
        count(distinct transaction_date)            as active_days,
        count(distinct category)                    as unique_categories,

        -- Amount aggregations
        sum(
            case when transaction_type = 'credit'
            then amount else 0 end
        )                                           as total_credits,

        sum(
            case when transaction_type = 'debit'
            then amount else 0 end
        )                                           as total_debits,

        sum(
            case when transaction_type = 'transfer'
            then amount else 0 end
        )                                           as total_transfers,

        -- Net balance impact from transactions
        sum(
            case
                when transaction_type = 'credit' then  amount
                when transaction_type = 'debit'  then -amount
                else 0
            end
        )                                           as net_balance_change,

        -- Date boundaries
        min(transaction_date)                       as first_transaction_date,
        max(transaction_date)                       as last_transaction_date,

        -- Risk counts
        sum(case when risk_flag    then 1 else 0 end)  as risk_flagged_count,
        sum(case when is_high_value then 1 else 0 end) as high_value_count

    from customer_transactions
    where status = 'completed'
    group by
        account_id,
        account_type,
        customer_id,
        customer_name

)

select * from account_summary
```

### Key patterns to note

**CASE WHEN inside aggregations** — this is the standard pattern for conditional aggregation in SQL. Rather than filtering and running multiple queries, you calculate all variants in a single pass:

```sql
sum(case when transaction_type = 'credit' then amount else 0 end) as total_credits
```

**Net balance change** — credits increase balance, debits decrease it. The `case` expression converts transaction amounts to signed values before summing.

**`where status = 'completed'`** — only completed transactions affect balances. This filter belongs here, in the aggregation, not in staging (staging should keep all statuses for visibility).

---

## Part 4: DIY Exercise (20 mins)

### Exercise 1: Add a spending category breakdown

Add the following CTE to `int_customer_transactions` that calculates the top spending category per customer. Don't add it to the main joined CTE — create it as a separate CTE that could be joined in later.

```sql
-- Add this CTE after 'joined'
category_totals as (

    select
        customer_id,
        category,
        sum(amount) as category_total,
        count(*)    as category_count
    from joined
    where transaction_type = 'debit'
    group by customer_id, category

)
```

### Exercise 2: Add a `days_since_last_transaction` field

In `int_customer_transactions`, add a calculated field:

```sql
current_date - t.transaction_date as days_since_transaction
```

### Exercise 3: Explore the data with queries

With `int_customer_transactions` temporarily materialized as a table, run these exploratory queries:

```sql
-- Which customers have risk_flag = true?
SELECT
    customer_name,
    credit_score,
    risk_category,
    count(*) as flagged_transactions
FROM intermediate.int_customer_transactions
WHERE risk_flag = true
GROUP BY customer_name, credit_score, risk_category;

-- Transaction size band distribution by account type
SELECT
    account_type,
    transaction_size_band,
    count(*)        as count,
    sum(amount)     as total_amount
FROM intermediate.int_customer_transactions
GROUP BY account_type, transaction_size_band
ORDER BY account_type, total_amount DESC;

-- Average transaction by customer type
SELECT
    customer_type,
    avg(amount)  as avg_amount,
    sum(amount)  as total_amount,
    count(*)     as transaction_count
FROM intermediate.int_customer_transactions
GROUP BY customer_type;
```

---

## 🎯 Module 3 Deliverables

### 1. Both intermediate models building successfully
```bash
dbt build --select intermediate
```

### 2. Row count verification
```sql
-- Should match your expectations:
-- int_customer_transactions: 96 rows (100 - 4 failed)
-- int_account_balances: 10 rows (one per account that has transactions)
SELECT count(*) FROM intermediate.int_customer_transactions;
SELECT count(*) FROM intermediate.int_account_balances;
```

### 3. Join chain verification
```sql
-- Every transaction should have customer data (no nulls from failed joins)
SELECT
    count(*)                                as total_rows,
    count(customer_name)                    as rows_with_customer,
    count(*) - count(customer_name)         as missing_customer
FROM intermediate.int_customer_transactions;
```

---

## ✅ Self-Assessment Checklist

Before moving to Module 4, ensure you can:

- [ ] Explain the difference between staging and intermediate models
- [ ] Explain why ephemeral materialization is appropriate for intermediate models
- [ ] Describe the correct join chain: transactions → accounts → customers
- [ ] Explain why `inner join` is appropriate here (backed by relationship tests)
- [ ] Use conditional aggregation (`sum(case when ...)`) for pivot-style calculations
- [ ] Temporarily override materialization to inspect ephemeral models
- [ ] Both intermediate models build and produce correct row counts

---

## 🐛 Common Issues & Solutions

### Issue: "relation intermediate.int_customer_transactions does not exist"
Ephemeral models don't create a relation in the database. Either:
- Temporarily override to `materialized='table'` to inspect data
- Or query through a mart model that references it (Module 4)

### Issue: Row count is less than 96
Check that your staging filter is only excluding `status = 'failed'`. If you're filtering on something else you may be losing more rows.

### Issue: NULL customer_name in results
This means the `inner join` to customers failed for some rows. Check that every `account_id` in transactions exists in accounts, and every `customer_id` in accounts exists in customers. Your Module 2 relationship tests should catch this.

### Issue: "Column does not exist" errors
Double-check column aliases. If you aliased `customer_name as full_name` in `stg_customers`, you need to reference `full_name` (or re-alias it) in the intermediate model.

---

## 🚀 Quick Reference

```bash
# Run intermediate models only
dbt run --select intermediate

# Build (run + test) intermediate
dbt build --select intermediate

# Run a model and all models upstream of it
dbt build --select +int_customer_transactions

# Override materialization at runtime (useful for debugging)
dbt run --select int_customer_transactions --vars '{"materialized": "table"}'
```

---

## ➡️ Next Steps

**Ready for Module 4?**

You should now have:
- ✅ `int_customer_transactions` joining all three staging models
- ✅ `int_account_balances` aggregating per-account activity
- ✅ Calculated fields: `is_high_value`, `risk_flag`, `transaction_size_band`
- ✅ Understanding of ephemeral materialization

**In Module 4, you'll learn:**
- Building fact and dimension tables in the marts layer
- Creating reusable macros with Jinja
- Converting a model to incremental materialization
- Using dbt packages (`dbt_utils`)

**Continue to:** [Module 4: Gold Layer & Advanced Features](MODULE_04.md)

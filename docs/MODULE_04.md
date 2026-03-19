# Module 4: Gold Layer & Advanced Features

---

**Duration:** 90 minutes  
**Prerequisites:** Completed Module 3 — both intermediate models building successfully  
**Deliverable:** Two mart models, a working macro, and an incremental model

---

## 🎯 Learning Objectives

By the end of this module, you will:
- ✅ Build fact and dimension tables in the marts layer
- ✅ Create and call reusable macros with Jinja
- ✅ Convert a model to incremental materialization
- ✅ Use `is_incremental()` to process only new data
- ✅ Install and use a dbt package (`dbt_utils`)

---

## 📋 Module Overview

1. **Building the Fact Table** (20 mins)
2. **Building the Dimension Table** (20 mins)
3. **Creating Macros** (20 mins)
4. **Incremental Models** (20 mins)
5. **DIY Exercise** (10 mins)

---

## Part 1: Building the Fact Table (20 mins)

### What belongs in the gold layer?

Gold layer models are analytics-ready — they're what analysts, BI tools, and data scientists query directly. They should be:
- **Wide** — all the fields needed for a use case in one model
- **Named for the business concept** — `fct_daily_transactions`, not `int_joined_stuff`
- **Materialized as tables** — performance matters here
- **Well documented** — these are the models non-engineers will use

### Fact vs dimension tables

| | Fact Table | Dimension Table |
|---|---|---|
| Contains | Events, measurements, metrics | Descriptive attributes |
| Grain | One row per event (or aggregation) | One row per entity |
| Examples | `fct_daily_transactions` | `dim_customers`, `dim_accounts` |
| Updates | Grows over time | Relatively stable |

### Complete `fct_daily_transactions.sql`

Open `models/marts/finance/fct_daily_transactions.sql` and complete the `[Module 4]` TODOs:

```sql
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
        account_id,
        account_type,

        -- Transaction counts
        count(*)                                        as transaction_count,
        count(distinct account_id)                      as unique_accounts,
        count(distinct category)                        as unique_categories,

        -- Amount aggregations
        sum(amount)                                     as total_amount,
        avg(amount)                                     as avg_amount,
        min(amount)                                     as min_amount,
        max(amount)                                     as max_amount,

        -- Split by transaction type
        sum(case when transaction_type = 'debit'    then amount else 0 end) as total_debits,
        sum(case when transaction_type = 'credit'   then amount else 0 end) as total_credits,
        sum(case when transaction_type = 'transfer' then amount else 0 end) as total_transfers,

        -- Risk and value flags
        sum(case when is_high_value then 1 else 0 end)  as high_value_count,
        sum(case when risk_flag     then 1 else 0 end)  as risk_flagged_count,

        -- Transaction fee (using macro — added in Part 3)
        -- sum({{ calculate_transaction_fee('amount', 'transaction_type') }}) as total_fees

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
```

Leave the `total_fees` line commented out for now — you'll uncomment it in Part 3 after building the macro.

Run and verify:
```bash
dbt run --select fct_daily_transactions
```

```sql
SELECT
    transaction_date,
    sum(transaction_count) as total_transactions,
    sum(total_amount)      as daily_volume
FROM marts.fct_daily_transactions
GROUP BY transaction_date
ORDER BY transaction_date;
```

---

## Part 2: Building the Dimension Table (20 mins)

### Complete `dim_customers.sql`

Open `models/marts/finance/dim_customers.sql` and complete the `[Module 4]` TODOs:

```sql
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
        count(*)                    as total_transactions,
        sum(amount)                 as total_lifetime_value,
        avg(amount)                 as avg_transaction_amount,
        min(transaction_date)       as first_transaction_date,
        max(transaction_date)       as last_transaction_date,
        count(distinct account_id)  as account_count,
        count(distinct category)    as category_count,

        -- Days since last transaction
        current_date - max(transaction_date) as days_since_last_transaction

    from {{ ref('int_customer_transactions') }}
    where status = 'completed'
    group by customer_id

),

final as (

    select
        -- Customer attributes
        c.customer_id,
        c.full_name                                 as customer_name,
        c.email,
        c.customer_type,
        c.risk_category,
        c.credit_score,
        c.city,
        c.state,
        c.age_group,
        c.created_at                                as customer_since,
        c.customer_age_days,

        -- Transaction metrics (coalesce handles customers with no transactions)
        coalesce(m.total_transactions,        0)    as total_transactions,
        coalesce(m.total_lifetime_value,      0)    as total_lifetime_value,
        coalesce(m.avg_transaction_amount,    0)    as avg_transaction_amount,
        coalesce(m.account_count,             0)    as account_count,
        coalesce(m.category_count,            0)    as category_count,
        m.first_transaction_date,
        m.last_transaction_date,
        m.days_since_last_transaction,

        -- Customer segment derived from lifetime value
        case
            when coalesce(m.total_lifetime_value, 0) >= 10000 then 'platinum'
            when coalesce(m.total_lifetime_value, 0) >=  5000 then 'gold'
            when coalesce(m.total_lifetime_value, 0) >=  1000 then 'silver'
            else 'bronze'
        end                                         as customer_segment

    from customers c
    left join customer_metrics m on c.customer_id = m.customer_id

)

select * from final
```

### Why `left join` in `dim_customers`?

`dim_customers` wants **all** customers — even ones who have never made a transaction. A `left join` ensures customers without transactions appear in the dimension with zero metrics (`coalesce(m.total_transactions, 0)`).

Note that `int_customer_transactions` also uses `left join` — but for a different reason. There it preserves orphaned transactions and surfaces data quality issues as nulls rather than silently dropping them. The principle is the same: **never use inner join when it would hide missing data.**

Run and verify:
```bash
dbt run --select dim_customers
```

```sql
SELECT
    customer_segment,
    count(*)                    as customer_count,
    avg(total_lifetime_value)   as avg_ltv,
    avg(credit_score)           as avg_credit_score
FROM marts.dim_customers
GROUP BY customer_segment
ORDER BY avg_ltv DESC;
```

---

## Part 3: Creating Macros (20 mins)

### What are macros?

Macros are reusable Jinja functions that can be called from any model. Before writing one, it's worth being deliberate about when they actually help.

### When macros are worth it — and when they aren't

**The core question:** would someone reading the calling model understand what it does without jumping to another file?

Macros introduce indirection. A reader sees `{{ calculate_transaction_fee('amount', 'transaction_type') }}` and has to go find that file to understand what's happening. That cost is only worth paying if the alternative — duplicating the logic — is worse.

**Ask these three questions before writing a macro:**

1. Is this logic used in 3+ models? If not, just write the SQL inline.
2. Is it complex enough that copy-pasting could introduce a subtle mistake? Simple arithmetic doesn't qualify.
3. Does a business stakeholder own this definition — meaning if it changes, it needs to change everywhere consistently?

**Good candidate — active account definition:**

```sql
-- Used as a WHERE clause in 10 different models.
-- The definition involves multiple conditions and is owned by the finance team.
-- If the definition changes, one file update fixes all models.
{% macro is_active_account() %}
    account_status = 'active'
    and current_balance >= 0
    and open_date <= current_date
    and not exists (
        select 1 from fraud_flags
        where fraud_flags.account_id = accounts.account_id
    )
{% endmacro %}
```

Without the macro, this block gets copy-pasted across models. One engineer misses a condition, another adds a new one in only some models — the definition silently drifts. That's the problem macros solve.

**Bad candidate — cents to dollars:**

```sql
-- Don't do this:
{% macro cents_to_dollars(column_name) %}
    ({{ column_name }} / 100.0)
{% endmacro %}

-- Just write this:
amount / 100.0
```

Any engineer reading `amount / 100.0` understands it instantly. The macro adds a layer of indirection for zero benefit. It also hides the SQL from anyone skimming the model.

**Borderline — the fee calculation in this workshop:**

The `calculate_transaction_fee` macro below is a reasonable example because the fee rules are specific enough that copy-pasting could introduce mistakes, and they're the kind of business rules that change when the product team updates pricing. In practice you'd also want to discuss whether this logic belongs in a macro or a lookup table — but for learning purposes it works well.

### Complete the transaction fee macro

Open `macros/calculate_transaction_fee.sql`. It's already scaffolded:

```sql
{% macro calculate_transaction_fee(amount, transaction_type) %}

    case
        when {{ transaction_type }} = 'debit'    then {{ amount }} * 0.01
        when {{ transaction_type }} = 'credit'   then 0
        when {{ transaction_type }} = 'transfer' then
            case
                when {{ amount }} < 1000 then 2.50
                else {{ amount }} * 0.005
            end
        else 0
    end

{% endmacro %}
```

**Fee rules:**
- Debit transactions: 1% of amount
- Credit transactions: no fee
- Transfers under $1,000: flat $2.50 fee
- Transfers $1,000+: 0.5% of amount

### Call the macro in `fct_daily_transactions`

Now uncomment the `total_fees` line in `fct_daily_transactions.sql`:

```sql
sum({{ calculate_transaction_fee('amount', 'transaction_type') }}) as total_fees
```

Run and check the compiled SQL to see how the macro was expanded:

```bash
dbt run --select fct_daily_transactions
```

```bash
# View the compiled SQL — the macro is inlined as plain SQL
type target\compiled\finance_analytics\models\marts\finance\fct_daily_transactions.sql
```

You'll see `{{ calculate_transaction_fee(...) }}` replaced with the full CASE expression. This is a useful reminder that macros are a **development convenience**, not a runtime abstraction — the compiled SQL is always plain, readable SQL.

### Audit columns macro

Create `macros/audit_columns.sql`:

```sql
{% macro audit_columns() %}
    current_timestamp   as created_at,
    current_timestamp   as updated_at,
    '{{ invocation_id }}' as dbt_run_id
{% endmacro %}
```

This one is marginal — it's only three lines and any engineer would understand them without a macro. The justification is purely consistency: every model that calls `{{ audit_columns() }}` is guaranteed to use the same column names and types. If you renamed `created_at` to `inserted_at` across 20 models, one macro change covers all of them.

It's a reasonable use but not a compelling one. Don't pattern-match from this and start wrapping everything in macros.

Call it in any model's SELECT list:
```sql
select
    transaction_id,
    amount,
    {{ audit_columns() }}
from ...
```

---

## Part 4: Incremental Models (20 mins)

### What is an incremental model?

By default, `materialized='table'` drops and recreates the entire table on every `dbt run`. For large tables this is expensive. An incremental model only processes **new or changed rows**, appending or merging them into the existing table.

### When to use incremental

Use incremental when:
- The table is large (millions+ rows)
- Data arrives continuously (e.g. daily transactions)
- Full refresh takes too long

Don't use incremental when:
- The table is small (use `table` — simpler)
- Historical data changes frequently (incremental misses updates)
- You're still in development (full refresh is safer)

### Convert `fct_daily_transactions` to incremental

```sql
{{
    config(
        materialized='incremental',
        unique_key='transaction_date || \'_\' || customer_id || \'_\' || account_id',
        on_schema_change='fail'
    )
}}

with customer_transactions as (

    select * from {{ ref('int_customer_transactions') }}

    {% if is_incremental() %}
    -- On incremental runs, only process transactions since the last run
    -- We look back 1 day to catch any late-arriving data
    where transaction_date >= (
        select dateadd('day', -1, max(transaction_date))
        from {{ this }}
    )
    {% endif %}

),

-- ... rest of the model is identical
```

### Understanding `is_incremental()`

The `{% if is_incremental() %}` block only executes when:
1. The target table already exists
2. dbt is NOT running with `--full-refresh`

On the first run (table doesn't exist yet), dbt runs the full query and creates the table. On subsequent runs, only new rows are processed.

### Run incremental

```bash
# First run — builds the full table
dbt run --select fct_daily_transactions

# Second run — only processes new rows (none, since data hasn't changed)
dbt run --select fct_daily_transactions

# Force a full rebuild
dbt run --select fct_daily_transactions --full-refresh
```

### Understanding `unique_key`

The `unique_key` tells dbt how to handle duplicates when merging:
- If a row with the same key already exists → **update** it
- If the key is new → **insert** it

Our key is `transaction_date + customer_id + account_id` because that's the grain of the fact table.

### Installing dbt packages

Open `packages.yml` and uncomment `dbt_utils`:

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1
```

Install it:
```bash
dbt deps
```

Now you can use `dbt_utils` macros. A useful one for unique keys:

```sql
-- Replace the string concatenation with dbt_utils.generate_surrogate_key
unique_key='{{ dbt_utils.generate_surrogate_key(["transaction_date", "customer_id", "account_id"]) }}'
```

---

## Part 5: DIY Exercise (10 mins)

### Exercise 1: Build a `dim_accounts` dimension table

Create `models/marts/finance/dim_accounts.sql` following the pattern from `dim_customers`:

**Requirements:**
- All columns from `stg_accounts`
- Joined metrics from `int_account_balances`: `transaction_count`, `total_credits`, `total_debits`, `net_balance_change`, `first_transaction_date`, `last_transaction_date`
- Use `left join` so accounts with no transactions still appear
- Add an `account_health` classification:
  - `'healthy'` — net_balance_change >= 0
  - `'declining'` — net_balance_change < 0
  - `'inactive'` — no transactions (null metrics)

### Exercise 2: Uncomment total_fees and verify

Make sure the `total_fees` column is uncommented in `fct_daily_transactions` and run:

```sql
SELECT
    transaction_date,
    sum(total_amount)   as gross_volume,
    sum(total_fees)     as total_fees,
    sum(total_fees) / sum(total_amount) * 100 as fee_percentage
FROM marts.fct_daily_transactions
GROUP BY transaction_date
ORDER BY transaction_date;
```

### Exercise 3: Run the full build

```bash
dbt build
```

All models — staging through marts — should build and test cleanly in a single command.

---

## 🎯 Module 4 Deliverables

### 1. Full build passing
```bash
dbt build
```
All models and tests green.

### 2. Mart tables populated
```sql
SELECT 'fct_daily_transactions' as model, count(*) as rows FROM marts.fct_daily_transactions
UNION ALL
SELECT 'dim_customers', count(*) FROM marts.dim_customers;
```

### 3. Macro compiled correctly
```bash
type target\compiled\finance_analytics\models\marts\finance\fct_daily_transactions.sql
```
Verify the `calculate_transaction_fee` macro has been expanded inline.

### 4. Customer segment distribution
```sql
SELECT customer_segment, count(*) as count
FROM marts.dim_customers
GROUP BY customer_segment;
```

---

## ✅ Self-Assessment Checklist

Before moving to Module 5, ensure you can:

- [ ] Explain the difference between fact and dimension tables
- [ ] Explain why `dim_customers` uses `left join` but `int_customer_transactions` uses `inner join`
- [ ] Write and call a macro from a model
- [ ] Explain when incremental materialization is appropriate
- [ ] Explain what `is_incremental()` does and when it evaluates to true
- [ ] Explain what `unique_key` does in an incremental model
- [ ] Install a dbt package with `dbt deps`
- [ ] `dbt build` completes cleanly across all layers

---

## 🐛 Common Issues & Solutions

### Issue: Macro not found
Check the macro file is in the `macros/` directory and the macro name matches exactly. Run `dbt parse` to validate.

### Issue: Incremental model not filtering
If the table doesn't exist yet, `is_incremental()` returns false and the full query runs. This is correct behaviour. Use `--full-refresh` to force it.

### Issue: `unique_key` conflict
If you see duplicate rows after an incremental run, your `unique_key` doesn't uniquely identify rows. Add more columns to the key or reconsider the grain of the model.

### Issue: `dbt_utils` macro not found after `dbt deps`
Run `dbt clean` then `dbt deps` again. Check `dbt_packages/` folder exists after running.

---

## ➡️ Next Steps

**Ready for Module 5?**

You should now have:
- ✅ `fct_daily_transactions` (table or incremental) with fee macro
- ✅ `dim_customers` with lifetime metrics and segmentation
- ✅ `calculate_transaction_fee` macro
- ✅ Full `dbt build` passing

**In Module 5, you'll learn:**
- Advanced tests with `dbt_expectations`
- Writing custom generic tests
- Generating and navigating dbt documentation
- Data quality best practices

**Continue to:** [Module 5: Advanced Testing & Data Quality](MODULE_05.md)

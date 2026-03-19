# Module 2: Source Configuration & Testing

---

**Duration:** 75 minutes  
**Prerequisites:** Completed Module 1 — three staging models running successfully  
**Deliverable:** Sources configured, 15+ tests passing across all staging models

---

## 🎯 Learning Objectives

By the end of this module, you will:
- ✅ Understand the difference between `ref()` and `source()` and when to use each
- ✅ Configure sources in `_sources.yml` to replace seed `ref()` calls
- ✅ Write generic schema tests (unique, not_null, accepted_values, relationships)
- ✅ Write singular tests for custom business rules
- ✅ Run `dbt test` and interpret failures

---

## 📋 Module Overview

1. **Configuring Sources** (20 mins)
2. **Generic Schema Tests** (25 mins)
3. **Singular Tests** (15 mins)
4. **DIY Exercise** (15 mins)

---

## Part 1: Configuring Sources (20 mins)

### Why sources?

In Module 1, staging models referenced seeds using `ref()`:

```sql
select * from {{ ref('transactions') }}
```

This works, but it's not semantically correct. `ref()` is meant for dbt-managed objects — models and seeds that dbt owns. Your raw source data (in a real project, tables loaded by an ingestion tool like Fivetran or Airbyte) isn't managed by dbt. `source()` is the right function for data that originates outside dbt.

**The benefits of using `source()` over `ref()` for raw data:**
- Declares the true origin of data in the lineage graph
- Enables source freshness checks (`dbt source freshness`)
- Makes it explicit which tables are "inputs" vs dbt-created tables
- Documents raw table structure alongside your models

### Configuring `_sources.yml`

Open `models/staging/_sources.yml`. It's fully commented out with `[Module 2]` TODOs. Uncomment and complete it:

```yaml
version: 2

sources:
  - name: bronze
    description: Bronze layer - raw data from CSV seeds
    database: finance_analytics  # The DuckDB database file (finance_analytics.duckdb)
    schema: bronze        # The schema where seeds are loaded

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
            description: Foreign key to accounts table
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
            description: Type of account (checking, savings, credit_card)
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

### Update staging models to use `source()`

Now update each staging model to replace `ref()` with `source()`.

**stg_transactions.sql** — change the source_data CTE:
```sql
with source_data as (

    -- [Module 2]: Now using source() instead of ref()
    select * from {{ source('bronze', 'transactions') }}

),
```

**stg_accounts.sql:**
```sql
with source_data as (

    select * from {{ source('bronze', 'accounts') }}

),
```

**stg_customers.sql:**
```sql
with source_data as (

    select * from {{ source('bronze', 'customers') }}

),
```

### Run and verify

```bash
dbt run --select staging
```

The compiled SQL output is identical to Module 1 — both compile to `bronze.transactions`. The difference is semantic: dbt now knows these are external sources, not dbt-created objects.

Check the lineage graph to see the difference:
```bash
dbt docs generate
dbt docs serve
```

You'll now see source nodes (green) feeding into your staging models, clearly showing where data originates.

---

## Part 2: Generic Schema Tests (25 mins)

### What are tests in dbt?

dbt has two types of tests:

**Generic tests** — reusable tests applied to columns via YAML config. dbt ships with four built-in ones:
- `unique` — no duplicate values in the column
- `not_null` — no null values in the column
- `accepted_values` — column only contains values from a defined list
- `relationships` — column values exist in another model's column (referential integrity)

**Singular tests** — custom SQL queries you write in `tests/`. Any query that returns rows is a failing test.

### Completing `_stg_models.yml`

Open `models/staging/_stg_models.yml`. Complete the schema tests for all three models:

```yaml
version: 2

models:
  - name: stg_transactions
    description: >
      Staging layer for transaction data. Excludes failed transactions.
      Customer information is accessed through the account relationship.
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
        description: Transaction amount in USD, cast to decimal(10,2)
        tests:
          - not_null

      - name: transaction_type
        description: Type of transaction
        tests:
          - accepted_values:
              arguments:
                values: ['debit', 'credit', 'transfer']

      - name: status
        description: Transaction processing status (failed transactions excluded at staging)
        tests:
          - accepted_values:
              arguments:
                values: ['completed', 'pending']

```

Now add `stg_accounts` and `stg_customers` yourself using `stg_transactions` as the pattern. The hints below tell you which tests each column needs — the full solutions are in `SOLUTIONS.md` if you get stuck.

**stg_accounts — required tests per column:**

| Column | Tests needed |
|--------|-------------|
| `account_id` | `unique`, `not_null` |
| `customer_id` | `not_null`, `relationships` → `stg_customers.customer_id` |
| `account_type` | `not_null`, `accepted_values`: checking, savings, credit_card |
| `account_status` | `accepted_values`: active, closed, suspended |
| `current_balance` | `not_null` |

**stg_customers — required tests per column:**

| Column | Tests needed |
|--------|-------------|
| `customer_id` | `unique`, `not_null` |
| `email` | `unique`, `not_null` |
| `customer_type` | `accepted_values`: individual, business |
| `risk_category` | `accepted_values`: low, medium, high |
| `credit_score` | `not_null` |

> 💡 **Hint:** The `relationships` test syntax is shown in the `stg_transactions` example above for `account_id`. Use the same pattern for `stg_accounts.customer_id`.

### Run the tests

```bash
dbt test --select staging
```

**Expected output:**
```
Found 6 models, 18 tests

1 of 18 START test accepted_values_stg_transactions_status__completed__pending ... [RUN]
2 of 18 START test accepted_values_stg_transactions_transaction_type__debit__credit__transfer ... [RUN]
...
18 of 18 PASS relationships_stg_accounts_customer_id__customer_id__ref_stg_customers_ ... [PASS]

Done. PASS=18 WARN=0 ERROR=0 SKIP=0 TOTAL=18
```

### Understanding test failures

Let's intentionally break a test to understand failures. Temporarily add an invalid value test:

```yaml
# Add temporarily to stg_transactions status test:
- accepted_values:
    arguments:
      values: ['completed']   # Intentionally missing 'pending'
```

Run:
```bash
dbt test --select stg_transactions
```

You'll see:
```
FAIL 1 accepted_values_stg_transactions_status__completed_ ............. [FAIL 3]
```

dbt tells you exactly how many rows failed. The compiled test SQL is in:
```
target/compiled/finance_analytics/models/staging/_stg_models.yml/
```

Open it — you'll see dbt generates a `SELECT` query that returns failing rows. **Any test that returns rows is a failure.** This is the pattern for all tests in dbt, including singular tests you write yourself.

Revert the change before continuing.

---

## Part 3: Singular Tests (15 mins)

### What are singular tests?

Singular tests are plain SQL files in `tests/`. Any query that returns rows is a failing test. They're perfect for business rules that can't be expressed as generic tests.

### Existing singular test

Open `tests/singular/test_transaction_date_not_future.sql`:

```sql
-- Test: No transactions should have a future date
-- Returns rows that FAIL the test (i.e. future-dated transactions)

select
    transaction_id,
    transaction_date,
    current_date as today
from {{ ref('stg_transactions') }}
where transaction_date > current_date
```

Run it:
```bash
dbt test --select test_transaction_date_not_future
```

This should pass since all our sample data is from Jan-Feb 2024.

### Write a new singular test

Create `tests/singular/test_no_negative_amounts.sql`:

```sql
-- Test: Transaction amounts should never be negative
-- A negative amount would indicate a data quality issue upstream

select
    transaction_id,
    amount
from {{ ref('stg_transactions') }}
where amount < 0
```

Create `tests/singular/test_credit_score_range.sql`:

```sql
-- Test: Credit scores must be within the valid 300-850 range

select
    customer_id,
    credit_score
from {{ ref('stg_customers') }}
where credit_score < 300
   or credit_score > 850
```

Run all tests together:
```bash
dbt test
```

### The golden rule of dbt tests

> A test query that returns **zero rows** = **PASS**  
> A test query that returns **any rows** = **FAIL**

This means you write tests to find the *bad* data. The test "passes" when there is nothing bad to find.

---

## Part 4: DIY Exercise (15 mins)

### Exercise 1: Add a relationships test for transactions → accounts

In `_stg_models.yml`, the `account_id` column in `stg_transactions` already has a `relationships` test. Verify you understand how it works by running just that test:

```bash
dbt test --select stg_transactions --greedy
```

Now add the equivalent test on `stg_accounts.customer_id` → `stg_customers.customer_id` if you haven't already.

### Exercise 2: Write a singular test for orphaned accounts

Create `tests/singular/test_no_orphaned_accounts.sql` — a test that finds any account whose `customer_id` does not exist in `stg_customers`:

```sql
-- Hint: Use a LEFT JOIN and filter WHERE c.customer_id IS NULL
select
    a.account_id,
    a.customer_id
from {{ ref('stg_accounts') }} a
left join {{ ref('stg_customers') }} c on a.customer_id = c.customer_id
where c.customer_id is null
```

### Exercise 3: Run `dbt build`

`dbt build` combines `dbt run` + `dbt test` in a single command, running tests immediately after each model. Get used to this — it's what you'll use in production.

```bash
dbt build --select staging
```

Notice how tests run right after the model they test. If a model's tests fail, dbt skips downstream models that depend on it.

---

## 🎯 Module 2 Deliverables

Take screenshots of:

### 1. All tests passing
```bash
dbt test
```
Should show 20+ tests all passing.

### 2. Source lineage in dbt docs
```bash
dbt docs generate && dbt docs serve
```
Navigate to the DAG — you should see green source nodes feeding into your staging models.

### 3. Query to verify referential integrity
```sql
-- Verify every transaction links to a valid account
SELECT
    count(*) as total_transactions,
    count(a.account_id) as matched_accounts,
    count(*) - count(a.account_id) as unmatched
FROM staging.stg_transactions t
LEFT JOIN staging.stg_accounts a ON t.account_id = a.account_id;
```

---

## ✅ Self-Assessment Checklist

Before moving to Module 3, ensure you can:

- [ ] Explain why `source()` is preferred over `ref()` for raw data
- [ ] Understand that `source()` and `ref()` can compile to the same SQL
- [ ] Write `unique`, `not_null`, `accepted_values`, and `relationships` tests
- [ ] Explain the golden rule: a test passes when it returns zero rows
- [ ] Write a singular test for a custom business rule
- [ ] Run `dbt build` and understand the difference from `dbt run` + `dbt test`
- [ ] All 20+ tests pass

---

## 🐛 Common Issues & Solutions

### Issue: "Source bronze.transactions was not found"
The `_sources.yml` file may still be fully commented. Make sure the `sources:` block is uncommented **and** indentation is correct — YAML is whitespace-sensitive.

```bash
# Validate YAML syntax
dbt parse
```

### Issue: `relationships` test failing
Check that the referenced column name exactly matches. `ref('stg_accounts')` with `field: account_id` means dbt looks for `account_id` in the compiled `stg_accounts` view.

### Issue: Tests running but not finding my new test file
New singular test files in `tests/` are picked up automatically. If dbt doesn't see it, run:
```bash
dbt clean
dbt build
```

### Issue: `accepted_values` warning about deprecated syntax
Use the `arguments:` nesting — this is required for dbt 1.9+:
```yaml
# Correct (dbt 1.9+)
- accepted_values:
    arguments:
      values: ['debit', 'credit', 'transfer']
```

---

## 🚀 Quick Reference

```bash
dbt test                              # Run all tests
dbt test --select stg_transactions    # Test one model
dbt test --select staging             # Test all in folder
dbt build --select staging            # Run + test together
dbt source freshness                  # Check source freshness (after adding loaded_at)
dbt parse                             # Validate project without running
```

---

## ➡️ Next Steps

**Ready for Module 3?**

You should now have:
- ✅ Sources configured in `_sources.yml`
- ✅ All staging models using `source()` for raw data
- ✅ 20+ tests passing across all three staging models
- ✅ Custom singular tests for business rules

**In Module 3, you'll learn:**
- Building intermediate models that join across entities
- Applying business logic (calculated fields, categorization)
- Understanding ephemeral materialization in practice
- Building the full transaction → account → customer join chain

**Continue to:** [Module 3: Silver Layer](MODULE_03.md)

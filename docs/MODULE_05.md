# Module 5: Advanced Testing & Data Quality

---

**Duration:** 60 minutes  
**Prerequisites:** Completed Module 4 — full `dbt build` passing  
**Deliverable:** 30+ tests including dbt_expectations, custom generic tests, and full documentation

---

## 🎯 Learning Objectives

By the end of this module, you will:
- ✅ Install and use `dbt_expectations` for advanced column-level tests
- ✅ Write custom generic tests reusable across models
- ✅ Generate and navigate dbt documentation
- ✅ Understand a layered testing strategy

---

## 📋 Module Overview

1. **Testing Strategy** (10 mins)
2. **dbt_expectations Package** (20 mins)
3. **Custom Generic Tests** (15 mins)
4. **Documentation** (15 mins)

---

## Part 1: Testing Strategy (10 mins)

### A layered approach to testing

Not all tests are equal. A good testing strategy tests at multiple layers with different purposes:

| Layer | What to test | Test type |
|-------|-------------|-----------|
| Source | PK uniqueness, not null, referential integrity | Generic (in `_sources.yml`) |
| Staging | Same as source + accepted_values, type correctness | Generic (in `_stg_models.yml`) |
| Intermediate | Business rule invariants, join correctness | Singular |
| Marts | Aggregation correctness, expected row counts, value ranges | Generic + dbt_expectations |

### The 80/20 rule for tests

You can't test everything. Focus tests on:
1. **Primary keys** — always unique and not null
2. **Foreign keys** — referential integrity across models
3. **Accepted values** — categoricals stay in their valid set
4. **Business-critical columns** — amounts, dates, statuses

Tests that are slow, fragile, or require constant maintenance aren't worth writing.

---

## Part 2: dbt_expectations Package (20 mins)

### Install the package

Open `packages.yml` and uncomment `dbt_expectations`:

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1

  - package: calogica/dbt_expectations
    version: 0.10.1
```

Install:
```bash
dbt deps
```

### What dbt_expectations provides

`dbt_expectations` is inspired by the Great Expectations Python library. It adds tests for:
- Row counts and table shape
- Column value ranges and distributions
- String pattern matching (regex)
- Statistical properties (mean, median, standard deviation)

### Add expectations to marts models

Create `models/marts/finance/_mart_models.yml`:

```yaml
version: 2

models:
  - name: fct_daily_transactions
    description: >
      Daily transaction summary per customer and account.
      Grain: one row per transaction_date + customer_id + account_id combination.
      Only includes completed transactions.
    tests:
      - dbt_expectations.expect_table_row_count_to_be_between:
          min_value: 1
          max_value: 100000

    columns:
      - name: transaction_date
        description: Date of the transactions being summarised
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: "'2020-01-01'"
              max_value: "current_date"

      - name: total_amount
        description: Sum of all completed transaction amounts for this date/customer/account
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 1000000

      - name: transaction_count
        description: Number of completed transactions
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 1
              max_value: 10000

      - name: avg_amount
        description: Average transaction amount
        tests:
          - dbt_expectations.expect_column_mean_to_be_between:
              min_value: 10
              max_value: 10000

  - name: dim_customers
    description: >
      Customer dimension table with lifetime transaction metrics and segmentation.
      One row per customer. Includes customers with no transactions (left join).
    tests:
      - dbt_expectations.expect_table_row_count_to_equal:
          value: 10    # We have exactly 10 customers in our sample data

    columns:
      - name: customer_id
        description: Unique customer identifier
        tests:
          - unique
          - not_null

      - name: email
        description: Customer email — must be a valid email format
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_match_regex:
              regex: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"

      - name: credit_score
        description: Customer credit score — valid range is 300 to 850
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 300
              max_value: 850

      - name: customer_segment
        description: Derived customer segment based on lifetime value
        tests:
          - accepted_values:
              arguments:
                values: ['platinum', 'gold', 'silver', 'bronze']

      - name: total_lifetime_value
        description: Total amount of all completed transactions
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 10000000
```

Run just the mart tests:
```bash
dbt test --select marts
```

---

## Part 3: Custom Generic Tests (15 mins)

### What is a custom generic test?

Generic tests (like `unique`, `not_null`) are reusable — you define them once and apply them to any column on any model. You can write your own in `tests/generic/`.

A generic test is a Jinja macro that takes at least two arguments: `model` and `column_name`. It returns a SQL query that should return zero rows when the test passes.

### Create a generic test for valid ID format

Create `tests/generic/test_valid_id_format.sql`:

```sql
{% test valid_id_format(model, column_name, prefix) %}

-- Tests that ID columns follow the pattern PREFIX + 3 digits
-- e.g. CUST001, ACC001, TXN001

select {{ column_name }}
from {{ model }}
where
    {{ column_name }} not like '{{ prefix }}%'
    or length({{ column_name }}) != length('{{ prefix }}') + 3

{% endtest %}
```

Apply it in `_stg_models.yml`:

```yaml
# Under stg_transactions columns:
- name: transaction_id
  tests:
    - unique
    - not_null
    - valid_id_format:
        prefix: 'TXN'

# Under stg_accounts columns:
- name: account_id
  tests:
    - unique
    - not_null
    - valid_id_format:
        prefix: 'ACC'

# Under stg_customers columns:
- name: customer_id
  tests:
    - unique
    - not_null
    - valid_id_format:
        prefix: 'CUST'
```

### Create a generic test for positive values

Create `tests/generic/test_positive_value.sql`:

```sql
{% test positive_value(model, column_name) %}

-- Tests that a numeric column contains only positive values

select {{ column_name }}
from {{ model }}
where {{ column_name }} <= 0

{% endtest %}
```

Apply to amounts:
```yaml
# Under stg_transactions columns:
- name: amount
  tests:
    - not_null
    - positive_value
```

Run all tests to verify:
```bash
dbt test
```

---

## Part 4: Documentation (15 mins)

### Writing good descriptions

dbt documentation lives in your YAML files. Descriptions support Markdown:

```yaml
models:
  - name: fct_daily_transactions
    description: |
      **Daily transaction summary** per customer and account.

      **Grain:** One row per `transaction_date + customer_id + account_id` combination.

      **Filters:** Only completed transactions are included. Failed and pending
      transactions are excluded at the staging layer.

      **Source:** Derived from `int_customer_transactions` which joins
      `stg_transactions → stg_accounts → stg_customers`.
```

### Generate and serve documentation

```bash
dbt docs generate
dbt docs serve
```

This opens a browser at `http://localhost:8080`. Explore:

1. **Model list** — all models with descriptions
2. **Lineage graph (DAG)** — click any model → click the graph icon in the bottom right
3. **Column details** — click any model → see all columns with descriptions and tests
4. **Source definitions** — green nodes show where raw data enters

### The DAG

The Directed Acyclic Graph visualises your entire pipeline. For this project you should see:

```
[bronze sources]
      ↓
[stg_transactions] [stg_accounts] [stg_customers]
              ↓           ↓            ↓
           [int_customer_transactions]
                      ↓
       [fct_daily_transactions]  [dim_customers]
```

Click any model in the graph to see its SQL, description, columns, and tests.

### Adding column descriptions at scale

For models with many columns, consider a `column_descriptions` variable approach or add a separate `docs` block. At minimum, document:
- The primary key
- Any foreign keys
- Any non-obvious derived or calculated columns

---

## 🎯 Module 5 Deliverables

### 1. All tests passing (30+)
```bash
dbt test
```

### 2. Documentation site running
```bash
dbt docs generate && dbt docs serve
```
Screenshot the DAG showing the full lineage from sources to marts.

### 3. Count of tests by model
```sql
-- After generating docs, check target/manifest.json
-- Or simply run:
dbt test --store-failures
```

### 4. Custom generic test in action
Verify `valid_id_format` is being applied:
```bash
dbt test --select stg_transactions --show-output
```

---

## ✅ Self-Assessment Checklist

Before moving to Module 6, ensure you can:

- [ ] Explain a layered testing strategy and why different layers need different tests
- [ ] Install a dbt package and use its macros/tests
- [ ] Write a `dbt_expectations` test for a column value range
- [ ] Write a custom generic test with a parameter
- [ ] Write a model description that would be useful to a non-engineer
- [ ] Navigate the dbt docs DAG and explain the lineage
- [ ] `dbt test` shows 30+ passing tests

---

## 🐛 Common Issues & Solutions

### Issue: `dbt_expectations` tests not found
Run `dbt deps` after adding the package to `packages.yml`. If it still fails, check the version is compatible with your dbt version at [hub.getdbt.com](https://hub.getdbt.com).

### Issue: Custom generic test not found
Check the file is in `tests/generic/` and the macro name matches the test name in YAML (e.g. macro `test_valid_id_format` is called as `valid_id_format`).

### Issue: `dbt docs serve` opens but DAG is empty
Run `dbt docs generate` first. The serve command only renders — it doesn't generate.

### Issue: Regex test failing on valid emails
DuckDB uses RE2 regex syntax. Double-check backslash escaping — in YAML you need `\\` to represent a single `\` in the regex.

---

## ➡️ Next Steps

**Ready for Module 6?**

You should now have:
- ✅ 30+ tests across all layers
- ✅ `dbt_expectations` tests on mart models
- ✅ Custom generic tests for ID format and positive values
- ✅ Full documentation site with lineage graph

**In Module 6, you'll learn:**
- Using tags and selectors to run model subsets
- SQL linting with SQLFluff
- Production deployment patterns
- CI/CD fundamentals

**Continue to:** [Module 6: Production Workflows](MODULE_06.md)

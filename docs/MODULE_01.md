# Module 1: Environment Setup & dbt Fundamentals

**Duration:** 90 minutes  
**Prerequisites:** Completed main setup from README.md  
**Deliverable:** Working dbt project with three staging models

---

## 🎯 Learning Objectives

By the end of this module, you will:
- ✅ Understand dbt project structure and configuration files
- ✅ Load sample data using dbt seeds
- ✅ Create your first staging models
- ✅ Use the `ref()` function to create dependencies
- ✅ Query results in DuckDB via VS Code
- ✅ Understand materialization strategies (views vs tables)

---

## 📋 Module Overview

1. **Project Structure Tour** (15 mins)
2. **Loading Sample Data** (15 mins)
3. **Creating Your First Model** (30 mins)
4. **DIY Exercise: Complete Remaining Staging Models** (30 mins)

---

## Part 1: Project Structure Tour (15 mins)

### Understanding the dbt Project Structure

Let's explore the files and folders in your dbt project:

```
dbt-finance-workshop/
├── dbt_project.yml          # Main project configuration
├── profiles.yml             # Database connection config (template)
├── models/                  # Where all your SQL models live
│   ├── staging/            # Bronze → Silver transformations
│   ├── intermediate/       # Silver layer business logic
│   └── marts/              # Gold layer (final analytics tables)
│       └── finance/        # Finance-specific marts
├── seeds/                   # CSV files to load as tables
│   ├── transactions.csv
│   ├── accounts.csv
│   └── customers.csv
├── tests/                   # Custom singular tests
│   └── singular/
├── macros/                  # Reusable SQL functions
├── analyses/               # Ad-hoc analysis queries (not run)
└── README.md               # Project documentation
```

### A Note on YAML File Naming

As you work through the modules you'll create several `.yml` files for sources, model tests, and seed configurations. Two things worth knowing upfront:

**Any filename works** — dbt scans all `.yml` files in your configured paths and reads whatever it finds. `schema.yml`, `properties.yml`, `my_file.yml` — dbt doesn't care.

**Convention is to lead with an underscore.** The dbt community standard (from dbt Labs' own style guide) is:

| File | Purpose |
|------|---------|
| `_sources.yml` | Source definitions (`sources:` block) |
| `_stg_models.yml` | Staging model tests and descriptions |
| `_int_models.yml` | Intermediate model tests and descriptions |
| `_mart_models.yml` | Mart model tests and descriptions |
| `_seeds.yml` | Seed column types and tests |

The leading `_` serves two purposes:
- Sorts the file to the **top** of the folder in VS Code's explorer, so config files are visually separated from `.sql` files
- Makes it immediately obvious it's metadata, not a model

**Keep sources separate from models.** Don't put `sources:` and `models:` blocks in the same file — as the project grows it becomes hard to navigate. This project uses `_sources.yml` exclusively for source definitions and `_stg_models.yml` for model documentation and tests.

**One yml per folder is fine for small projects.** On larger projects teams sometimes split into one yml per model (e.g. `stg_transactions.yml`) for easier code review. For this workshop, one file per folder is enough.

---

### Key Configuration File: dbt_project.yml

Open `dbt_project.yml` in VS Code. This is the central config for the entire project — it controls where dbt looks for files, how models are materialized, and what schemas they land in.

The file is heavily commented to explain each setting. Read through it now before continuing — the comments answer the questions you're about to have. A few concepts worth calling out:

**Materialization** controls how dbt persists a model in the database:
- `view` — virtual table, no data stored, query re-runs every time it's referenced (good for staging)
- `table` — physical table, data is stored (good for marts that are queried often)
- `ephemeral` — never created in the DB at all, inlined as a CTE wherever referenced (good for intermediate logic you don't need to query directly)

**The `+` prefix** means "apply this config to all models in this folder". Child folders override parent settings.

**Schemas** cascade the same way — `+schema: staging` puts every model in that folder into the `staging` schema in DuckDB. The `generate_schema_name` macro in `macros/` ensures these are used as-is rather than being prefixed with `main_`.

### Understanding profiles.yml

Your database connection is configured in `~/.dbt/profiles.yml`:

```yaml
finance_analytics:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: 'finance_analytics.duckdb'
      threads: 4
```

This tells dbt:
- Use DuckDB as the database
- Create a file called `finance_analytics.duckdb`
- Use 4 parallel threads for execution

---

## Part 2: Loading Sample Data (15 mins)

### Understanding Seeds

Seeds are CSV files that dbt loads into your database. They're perfect for:
- Reference data (e.g., country codes, category mappings)
- Small datasets for development
- Our bronze layer sample data

### Inspect the Sample Data

Open each CSV file in VS Code:

**seeds/transactions.csv** (100 rows)
- Transaction details from a banking system
- **Important:** Transactions belong to accounts (via account_id), not directly to customers
- Includes: amounts, types, statuses, categories
- Date range: January-February 2024

**seeds/accounts.csv** (20 rows)
- Bank account master data
- Each account belongs to a customer (via customer_id)
- Types: checking, savings, credit_card
- Includes credit limits and balances

**seeds/customers.csv** (10 rows)
- Customer demographic and credit data
- Customers can have multiple accounts
- Risk categories and credit scores
- Geographic information

**Data Relationships:**
```
Customers (1) → (N) Accounts (1) → (N) Transactions

To get from Transaction to Customer:
Transaction → Account → Customer
```

### Load Seeds into DuckDB

Run the following command in your terminal:

```bash
dbt seed
```

**Expected Output:**
```
Running with dbt=1.7.0
Found 0 models, 0 tests, 0 snapshots, 0 analyses, 0 macros, 0 operations, 3 seed files, 0 sources, 0 exposures

Concurrency: 4 threads (target='dev')

1 of 3 START seed file bronze.transactions ............................ [RUN]
2 of 3 START seed file bronze.accounts ................................ [RUN]
3 of 3 START seed file bronze.customers ............................... [RUN]
1 of 3 OK loaded seed file bronze.transactions ........................ [INSERT 100 in 0.15s]
2 of 3 OK loaded seed file bronze.accounts ............................ [INSERT 20 in 0.12s]
3 of 3 OK loaded seed file bronze.customers ........................... [INSERT 10 in 0.10s]

Completed successfully
Done. PASS=3 WARN=0 ERROR=0 SKIP=0 TOTAL=3
```

### Verify Data in DuckDB (VS Code)

1. **Open DuckDB Extension in VS Code:**
   - Click the DuckDB icon in the left sidebar
   - If not connected, click "Add Connection"
   - Select `finance_analytics.duckdb` from the project root

2. **Create a new .sql file for testing:**
   - Create: `analyses/explore_data.sql`

3. **Run queries to explore the data:**

```sql
-- Show all tables
SHOW TABLES;

-- Count rows in each seed table
SELECT 'transactions' as table_name, count(*) as row_count 
FROM bronze.transactions
UNION ALL
SELECT 'accounts', count(*) FROM bronze.accounts
UNION ALL
SELECT 'customers', count(*) FROM bronze.customers;

-- Preview transactions
SELECT * FROM bronze.transactions LIMIT 10;

-- Check transaction types
SELECT transaction_type, count(*) as count
FROM bronze.transactions
GROUP BY transaction_type;

-- Check transaction statuses
SELECT status, count(*) as count
FROM bronze.transactions
GROUP BY status;
```

**Execute queries:**
- Mac: Cmd + Enter
- Windows: Ctrl + Enter

**What to look for:**
- 100 transactions
- 20 accounts
- 10 customers
- Transaction types: debit, credit, transfer
- Statuses: completed, pending, failed

---

## Part 3: Creating Your First Model (30 mins)

### Understanding Staging Models

Staging models are the first transformation layer:
- **Purpose:** Clean, standardize, and prepare raw data
- **Location:** `models/staging/`
- **Naming:** `stg_<source_name>.sql`
- **Materialization:** Views (lightweight, always fresh)

### The stg_transactions Model

Open `models/staging/stg_transactions.sql`. You'll see a partially completed model with TODO comments.

**Current state:**
```sql
with source_data as (
    select * from {{ ref('transactions') }}
),

renamed as (
    select
        transaction_id,
        account_id,
        customer_id,
        transaction_date,
        amount,
        transaction_type,
        status,
        merchant_name,
        category,
        current_timestamp as loaded_at
    from source_data
)

select * from renamed
```

### Step 1: Complete the Model

Let's fix all the TODOs:

```sql
-- Staging model for transactions
-- This is the first transformation layer (Bronze -> Silver)
-- Purpose: Clean and standardize transaction data

with source_data as (
    
    -- For now, we'll use ref() to reference the seed
    -- In Module 2, we'll replace this with source()
    select * from {{ ref('transactions') }}

),

renamed as (

    select
        -- Primary key
        transaction_id,
        
        -- Foreign key (to accounts - customer is accessed through account)
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

**Changes made:**
1. ✅ Cast amount to decimal(10,2) for precision
2. ✅ Added transaction_age_days calculation
3. ✅ Added filter to exclude failed transactions
4. ✅ Added comments for clarity
5. ✅ Note: customer_id is NOT in transactions - it's accessed through accounts

### Step 2: Understanding the ref() Function

The `{{ ref('transactions') }}` function is crucial in dbt:

**What it does:**
- Creates a dependency between models — dbt knows to run the `transactions` seed before `stg_transactions`
- In compiled SQL, it resolves to the schema where dbt materialized that object
- Enables automatic lineage tracking

**Why does `ref('transactions')` compile to `bronze.transactions`?**

Because the seed is configured with `+schema: bronze` in `dbt_project.yml`:

```yaml
seeds:
  finance_analytics:
    +schema: bronze   # ← this puts seeds in the bronze schema
```

`ref()` resolves to wherever dbt actually created the object. The schema comes from your project config, not from source definitions. Source definitions are a separate concept covered in Module 2.

**What about `source()`? Is it the same thing?**

Not quite. Both `ref('transactions')` and `source('bronze', 'transactions')` compile to `bronze.transactions` in this project — the same SQL output — but they mean different things:

| | `ref()` | `source()` |
|---|---|---|
| **Use for** | dbt-managed objects (seeds, models) | External tables dbt didn't create |
| **Schema from** | `dbt_project.yml` config | `_sources.yml` definition |
| **Source freshness checks** | No | Yes |

In Module 2 you will swap `ref('transactions')` for `source('bronze', 'transactions')`. The compiled SQL will be identical, but using `source()` is the correct pattern for raw data because it documents the true origin of data and enables freshness monitoring.

**Why not write `FROM bronze.transactions` directly?**
- Hardcoding the schema breaks dbt's dependency graph
- dbt won't know to run seeds before models
- No automatic lineage tracking or documentation

### Step 3: Run the Model

> ⚠️ **Before running any dbt command:** Disconnect from DuckDB in VS Code first.
> DuckDB only allows one writer at a time. If the VS Code extension holds a connection,
> dbt will fail with a lock error. Right-click the connection in the DuckDB panel → **Disconnect**,
> run your dbt command, then reconnect to query results.

```bash
dbt run --select stg_transactions
```

**Expected Output:**
```
Running with dbt=1.7.0
Found 1 model, 0 tests, 0 snapshots, 0 analyses, 0 macros, 0 operations, 3 seed files, 0 sources

Concurrency: 4 threads (target='dev')

1 of 1 START sql view model staging.stg_transactions .................. [RUN]
1 of 1 OK created sql view model staging.stg_transactions ............. [CREATE VIEW in 0.10s]

Completed successfully
Done. PASS=1 WARN=0 ERROR=0 SKIP=0 TOTAL=1
```

**Key points:**
- ✅ Model ran successfully
- ✅ Created as a **view** (as configured in dbt_project.yml)
- ✅ Created in **staging** schema
- ✅ Took ~0.10 seconds

### Step 4: Query the Model Results

In your `analyses/explore_data.sql` file:

```sql
-- Query the staging model
SELECT * FROM staging.stg_transactions LIMIT 10;

-- Check the filter worked (no failed transactions)
SELECT status, count(*) as count
FROM staging.stg_transactions
GROUP BY status;

-- Verify calculated field
SELECT 
    transaction_id,
    transaction_date,
    transaction_age_days,
    current_date
FROM staging.stg_transactions
LIMIT 5;

-- Check data types
DESCRIBE staging.stg_transactions;
```

**Verify:**
- ✅ No failed transactions (filter worked)
- ✅ Amount is decimal(10,2)
- ✅ transaction_age_days is calculated correctly
- ✅ loaded_at timestamp is present

### Step 5: Understanding Compiled SQL

dbt compiles your Jinja/SQL into pure SQL. Let's see it:

```bash
# View compiled SQL
cat target/compiled/finance_analytics/models/staging/stg_transactions.sql
```

You'll see `{{ ref('transactions') }}` has been replaced with `bronze.transactions` — the schema coming from the `+schema: bronze` seed config in `dbt_project.yml`, not from a source definition.

---

## Part 4: DIY Exercise - Complete Remaining Staging Models (30 mins)

### Exercise 1: Complete stg_accounts.sql

**Requirements:**
1. Reference the accounts seed table
2. Select and appropriately cast all columns:
   - account_id (varchar)
   - customer_id (varchar)
   - account_type (varchar)
   - account_status (varchar)
   - open_date (date)
   - credit_limit (decimal(10,2))
   - current_balance (decimal(10,2))
3. Add calculated field: `account_age_days` (current_date - open_date)
4. Add `loaded_at` timestamp
5. No filters needed

**Starter template in:** `models/staging/stg_accounts.sql`

**Solution approach:**
```sql
with source_data as (
    select * from {{ ref('accounts') }}
),

renamed as (
    select
        account_id,
        customer_id,
        account_type,
        account_status,
        cast(open_date as date) as open_date,
        cast(credit_limit as decimal(10,2)) as credit_limit,
        cast(current_balance as decimal(10,2)) as current_balance,
        
        -- Calculated field
        current_date - cast(open_date as date) as account_age_days,
        
        -- Audit
        current_timestamp as loaded_at
        
    from source_data
)

select * from renamed
```

**Run and verify:**
```bash
dbt run --select stg_accounts
```

**Test query:**
```sql
SELECT 
    account_type,
    count(*) as count,
    avg(current_balance) as avg_balance
FROM staging.stg_accounts
GROUP BY account_type;
```

### Exercise 2: Complete stg_customers.sql

**Requirements:**
1. Reference the customers seed table
2. Select all columns with appropriate types
3. Rename `customer_name` to `full_name`
4. Add calculated field: `customer_age_days` (current_date - created_at)
5. Add `loaded_at` timestamp

**Starter template in:** `models/staging/stg_customers.sql`

**Solution approach:**
```sql
with source_data as (
    select * from {{ ref('customers') }}
),

renamed as (
    select
        customer_id,
        customer_name as full_name,
        email,
        customer_type,
        risk_category,
        cast(created_at as date) as created_at,
        city,
        state,
        age_group,
        cast(credit_score as integer) as credit_score,
        
        -- Calculated field
        current_date - cast(created_at as date) as customer_age_days,
        
        -- Audit
        current_timestamp as loaded_at
        
    from source_data
)

select * from renamed
```

**Run and verify:**
```bash
dbt run --select stg_customers
```

**Test query:**
```sql
SELECT 
    customer_type,
    risk_category,
    count(*) as count,
    avg(credit_score) as avg_credit_score
FROM staging.stg_customers
GROUP BY customer_type, risk_category;
```

### Exercise 3: Run All Staging Models Together

```bash
# Run all models in staging folder
dbt run --select staging

# Or run all models
dbt run
```

**Expected Output:**
```
1 of 3 START sql view model staging.stg_transactions .................. [RUN]
2 of 3 START sql view model staging.stg_accounts ...................... [RUN]
3 of 3 START sql view model staging.stg_customers ..................... [RUN]
1 of 3 OK created sql view model staging.stg_transactions ............. [CREATE VIEW in 0.10s]
2 of 3 OK created sql view model staging.stg_accounts ................. [CREATE VIEW in 0.09s]
3 of 3 OK created sql view model staging.stg_customers ................ [CREATE VIEW in 0.08s]

Done. PASS=3 WARN=0 ERROR=0 SKIP=0 TOTAL=3
```

---

## 🎯 Module 1 Deliverables

Take screenshots of the following for your portfolio:

### 1. Successful dbt run
```bash
dbt run
```
Screenshot should show all 3 models passing.

### 2. Query Results from Each Staging Model
```sql
-- Sample data from each staging model
SELECT * FROM staging.stg_transactions LIMIT 5;
SELECT * FROM staging.stg_accounts LIMIT 5;
SELECT * FROM staging.stg_customers LIMIT 5;
```

### 3. Data Quality Checks
```sql
-- Verify no failed transactions
SELECT status, count(*) FROM staging.stg_transactions GROUP BY status;

-- Verify all account types
SELECT account_type, count(*) FROM staging.stg_accounts GROUP BY account_type;

-- Verify risk categories
SELECT risk_category, count(*) FROM staging.stg_customers GROUP BY risk_category;
```

### 4. Lineage Verification

Run this to see the dependency graph:
```bash
dbt docs generate
dbt docs serve
```

Navigate to the DAG (Directed Acyclic Graph) and verify:
- Seeds feed into staging models
- No broken dependencies

---

## ✅ Self-Assessment Checklist

Before moving to Module 2, ensure you can:

- [ ] Explain the difference between seeds and models
- [ ] Understand what the `{{ ref() }}` function does and why it's important
- [ ] Run specific models using `--select`
- [ ] Query results in DuckDB via VS Code
- [ ] Explain the difference between view and table materialization
- [ ] Navigate the compiled SQL in the target/ folder
- [ ] Understand the dbt project structure
- [ ] All three staging models run successfully

---

## 🐛 Common Issues & Solutions

### Issue 1: "Could not find a profile"
**Error:** `Could not find profile named 'finance_analytics'`

**Solution:**
```bash
# Check profile location
ls ~/.dbt/  # Mac/Linux
dir %USERPROFILE%\.dbt\  # Windows

# If missing, copy from project
cp profiles.yml ~/.dbt/profiles.yml
```

### Issue 2: "Relation does not exist"
**Error:** `Runtime Error: relation "bronze.transactions" does not exist`

**Solution:**
```bash
# Load seeds first
dbt seed

# Then run models
dbt run
```

### Issue 3: DuckDB file locked
**Error:** `IO Error: Could not set lock on file`

**Solution:**
- Close all DuckDB connections in VS Code
- Close any SQL files connected to the database
- Try again

### Issue 4: Model not found
**Error:** `Could not find model 'stg_transactions'`

**Solution:**
- Check that .sql file is in `models/staging/`
- Verify filename matches reference
- Run `dbt debug` to check project structure

---

## 🚀 Quick Reference

**Key Commands:**
```bash
dbt seed                          # Load CSV files
dbt run                           # Run all models
dbt run --select stg_transactions # Run one model
dbt run --select staging          # Run all in folder
dbt clean                         # Remove compiled files
```

**Query Patterns:**
```sql
-- Always query by schema.table
SELECT * FROM staging.stg_transactions;
SELECT * FROM bronze.transactions;

-- Useful aggregations
SELECT column, count(*) FROM table GROUP BY column;
SELECT avg(numeric_column) FROM table;
```

**Project Structure:**
```
models/staging/    → Views in 'staging' schema
models/marts/      → Tables in 'marts' schema
seeds/             → Tables in 'bronze' schema (default)
```

---

## 📚 Additional Learning

**Recommended Reading:**
- [dbt Model Syntax](https://docs.getdbt.com/docs/build/sql-models)
- [dbt ref() Function](https://docs.getdbt.com/reference/dbt-jinja-functions/ref)
- [dbt Materializations](https://docs.getdbt.com/docs/build/materializations)

**Practice Challenges:**
1. Add a new calculated field to any staging model
2. Create a new seed file and staging model
3. Experiment with different materializations (table vs view)

---

## ➡️ Next Steps

**Ready for Module 2?**

You should now have:
- ✅ Three working staging models
- ✅ Data loaded in DuckDB
- ✅ Ability to query results
- ✅ Understanding of basic dbt concepts

**In Module 2, you'll learn:**
- How to configure sources (replace `ref()` with `source()`)
- Schema tests (unique, not_null, relationships)
- Custom singular tests
- Data quality validation

**Continue to:** [Module 2: Source Configuration & Testing](docs/MODULE_02.md)

---

## 💬 Questions?

- Review the [Troubleshooting section](#-common-issues--solutions)
- Check the [main README](../README.md)
- Ask in DataGrokr Slack: #dbt-training

Great work completing Module 1! 🎉

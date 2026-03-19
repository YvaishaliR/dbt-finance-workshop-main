# dbt Finance Analytics Workshop

Welcome to the  self-paced dbt training workshop! This hands-on workshop will take you from dbt basics to advanced production patterns using real-world finance data.

## 🎯 Workshop Overview

**Total Time:** 8-9 hours (self-paced)  
**Format:** Progressive modules with DIY exercises  
**Domain:** Finance & Accounting  
**Database:** DuckDB (local, no external dependencies)

## 📚 What You'll Build

By the end of this workshop, you'll have:
- ✅ Complete medallion architecture (Bronze → Silver → Gold)
- ✅ 15+ dbt models across staging, intermediate, and marts layers
- ✅ 20+ data quality tests
- ✅ Custom macros for reusable business logic
- ✅ Incremental model implementation
- ✅ Production-ready project structure
- ✅ Full dbt documentation site

## 🏗️ Architecture

```
Bronze (Seeds)          Silver (Staging)         Gold (Marts)
├── transactions.csv → ├── stg_transactions → ├── fct_daily_transactions
├── accounts.csv     → ├── stg_accounts     → ├── dim_customers
└── customers.csv    → └── stg_customers    → └── dim_accounts
                            ↓
                       Intermediate Layer
                       ├── int_customer_transactions
                       └── int_account_balances

Relationships:
- Customers (1) → (N) Accounts
- Accounts (1) → (N) Transactions
```


> 💡 **YAML Naming Convention:** dbt reads any `.yml` filename, but the community standard is to prefix with `_` (e.g. `_sources.yml`, `_stg_models.yml`). The underscore sorts the file to the top of the folder in VS Code and visually separates config files from `.sql` models. See Module 1 for a full explanation.

## 🚀 Prerequisites

### Required Software
- Python 3.8+ ([download](https://www.python.org/downloads/))
- VS Code ([download](https://code.visualstudio.com/))
- Git ([download](https://git-scm.com/downloads))

### Recommended VS Code Extensions
- DuckDB SQL Tools (RandomFractalsInc.duckdb-sql-tools)
- Better Jinja (samuelcolvin.jinjahtml)
- SQLFluff (dorzey.vscode-sqlfluff)

## 📦 Setup Instructions

### Step 1: Clone the Repository
```bash
git clone <repository-url>
cd dbt-finance-workshop
```

### Step 2: Create Virtual Environment
```bash
# Create virtual environment
python -m venv venv

# Activate (Mac/Linux)
source venv/bin/activate

# Activate (Windows)
venv\Scripts\activate
```

### Step 3: Install dbt
```bash
pip install dbt-core dbt-duckdb
```

### Step 4: Configure dbt Profile
```bash
# Create .dbt directory
mkdir ~/.dbt  # Mac/Linux
mkdir %USERPROFILE%\.dbt  # Windows

# Copy profiles.yml template
cp profiles.yml ~/.dbt/profiles.yml  # Mac/Linux
copy profiles.yml %USERPROFILE%\.dbt\profiles.yml  # Windows
```

### Step 5: Verify Installation
```bash
dbt --version
# Should show dbt version and dbt-duckdb adapter
```

### Step 6: Test Connection
```bash
dbt debug
# All checks should pass ✓
```

## 🔧 Working with DuckDB in VS Code

### Install DuckDB Extension
1. Open VS Code
2. Go to Extensions (Cmd+Shift+X / Ctrl+Shift+X)
3. Search for "DuckDB SQL Tools"
4. Install by RandomFractalsInc

### Connect to Database
1. Click on DuckDB icon in left sidebar
2. Add new connection
3. Point to `finance_analytics.duckdb` (created after first `dbt run`)
4. Open .sql files and run queries with Cmd+Enter (Mac) or Ctrl+Enter (Windows)

### Quick Query Examples
```sql
-- View all tables
SHOW TABLES;

-- Query staging data
SELECT * FROM staging.stg_transactions LIMIT 10;

-- Check row counts
SELECT 'transactions' as table_name, count(*) as row_count FROM bronze.transactions
UNION ALL
SELECT 'accounts', count(*) FROM bronze.accounts
UNION ALL
SELECT 'customers', count(*) FROM bronze.customers;
```

## 📖 Module Structure

### Module 1: Environment Setup & dbt Fundamentals (90 mins)
- ✅ Setup complete (you just did this!)
- 📝 Next: Run your first dbt models
- 🎯 Deliverable: Working dbt project with staging models

### Module 2: Source Configuration & Testing (75 mins)
- 🔍 Configure sources
- ✅ Add schema tests
- 🧪 Write custom tests
- 🎯 Deliverable: Comprehensive test suite

### Module 3: Medallion Architecture - Silver Layer (90 mins)
- 🏗️ Build intermediate models
- 🔄 Apply business transformations
- 📊 Create aggregations
- 🎯 Deliverable: Silver layer with business logic

### Module 4: Gold Layer & Advanced Features (90 mins)
- 🌟 Build fact and dimension tables
- 🔧 Create reusable macros
- ⚡ Implement incremental models
- 🎯 Deliverable: Production-ready marts

### Module 5: Advanced Testing & Data Quality (60 mins)
- 📏 Use dbt_expectations
- 🔬 Create custom generic tests
- 📚 Generate documentation
- 🎯 Deliverable: Full test coverage + docs

### Module 6: Production Workflows & Best Practices (75 mins)
- 🏷️ Use selectors and tags
- ✨ Set up linting with SQLFluff
- 🚀 Understand deployment patterns
- 🎯 Deliverable: Production-ready project

## 🎓 Learning Path

**Recommended Pace:**
- **Day 1:** Modules 1-2 (Complete setup and basic models)
- **Day 2:** Modules 3-4 (Build out transformations)
- **Day 3:** Modules 5-6 (Advanced features and production)

**Self-Assessment:**
Each module has clear deliverables. Take screenshots of:
1. Successful `dbt run` outputs
2. Passing test results
3. Query results from DuckDB
4. Generated documentation

## 🆘 Troubleshooting

### Common Issues

**Issue:** `dbt command not found`
- **Fix:** Make sure virtual environment is activated
```bash
source venv/bin/activate  # Mac/Linux
venv\Scripts\activate  # Windows
```

**Issue:** `Could not find profile named 'finance_analytics'`
- **Fix:** Check that profiles.yml is in the correct location (~/.dbt/)

**Issue:** DuckDB file locked
- **Fix:** Close any open DuckDB connections in VS Code

**Issue:** Module not found errors
- **Fix:** Reinstall dependencies
```bash
pip install --upgrade dbt-core dbt-duckdb
```

## 📊 Sample Data Overview

### Bronze Layer (Seeds)
- **transactions.csv:** 100 sample transactions (Jan-Feb 2024)
- **accounts.csv:** 20 accounts across checking, savings, credit cards
- **customers.csv:** 10 customers with demographic and credit data

### Key Metrics to Build
- Daily transaction volumes
- Customer lifetime value
- Account balances
- Risk profiles
- Category spending analysis

## 🔗 Useful Resources

- [dbt Documentation](https://docs.getdbt.com/)
- [DuckDB Documentation](https://duckdb.org/docs/)
- [dbt Best Practices](https://docs.getdbt.com/guides/best-practices)
- [dbt Discourse Community](https://discourse.getdbt.com/)

## 📝 Quick Reference Commands

```bash
# Load seed data
dbt seed

# Run all models
dbt run

# Run specific model
dbt run --select stg_transactions

# Run tests
dbt test

# Run tests for specific model
dbt test --select stg_transactions

# Run everything (seeds, run, test)
dbt build

# Generate documentation
dbt docs generate
dbt docs serve

# Install packages
dbt deps

# Clean compiled files
dbt clean

# Run models downstream of a specific model
dbt run --select stg_transactions+

# Run models upstream of a specific model
dbt run --select +fct_daily_transactions
```

## 🎯 Success Criteria

You've successfully completed the workshop when:
- [ ] All `dbt build` commands pass without errors
- [ ] All tests pass (20+ tests)
- [ ] You can query data at each layer (bronze, staging, intermediate, marts)
- [ ] Documentation site renders correctly
- [ ] You understand when to use views vs tables vs ephemeral
- [ ] You can explain the ref() and source() functions
- [ ] You've created at least one custom macro
- [ ] You understand incremental models

## 🏆 Next Steps

After completing this workshop:
1. Apply these patterns to real  projects
2. Explore advanced dbt packages (dbt_utils, dbt_expectations)
3. Set up dbt Cloud for production deployment
4. Implement CI/CD pipelines
5. Build data quality dashboards

## 📫 Support

Questions or issues? Reach out on the  Slack channel #dbt-training

Happy learning! 🚀

---

## ⚠️ Workshop Tips & Gotchas

These are lessons learned from running this workshop. Read them before you start — they'll save you time.

### 1. Use `dbt clean` to Start Afresh

If something is behaving unexpectedly — stale models, weird errors, old compiled SQL — run `dbt clean` first. It wipes the `target/` and `dbt_packages/` directories so dbt re-compiles everything from scratch.

```bash
dbt clean
dbt seed       # reload seeds
dbt run        # recompile and run all models
```

Get into the habit of running `dbt clean` whenever you:
- Pull changes from git
- Change `dbt_project.yml` or `profiles.yml`
- Hit a confusing error that doesn't match your code
- Switch between branches

### 2. Run `dbt deps` When packages.yml Changes

If `packages.yml` has any packages uncommented (modules 4 and 5 use `dbt_utils` and `dbt_expectations`), you must run `dbt deps` to download them before `dbt run` will work.

```bash
dbt deps    # installs packages into dbt_packages/
dbt build   # now safe to run
```

You only need to re-run `dbt deps` when you add or change a package version. The `dbt_packages/` folder is gitignored — so anyone cloning the repo fresh also needs to run it.

### 3. Detach DuckDB in VS Code Before Running dbt

DuckDB is a **single-user process** — only one connection can write to the `.duckdb` file at a time. If you have the database open in the VS Code DuckDB extension and then run `dbt seed` or `dbt run`, you'll get a lock error like:

```
IO Error: Could not set lock on file "finance_analytics.duckdb"
```

**Before every `dbt` command, disconnect from DuckDB in VS Code:**
1. Open the DuckDB panel in the VS Code sidebar
2. Right-click the connection → **Disconnect** (or close the connection)
3. Run your `dbt` command
4. Reconnect to query results

Alternatively, keep two terminal windows open — one for dbt commands, one for your VS Code queries — and make it a habit to disconnect before switching to dbt.

### 4. Jinja Inside SQL Comments Is Still Executed

dbt processes Jinja `{{ }}` before running SQL — this includes text inside SQL comments. So this will cause a compile error even though it looks harmless:

```sql
-- TODO: Replace with {{ source('bronze', 'transactions') }}   ❌
```

Always strip the curly braces from hints in comments:

```sql
-- TODO: Replace with source('bronze', 'transactions') in double curly braces   ✅
```

### 5. Schema Names: Use `generate_schema_name` Macro

By default dbt prefixes schema names with `target.schema`, turning `bronze` into `main_bronze`. The project already includes `macros/generate_schema_name.sql` to fix this — make sure it's present if your schemas look wrong.

### 6. Seed NULL Values Must Be Empty, Not the String "NULL"

DuckDB's CSV parser treats the literal string `"NULL"` as a string, not a null value. Use empty fields in CSVs instead:

```csv
# Wrong ❌
ACC001,CUST001,checking,active,2020-03-15,NULL,2500.75

# Correct ✅
ACC001,CUST001,checking,active,2020-03-15,,2500.75
```

Column types for seeds should always be explicitly declared in `seeds/schema.yml` to avoid DuckDB's type sniffer guessing wrong.

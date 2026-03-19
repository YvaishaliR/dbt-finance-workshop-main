# Quick Start Guide - 5 Minute Setup

Get up and running with the dbt Finance Workshop in 5 minutes!

## ⚠️ Before You Begin — Key Tips

These will save you time. Keep them in mind throughout all modules.

| Tip | When |
|-----|------|
| Run `dbt clean` | Whenever things behave unexpectedly — clears stale compiled files |
| Run `dbt deps` | After uncommenting packages in `packages.yml` (Modules 4 & 5) |
| Disconnect DuckDB in VS Code | **Before every `dbt` command** — DuckDB only allows one writer at a time |

**DuckDB lock error?** Right-click the connection in the VS Code DuckDB panel → Disconnect, then retry your dbt command.


## Prerequisites ✓

- [ ] Python 3.8+ installed
- [ ] VS Code installed
- [ ] Terminal/Command Prompt access

## Setup (Mac/Linux)

```bash
# 1. Run the setup script
./setup.sh

# 2. Load sample data
dbt seed

# 3. Run your first model
dbt run --select stg_transactions

# 4. Query the results (in VS Code with DuckDB extension)
# Open a .sql file and run:
SELECT * FROM staging.stg_transactions LIMIT 10;
```

## Setup (Windows)

```cmd
# 1. Run the setup script
setup.bat

# 2. Load sample data
dbt seed

# 3. Run your first model
dbt run --select stg_transactions

# 4. Query the results (in VS Code with DuckDB extension)
# Open a .sql file and run:
SELECT * FROM staging.stg_transactions LIMIT 10;
```

## What You Just Did

✅ Installed dbt-core and dbt-duckdb  
✅ Configured your database connection  
✅ Loaded 100 sample transactions + accounts & customers  
✅ Created your first staging model (a SQL view)  
✅ Queried the transformed data

## Next Steps

### Complete Module 1
Open and follow: `docs/MODULE_01.md`

This will guide you through:
- Understanding dbt project structure
- Creating staging models for accounts and customers
- Using the `ref()` function
- Understanding materializations

**Time:** ~90 minutes

### Helpful Commands

```bash
# See all available commands
dbt --help

# Run all models
dbt run

# Run just staging models
dbt run --select staging

# Run tests
dbt test

# Generate documentation
dbt docs generate
dbt docs serve
```

## Troubleshooting

### "dbt command not found"
Make sure your virtual environment is activated:
```bash
source venv/bin/activate  # Mac/Linux
venv\Scripts\activate      # Windows
```

### "Could not find profile"
Copy profiles.yml to the right location:
```bash
cp profiles.yml ~/.dbt/profiles.yml  # Mac/Linux
copy profiles.yml %USERPROFILE%\.dbt\profiles.yml  # Windows
```

### DuckDB file locked
Close any open DuckDB connections in VS Code and try again.

## Project Structure

```
dbt-finance-workshop/
├── models/
│   ├── staging/          ← Start here!
│   ├── intermediate/
│   └── marts/
├── seeds/
│   ├── transactions.csv  ← Sample data (100 rows)
│   ├── accounts.csv      ← Sample data (20 rows)
│   └── customers.csv     ← Sample data (10 rows)
├── docs/
│   └── MODULE_01.md     ← Detailed tutorial
└── README.md            ← Full workshop overview
```

## VS Code Extensions (Recommended)

1. **DuckDB SQL Tools** - Query your database
2. **Better Jinja** - Syntax highlighting for dbt models
3. **SQLFluff** - SQL linting (for Module 6)

Install from VS Code Extensions marketplace (Cmd+Shift+X / Ctrl+Shift+X)

## Sample Queries to Try

```sql
-- How many transactions per customer?
SELECT 
    customer_id,
    count(*) as transaction_count,
    sum(amount) as total_amount
FROM staging.stg_transactions
GROUP BY customer_id
ORDER BY total_amount DESC;

-- What are the most common transaction categories?
SELECT 
    category,
    count(*) as count,
    avg(amount) as avg_amount
FROM staging.stg_transactions
GROUP BY category
ORDER BY count DESC;

-- Check account types distribution
SELECT 
    account_type,
    count(*) as count,
    avg(current_balance) as avg_balance
FROM staging.stg_accounts
GROUP BY account_type;
```

## Learning Path

**Day 1 (3 hours):**
- Module 1: Setup & Fundamentals ✓ (You're here!)
- Module 2: Source Configuration & Testing

**Day 2 (3 hours):**
- Module 3: Silver Layer Transformations
- Module 4: Gold Layer & Advanced Features

**Day 3 (2.5 hours):**
- Module 5: Advanced Testing & Data Quality
- Module 6: Production Workflows

## Resources

- **Full README:** `README.md` - Complete workshop overview
- **Module 1:** `docs/MODULE_01.md` - Detailed walkthrough
- **Solutions:** `SOLUTIONS.md` - Reference solutions (use after trying!)
- **dbt Docs:** https://docs.getdbt.com/

## Support

Questions? Check:
1. The troubleshooting section above
2. Module documentation in `docs/`
3. DataGrokr Slack: #dbt-training

---

🎉 **You're ready to start learning dbt!**

Open `docs/MODULE_01.md` and let's build something great!

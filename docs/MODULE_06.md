# Module 6: Production Workflows & Best Practices

---

**Duration:** 75 minutes  
**Prerequisites:** Completed Module 5 — 30+ tests passing, documentation generated  
**Deliverable:** Tagged models, selectors, linted SQL, and documented deployment strategy

---

## 🎯 Learning Objectives

By the end of this module, you will:
- ✅ Tag models and use graph operators to run subsets
- ✅ Create selectors for common run patterns
- ✅ Lint SQL with SQLFluff
- ✅ Understand production deployment patterns
- ✅ Know the key differences between dbt Core and dbt Cloud

---

## 📋 Module Overview

1. **Tags & Graph Operators** (20 mins)
2. **Selectors** (15 mins)
3. **SQL Linting with SQLFluff** (20 mins)
4. **Production Deployment Patterns** (20 mins)

---

## Part 1: Tags & Graph Operators (20 mins)

### Why tags?

Tags let you group models logically and run subsets with a single command. In production you might need to:
- Run only fast, lightweight models every hour
- Run heavy mart models once daily
- Run a specific domain's models independently
- Skip certain models during CI

### Tagging models in `dbt_project.yml`

Tags can be applied at the folder level in `dbt_project.yml` or per-model in YAML config files.

Update `dbt_project.yml` to add tags:

```yaml
models:
  finance_analytics:

    staging:
      +materialized: view
      +schema: staging
      +tags: ['staging', 'hourly']    # Staging is lightweight, refresh frequently

    intermediate:
      +materialized: ephemeral
      +tags: ['intermediate']

    marts:
      +materialized: table
      +schema: marts
      +tags: ['marts', 'daily']       # Marts are heavier, refresh daily
      finance:
        +tags: ['finance', 'daily']
```

You can also tag individual models in their YAML config:

```yaml
# In _mart_models.yml
models:
  - name: fct_daily_transactions
    config:
      tags: ['finance', 'daily', 'critical']  # critical = alert if this fails
```

### Running by tag

```bash
# Run all daily models
dbt run --select tag:daily

# Run all staging models
dbt run --select tag:staging

# Build all finance domain models
dbt build --select tag:finance

# Test only critical models
dbt test --select tag:critical
```

### Graph operators

Graph operators let you select models relative to others in the DAG:

| Operator | Meaning | Example |
|----------|---------|---------|
| `+` prefix | All upstream models | `+fct_daily_transactions` |
| `+` suffix | All downstream models | `stg_transactions+` |
| `@` prefix | Upstream + all their tests | `@fct_daily_transactions` |
| `1+` | Only immediate parents | `1+fct_daily_transactions` |
| `state:modified` | Only changed models | `state:modified+` |

Examples:
```bash
# Run a model and everything it depends on
dbt run --select +fct_daily_transactions

# Run a model and everything downstream of it
dbt run --select stg_transactions+

# Run only the staging layer and its tests
dbt build --select staging+1

# Run changed models and their downstream dependencies (Slim CI)
dbt build --select state:modified+
```

### Excluding models

```bash
# Run everything except intermediate models
dbt run --exclude intermediate

# Run marts but skip the dim_customers model
dbt run --select marts --exclude dim_customers
```

---

## Part 2: Selectors (15 mins)

### What are selectors?

Selectors are named, reusable selection patterns defined in `selectors.yml`. Instead of typing long `--select` strings in every command, you define them once and reference by name.

Create `selectors.yml` in the project root:

```yaml
selectors:

  - name: staging_layer
    description: All staging models and their tests
    definition:
      method: path
      value: models/staging

  - name: daily_refresh
    description: Models that run on the daily schedule
    definition:
      union:
        - method: tag
          value: daily
        - method: tag
          value: critical

  - name: hourly_refresh
    description: Lightweight models that refresh every hour
    definition:
      method: tag
      value: hourly

  - name: finance_domain
    description: All finance domain models end-to-end
    definition:
      union:
        - method: path
          value: models/staging
        - method: path
          value: models/intermediate
        - method: path
          value: models/marts/finance

  - name: mart_with_upstreams
    description: Run a full pipeline for the mart layer
    definition:
      method: selector
      value: daily_refresh
      parents: true
```

Use selectors with `--selector`:
```bash
# Use a named selector
dbt build --selector daily_refresh
dbt run --selector staging_layer
dbt test --selector finance_domain
```

---

## Part 3: SQL Linting with SQLFluff (20 mins)

### Why lint SQL?

Consistent, readable SQL is important when multiple engineers work on the same project. SQLFluff:
- Enforces consistent style (capitalisation, indentation, spacing)
- Catches common SQL mistakes
- Can automatically fix many violations
- Works natively with dbt's Jinja templating

### Install SQLFluff

```bash
pip install sqlfluff sqlfluff-templater-dbt
```

### Configure SQLFluff

Create `.sqlfluff` in the project root:

```ini
[sqlfluff]
dialect = duckdb
templater = dbt
max_line_length = 100
exclude_rules = RF05   # RF05 = reserved words as identifiers (too strict for dbt)

[sqlfluff:templater:dbt]
project_dir = .
profiles_dir = ~/.dbt

[sqlfluff:indentation]
indent_unit = space
tab_space_size = 4

[sqlfluff:rules:capitalisation.keywords]
capitalisation_policy = lower

[sqlfluff:rules:capitalisation.functions]
capitalisation_policy = lower

[sqlfluff:rules:capitalisation.literals]
capitalisation_policy = lower

[sqlfluff:rules:capitalisation.identifiers]
capitalisation_policy = lower

[sqlfluff:rules:aliasing.table]
aliasing = explicit     # Always require explicit aliases (t, a, c not just table names)

[sqlfluff:rules:aliasing.column]
aliasing = explicit
```

### Run SQLFluff

```bash
# Lint a single file
sqlfluff lint models/staging/stg_transactions.sql

# Lint the entire project
sqlfluff lint models/

# Automatically fix violations
sqlfluff fix models/staging/stg_transactions.sql

# Fix the entire project
sqlfluff fix models/
```

### Common violations to know

| Rule | Violation | Fix |
|------|-----------|-----|
| `L010` | Keywords not lowercase | `SELECT` → `select` |
| `L014` | Unquoted identifiers not lowercase | `TransactionID` → `transaction_id` |
| `L031` | Unnecessary aliases | Remove unused `AS x` |
| `L034` | SELECT wildcards | Replace `SELECT *` with explicit columns |
| `L036` | SELECT on new line | Put each column on its own line |

### SQLFluff with dbt Jinja

SQLFluff's dbt templater understands `{{ ref() }}`, `{{ source() }}`, and `{% if %}` blocks. It compiles the Jinja before linting, so it won't flag these as errors.

If you see `TMP` or templating errors, ensure `profiles_dir` in `.sqlfluff` points to your `~/.dbt/` directory.

---

## Part 4: Production Deployment Patterns (20 mins)

### dbt Core vs dbt Cloud

This workshop uses **dbt Core** (the open-source CLI). In production at DataGrokr clients, you'll encounter both:

| | dbt Core | dbt Cloud |
|---|----------|-----------|
| **Cost** | Free | Paid (has free tier) |
| **Scheduling** | External (Airflow, cron, etc.) | Built-in scheduler |
| **CI/CD** | Manual setup | Built-in CI jobs |
| **IDE** | VS Code + local | Cloud IDE |
| **Logs** | Local files | Web UI |
| **Slim CI** | Possible but complex | First-class feature |

For DataGrokr client engagements, the choice depends on client infrastructure. Both use the same `dbt_project.yml`, models, and tests — only the orchestration layer differs.

### Environment strategy

A typical production setup has three environments:

```
Development → CI/CD → Production

dev    profile: local DuckDB, run dbt manually
ci     profile: cloud warehouse, run on PR
prod   profile: cloud warehouse, run on schedule
```

In `profiles.yml` you'd have:

```yaml
finance_analytics:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: 'finance_analytics.duckdb'

    ci:
      type: snowflake     # or bigquery, redshift, etc.
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      schema: "ci_{{ env_var('PR_NUMBER') }}"   # Isolated schema per PR

    prod:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      schema: prod
```

### Slim CI

Slim CI only runs models that changed in a pull request, rather than the full project. This keeps CI fast.

```bash
# In CI, compare against production manifest
dbt build --select state:modified+ --defer --state prod-manifest/
```

This requires storing the production manifest (`target/manifest.json`) as an artifact after each production run, then downloading it in CI.

### Production checklist

Before deploying a dbt project to production:

```
Infrastructure
[ ] Warehouse connection credentials in environment variables (not hardcoded)
[ ] Service account with least-privilege permissions
[ ] Target schemas created with correct permissions

Models
[ ] All models have descriptions
[ ] All primary keys have unique + not_null tests
[ ] All foreign keys have relationships tests
[ ] No hardcoded schema names (use ref/source only)
[ ] dbt build passes cleanly on CI

Scheduling
[ ] Understand which models need to run at which frequency
[ ] Selectors defined for each schedule (hourly, daily, weekly)
[ ] Failure alerting configured
[ ] On-call process defined for test failures

Documentation
[ ] dbt docs deployed to accessible location
[ ] Stakeholders know where to find documentation
```

### Source freshness monitoring

In production, you want to know if source data stops arriving. Add freshness configuration to `_sources.yml`:

```yaml
sources:
  - name: bronze
    freshness:
      warn_after:  {count: 12, period: hour}
      error_after: {count: 24, period: hour}

    tables:
      - name: transactions
        loaded_at_field: loaded_at   # Column that tracks when row was loaded
```

Then run:
```bash
dbt source freshness
```

This tells you if your source tables haven't been updated recently.

---

## 🎯 Module 6 Deliverables

### 1. Tags applied across all layers
```bash
# Verify tags are applied
dbt ls --select tag:daily
dbt ls --select tag:staging
```

### 2. Selectors working
```bash
dbt build --selector daily_refresh
dbt ls --selector finance_domain
```

### 3. SQLFluff passing
```bash
sqlfluff lint models/ --format github-annotation
```
Zero violations (or documented exceptions).

### 4. Document your deployment plan

Write a short `DEPLOYMENT.md` in the project root answering:
- What schedule would each model run on? (hourly, daily, weekly)
- Which selector would the scheduler use?
- What would your CI check on each pull request?
- What alerts would you set up for failures?

---

## ✅ Final Workshop Self-Assessment

You've completed the workshop. You should now be able to:

**Project Structure**
- [ ] Explain the medallion architecture and what belongs in each layer
- [ ] Organise models into staging / intermediate / marts correctly
- [ ] Use `_` prefixed YAML files following community conventions

**Core dbt Concepts**
- [ ] Use `ref()` for dbt objects and `source()` for raw data
- [ ] Explain how `dbt_project.yml` controls materializations and schemas
- [ ] Use `dbt build` to run and test in a single command
- [ ] Navigate the compiled SQL in `target/`

**Testing**
- [ ] Write all four generic test types
- [ ] Write singular tests for custom business rules
- [ ] Write custom generic tests with parameters
- [ ] Apply `dbt_expectations` tests to mart models

**Advanced Features**
- [ ] Write and call macros from models
- [ ] Configure and run incremental models
- [ ] Install and use dbt packages
- [ ] Use tags and graph operators to run model subsets
- [ ] Create selectors for named run patterns

**Production Readiness**
- [ ] Lint SQL with SQLFluff
- [ ] Understand environment strategy (dev / ci / prod)
- [ ] Know the difference between dbt Core and dbt Cloud
- [ ] Understand Slim CI

---

## 🏆 What to Build Next

Now that you've completed the workshop, here are real DataGrokr project patterns to explore:

**1. Add a date dimension**
A `dim_date` model gives analysts a reliable spine for date-based calculations. Use `dbt_utils.date_spine` to generate it.

**2. Add snapshot models**
Snapshots capture slowly changing dimensions — track how a customer's `risk_category` changes over time using `dbt snapshot`.

**3. Connect to a real warehouse**
Swap the DuckDB profile for Snowflake, BigQuery, or Databricks. The models are identical — only `profiles.yml` changes.

**4. Set up CI with GitHub Actions**
Create `.github/workflows/dbt_ci.yml` to run `dbt build --select state:modified+` on every pull request.

**5. Deploy dbt docs**
Host the generated `target/` docs on S3, GitHub Pages, or dbt Cloud so stakeholders can browse the documentation.

---

## 🎓 Congratulations!

You've built a complete, production-ready dbt project from scratch:

```
✅ Bronze → Silver → Gold medallion architecture
✅ 15+ models across staging, intermediate, and marts
✅ 30+ data quality tests
✅ Custom macros for business logic
✅ Incremental model implementation
✅ Full documentation with lineage graph
✅ SQL linting with SQLFluff
✅ Production deployment knowledge
```

**Ask yourself:** Could you walk a new engineer through this project and explain every file? If yes, you're ready to apply these patterns on real client projects.

---

## 📚 Further Learning

- [dbt Documentation](https://docs.getdbt.com/)
- [dbt Best Practices Guide](https://docs.getdbt.com/guides/best-practices)
- [dbt Discourse Community](https://discourse.getdbt.com/)
- [dbt Slack Community](https://www.getdbt.com/community/join-the-community)
- [dbt_utils package](https://hub.getdbt.com/dbt-labs/dbt_utils/latest/)
- [dbt_expectations package](https://hub.getdbt.com/calogica/dbt_expectations/latest/)
- [SQLFluff documentation](https://docs.sqlfluff.com/)

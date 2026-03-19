# Data Model Documentation

## Entity Relationship Diagram

```
┌─────────────┐
│  CUSTOMERS  │
│─────────────│
│ customer_id │ PK
│ full_name   │
│ email       │
│ ...         │
└──────┬──────┘
       │ 1
       │
       │ N
┌──────┴──────┐
│  ACCOUNTS   │
│─────────────│
│ account_id  │ PK
│ customer_id │ FK → customers.customer_id
│ account_type│
│ ...         │
└──────┬──────┘
       │ 1
       │
       │ N
┌──────┴──────────┐
│  TRANSACTIONS   │
│─────────────────│
│ transaction_id  │ PK
│ account_id      │ FK → accounts.account_id
│ amount          │
│ ...             │
└─────────────────┘
```

## Relationships Explained

### Customers → Accounts (1:N)
- **One customer can have multiple accounts**
- Examples:
  - CUST001 has ACC001 (checking) and ACC011 (credit card)
  - CUST002 has ACC002 (savings) and ACC012 (credit card)

**Why?** Customers typically maintain multiple account types for different purposes:
- Checking for daily transactions
- Savings for long-term goals
- Credit cards for purchases

### Accounts → Transactions (1:N)
- **One account can have multiple transactions**
- Examples:
  - ACC001 has transactions: TXN001, TXN003, TXN008, TXN016, etc.
  - ACC002 has transactions: TXN002, TXN006, TXN013, etc.

**Why?** Accounts accumulate many transactions over time - deposits, withdrawals, payments, transfers.

### Transactions ⇏ Customers (NO DIRECT LINK)
- **Transactions do NOT have a direct customer_id foreign key**
- **To get from Transaction to Customer, you MUST join through Account**

**Why this design?**
1. **Data Normalization:** Customer info stored once, not duplicated per transaction
2. **Real-world accuracy:** Transactions happen on accounts, not directly on customers
3. **Flexibility:** Account ownership can change (joint accounts, transfers) without touching transactions
4. **Data integrity:** One source of truth for account-customer relationship

## How to Query Across Entities

### ❌ WRONG - This will fail
```sql
SELECT 
    t.transaction_id,
    c.customer_name  -- ERROR: No path from transactions to customers
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id  -- customer_id doesn't exist in transactions!
```

### ✅ CORRECT - Join through accounts
```sql
SELECT 
    t.transaction_id,
    t.amount,
    a.account_type,
    c.customer_name
FROM transactions t
INNER JOIN accounts a ON t.account_id = a.account_id      -- Transaction → Account
INNER JOIN customers c ON a.customer_id = c.customer_id   -- Account → Customer
```

## In dbt Models

### Staging Layer
Each staging model corresponds to one source table:

**stg_transactions.sql**
```sql
select
    transaction_id,
    account_id,      -- FK to accounts only
    -- NO customer_id here!
    transaction_date,
    amount,
    ...
from {{ source('bronze', 'transactions') }}
```

**stg_accounts.sql**
```sql
select
    account_id,
    customer_id,     -- FK to customers
    account_type,
    ...
from {{ source('bronze', 'accounts') }}
```

**stg_customers.sql**
```sql
select
    customer_id,
    full_name,
    email,
    ...
from {{ source('bronze', 'customers') }}
```

### Intermediate Layer
This is where we join entities together:

**int_customer_transactions.sql**
```sql
-- Enrich transactions with customer and account data
with transactions as (
    select * from {{ ref('stg_transactions') }}
),
accounts as (
    select * from {{ ref('stg_accounts') }}
),
customers as (
    select * from {{ ref('stg_customers') }}
)

select
    t.transaction_id,
    t.amount,
    a.account_id,
    a.account_type,
    c.customer_id,     -- Now we have customer info!
    c.customer_name
from transactions t
inner join accounts a on t.account_id = a.account_id      -- Join 1: Transaction → Account
inner join customers c on a.customer_id = c.customer_id   -- Join 2: Account → Customer
```

## Common Queries

### Get all transactions for a specific customer
```sql
SELECT 
    c.customer_name,
    a.account_type,
    t.transaction_date,
    t.amount,
    t.category
FROM customers c
INNER JOIN accounts a ON c.customer_id = a.customer_id
INNER JOIN transactions t ON a.account_id = t.account_id
WHERE c.customer_id = 'CUST001'
ORDER BY t.transaction_date DESC;
```

### Calculate customer lifetime value
```sql
SELECT 
    c.customer_id,
    c.customer_name,
    COUNT(DISTINCT a.account_id) as account_count,
    COUNT(t.transaction_id) as transaction_count,
    SUM(CASE WHEN t.transaction_type = 'credit' THEN t.amount ELSE 0 END) as total_credits,
    SUM(CASE WHEN t.transaction_type = 'debit' THEN t.amount ELSE 0 END) as total_debits
FROM customers c
INNER JOIN accounts a ON c.customer_id = a.customer_id
INNER JOIN transactions t ON a.account_id = t.account_id
WHERE t.status = 'completed'
GROUP BY c.customer_id, c.customer_name;
```

### Find accounts with no transactions
```sql
SELECT 
    a.account_id,
    a.account_type,
    c.customer_name
FROM accounts a
INNER JOIN customers c ON a.customer_id = c.customer_id
LEFT JOIN transactions t ON a.account_id = t.account_id
WHERE t.transaction_id IS NULL;
```

## Testing Relationships in dbt

### Test: All transactions have valid accounts
```yaml
# models/staging/schema.yml
models:
  - name: stg_transactions
    columns:
      - name: account_id
        tests:
          - relationships:
              to: ref('stg_accounts')
              field: account_id
```

### Test: All accounts have valid customers
```yaml
# models/staging/schema.yml
models:
  - name: stg_accounts
    columns:
      - name: customer_id
        tests:
          - relationships:
              to: ref('stg_customers')
              field: customer_id
```

### Test: Transaction → Customer integrity via join
```sql
-- tests/singular/test_transaction_customer_integrity.sql
-- This test ensures every transaction can be traced to a customer

SELECT 
    t.transaction_id,
    t.account_id
FROM {{ ref('stg_transactions') }} t
LEFT JOIN {{ ref('stg_accounts') }} a ON t.account_id = a.account_id
LEFT JOIN {{ ref('stg_customers') }} c ON a.customer_id = c.customer_id
WHERE c.customer_id IS NULL  -- This should return 0 rows
```

## Sample Data Verification

Run these queries to understand the data:

```sql
-- How many accounts does each customer have?
SELECT 
    c.customer_id,
    c.customer_name,
    COUNT(a.account_id) as account_count,
    STRING_AGG(a.account_type, ', ') as account_types
FROM bronze.customers c
LEFT JOIN bronze.accounts a ON c.customer_id = a.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY account_count DESC;

-- How many transactions on each account?
SELECT 
    a.account_id,
    a.account_type,
    c.customer_name,
    COUNT(t.transaction_id) as transaction_count,
    SUM(t.amount) as total_volume
FROM bronze.accounts a
INNER JOIN bronze.customers c ON a.customer_id = c.customer_id
LEFT JOIN bronze.transactions t ON a.account_id = t.account_id
GROUP BY a.account_id, a.account_type, c.customer_name
ORDER BY transaction_count DESC;

-- Show the full path for sample transactions
SELECT 
    t.transaction_id,
    t.transaction_date,
    t.amount,
    t.category,
    a.account_id,
    a.account_type,
    c.customer_id,
    c.customer_name
FROM bronze.transactions t
INNER JOIN bronze.accounts a ON t.account_id = a.account_id
INNER JOIN bronze.customers c ON a.customer_id = c.customer_id
LIMIT 10;
```

## Key Takeaways

✅ **Customers have Accounts** → Use accounts.customer_id  
✅ **Transactions belong to Accounts** → Use transactions.account_id  
✅ **To get Customer from Transaction** → Join through Account  
❌ **transactions.customer_id does NOT exist** → Will cause errors  

This normalized design reflects real-world banking systems and teaches proper data modeling principles!

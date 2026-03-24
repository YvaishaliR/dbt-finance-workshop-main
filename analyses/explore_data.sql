-- Should match your expectations:
-- int_customer_transactions: 96 rows (100 - 4 failed)
-- int_account_balances: 10 rows (one per account that has transactions)
SELECT count(*) FROM intermediate.int_customer_transactions;
SELECT count(*) FROM intermediate.int_account_balances;
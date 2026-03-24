SELECT
    transaction_date,
    sum(transaction_count) as total_transactions,
    sum(total_amount)      as daily_volume
FROM marts.fct_daily_transactions
GROUP BY transaction_date
ORDER BY transaction_date;
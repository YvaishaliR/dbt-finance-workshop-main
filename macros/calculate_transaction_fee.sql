-- calculate_transaction_fee
--
-- Calculates the fee for a given transaction based on type and amount.
--
-- WHY THIS IS A MACRO:
-- Fee rules are business-owned, specific enough to get wrong when copy-pasted,
-- and need to change consistently across all models when pricing updates.
-- This justifies the indirection. See MODULE_04.md for guidance on when
-- macros are — and aren't — appropriate.
--
-- Usage:
--   {{ calculate_transaction_fee('amount', 'transaction_type') }}

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

{% test valid_id_format(model, column_name, prefix) %}

-- Tests that ID columns follow the pattern PREFIX + 3 digits
-- e.g. CUST001, ACC001, TXN001

select {{ column_name }}
from {{ model }}
where
    {{ column_name }} not like '{{ prefix }}%'
    or length({{ column_name }}) != length('{{ prefix }}') + 3

{% endtest %}
{% test positive_value(model, column_name) %}

-- Tests that a numeric column contains only positive values

select {{ column_name }}
from {{ model }}
where {{ column_name }} <= 0

{% endtest %}
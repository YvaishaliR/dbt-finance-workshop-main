{% macro audit_columns() %}
    current_timestamp   as created_at,
    current_timestamp   as updated_at,
    '{{ invocation_id }}' as dbt_run_id
{% endmacro %}
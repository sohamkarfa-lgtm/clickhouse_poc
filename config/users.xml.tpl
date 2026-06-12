<?xml version="1.0"?>
<clickhouse>

    <profiles>
        <default>
            <max_memory_usage>4000000000</max_memory_usage>
            <use_uncompressed_cache>0</use_uncompressed_cache>
            <load_balancing>random</load_balancing>
        </default>
        <readonly>
            <readonly>1</readonly>
        </readonly>
    </profiles>

    <quotas>
        <default>
            <interval>
                <duration>3600</duration>
                <queries>0</queries>
                <errors>0</errors>
            </interval>
        </default>
    </quotas>

    <users>
        <!-- Developer user: full access -->
        <${CLICKHOUSE_USER}>
            <password>${CLICKHOUSE_PASSWORD}</password>
            <networks><ip>::/0</ip></networks>
            <profile>default</profile>
            <quota>default</quota>
            <access_management>1</access_management>
        </${CLICKHOUSE_USER}>

        <!-- Read-only: for demos and external tools -->
        <${CLICKHOUSE_READONLY_USER}>
            <password>${CLICKHOUSE_READONLY_PASSWORD}</password>
            <networks><ip>::/0</ip></networks>
            <profile>readonly</profile>
            <quota>default</quota>
        </${CLICKHOUSE_READONLY_USER}>
    </users>

</clickhouse>
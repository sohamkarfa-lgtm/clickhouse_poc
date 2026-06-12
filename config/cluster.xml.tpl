<?xml version="1.0"?>
<clickhouse>

    <zookeeper>
        <!-- Keeper endpoints — CH nodes use these for replication coordination -->
        <node>
            <host>keeper-01</host>
            <port>9181</port>
        </node>
        <node>
            <host>keeper-02</host>
            <port>9181</port>
        </node>
        <node>
            <host>keeper-03</host>
            <port>9181</port>
        </node>
    </zookeeper>

    <remote_servers>
        <ch_cluster>

            <!-- Shard 1: node-01 (replica 1) + node-02 (replica 2) -->
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>ch-node-01</host>
                    <port>9000</port>
                    <user>${CLICKHOUSE_USER}</user>
                    <password>${CLICKHOUSE_PASSWORD}</password>
                </replica>
                <replica>
                    <host>ch-node-02</host>
                    <port>9000</port>
                    <user>${CLICKHOUSE_USER}</user>
                    <password>${CLICKHOUSE_PASSWORD}</password>
                </replica>
            </shard>

            <!-- Shard 2: node-03 (replica 1) + node-04 (replica 2) -->
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>ch-node-03</host>
                    <port>9000</port>
                    <user>${CLICKHOUSE_USER}</user>
                    <password>${CLICKHOUSE_PASSWORD}</password>
                </replica>
                <replica>
                    <host>ch-node-04</host>
                    <port>9000</port>
                    <user>${CLICKHOUSE_USER}</user>
                    <password>${CLICKHOUSE_PASSWORD}</password>
                </replica>
            </shard>

        </ch_cluster>
    </remote_servers>

    <!-- Distributed DDL — run CREATE TABLE once, applies to all nodes -->
    <distributed_ddl>
        <path>/clickhouse/task_queue/ddl</path>
    </distributed_ddl>

</clickhouse>
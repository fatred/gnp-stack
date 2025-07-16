-- Create database
CREATE DATABASE IF NOT EXISTS bgp;
USE bgp;

-- Main NATS consumer table for all BMP messages
CREATE TABLE bgp_nats_queue (
    data String,
    subject String
) ENGINE = NATS
SETTINGS 
    nats_url = 'nats://clab-gnp-stack-nats:4222',
    nats_subjects = 'gobmp.parsed.*',
    nats_format = 'JSONEachRow';

-- ====================
-- PEER STATE CHANGES
-- ====================
CREATE TABLE bgp_peer_states (
    timestamp DateTime64(6),
    router_hash String,
    router_ip String,
    peer_hash String,
    peer_ip String,
    peer_asn UInt32,
    peer_rd String,
    state LowCardinality(String),
    is_ipv4 Bool,
    is_pre_policy Bool,
    is_adj_rib_in Bool
) ENGINE = MergeTree()
ORDER BY (timestamp, peer_ip);

CREATE MATERIALIZED VIEW bgp_peer_states_mv TO bgp_peer_states AS
SELECT
    parseDateTime64BestEffort(JSONExtractString(data, 'timestamp')) AS timestamp,
    JSONExtractString(data, 'router_hash') AS router_hash,
    JSONExtractString(data, 'router_ip') AS router_ip,
    JSONExtractString(data, 'peer_hash') AS peer_hash,
    JSONExtractString(data, 'peer_ip') AS peer_ip,
    JSONExtractUInt(data, 'peer_asn') AS peer_asn,
    JSONExtractString(data, 'peer_rd') AS peer_rd,
    JSONExtractString(data, 'state') AS state,
    JSONExtractBool(data, 'is_ipv4') AS is_ipv4,
    JSONExtractBool(data, 'is_prepolicy') AS is_pre_policy,
    JSONExtractBool(data, 'is_adj_rib_in') AS is_adj_rib_in
FROM bgp_nats_queue
WHERE subject = 'gobmp.parsed.peer';

-- ====================
-- UNICAST PREFIXES (IPv4 and IPv6)
-- ====================
CREATE TABLE bgp_unicast_prefixes (
    timestamp DateTime64(6),
    router_hash String,
    router_ip String,
    peer_hash String,
    peer_ip String,
    peer_asn UInt32,
    prefix String,
    prefix_len UInt8,
    is_ipv4 Bool,
    origin_as UInt32,
    as_path Array(UInt32),
    as_path_count UInt8,
    nexthop String,
    med UInt32,
    local_pref UInt32,
    community String,
    large_community String,
    action LowCardinality(String),
    is_prepolicy Bool,
    is_adj_rib_in Bool,
    is_nexthop_ipv4 Bool
) ENGINE = MergeTree()
ORDER BY (timestamp, peer_ip, prefix);

CREATE MATERIALIZED VIEW bgp_unicast_prefixes_mv TO bgp_unicast_prefixes AS
SELECT
    parseDateTime64BestEffort(JSONExtractString(data, 'timestamp')) AS timestamp,
    JSONExtractString(data, 'router_hash') AS router_hash,
    JSONExtractString(data, 'router_ip') AS router_ip,
    JSONExtractString(data, 'peer_hash') AS peer_hash,
    JSONExtractString(data, 'peer_ip') AS peer_ip,
    JSONExtractUInt(data, 'peer_asn') AS peer_asn,
    JSONExtractString(data, 'prefix') AS prefix,
    JSONExtractUInt(data, 'prefix_len') AS prefix_len,
    JSONExtractBool(data, 'is_ipv4') AS is_ipv4,
    JSONExtractUInt(data, 'origin_as') AS origin_as,
    JSONExtractArrayRaw(data, 'as_path') AS as_path,
    JSONExtractUInt(data, 'as_path_count') AS as_path_count,
    JSONExtractString(data, 'nexthop') AS nexthop,
    JSONExtractUInt(data, 'med') AS med,
    JSONExtractUInt(data, 'local_pref') AS local_pref,
    JSONExtractString(data, 'community_list') AS community,
    JSONExtractString(data, 'large_community_list') AS large_community,
    JSONExtractString(data, 'action') AS action,
    JSONExtractBool(data, 'is_prepolicy') AS is_prepolicy,
    JSONExtractBool(data, 'is_adj_rib_in') AS is_adj_rib_in,
    JSONExtractBool(data, 'is_nexthop_ipv4') AS is_nexthop_ipv4
FROM bgp_nats_queue
WHERE subject IN ('gobmp.parsed.unicast_prefix', 'gobmp.parsed.unicast_prefix_v4', 'gobmp.parsed.unicast_prefix_v6');

-- ====================
-- L3VPN PREFIXES
-- ====================
CREATE TABLE bgp_l3vpn_prefixes (
    timestamp DateTime64(6),
    router_hash String,
    router_ip String,
    peer_hash String,
    peer_ip String,
    peer_asn UInt32,
    prefix String,
    prefix_len UInt8,
    is_ipv4 Bool,
    origin_as UInt32,
    as_path Array(UInt32),
    nexthop String,
    rd String,
    rt String,
    action LowCardinality(String),
    label Array(UInt32)
) ENGINE = MergeTree()
ORDER BY (timestamp, peer_ip, rd, prefix);

CREATE MATERIALIZED VIEW bgp_l3vpn_prefixes_mv TO bgp_l3vpn_prefixes AS
SELECT
    parseDateTime64BestEffort(JSONExtractString(data, 'timestamp')) AS timestamp,
    JSONExtractString(data, 'router_hash') AS router_hash,
    JSONExtractString(data, 'router_ip') AS router_ip,
    JSONExtractString(data, 'peer_hash') AS peer_hash,
    JSONExtractString(data, 'peer_ip') AS peer_ip,
    JSONExtractUInt(data, 'peer_asn') AS peer_asn,
    JSONExtractString(data, 'prefix') AS prefix,
    JSONExtractUInt(data, 'prefix_len') AS prefix_len,
    JSONExtractBool(data, 'is_ipv4') AS is_ipv4,
    JSONExtractUInt(data, 'origin_as') AS origin_as,
    JSONExtractArrayRaw(data, 'as_path') AS as_path,
    JSONExtractString(data, 'nexthop') AS nexthop,
    JSONExtractString(data, 'rd') AS rd,
    JSONExtractString(data, 'rt') AS rt,
    JSONExtractString(data, 'action') AS action,
    JSONExtractArrayRaw(data, 'label') AS label
FROM bgp_nats_queue
WHERE subject IN ('gobmp.parsed.l3vpn', 'gobmp.parsed.l3vpn_v4', 'gobmp.parsed.l3vpn_v6');

-- ====================
-- LINK-STATE NODES
-- ====================
CREATE TABLE bgp_ls_nodes (
    timestamp DateTime64(6),
    router_hash String,
    router_ip String,
    peer_hash String,
    peer_ip String,
    peer_asn UInt32,
    igp_router_id String,
    asn UInt32,
    mt_id UInt16,
    area_id String,
    protocol LowCardinality(String),
    node_flags UInt8,
    node_name String,
    isis_area_id String,
    sr_algorithm Array(UInt8),
    sr_capabilities String,
    action LowCardinality(String)
) ENGINE = MergeTree()
ORDER BY (timestamp, peer_ip, igp_router_id);

CREATE MATERIALIZED VIEW bgp_ls_nodes_mv TO bgp_ls_nodes AS
SELECT
    parseDateTime64BestEffort(JSONExtractString(data, 'timestamp')) AS timestamp,
    JSONExtractString(data, 'router_hash') AS router_hash,
    JSONExtractString(data, 'router_ip') AS router_ip,
    JSONExtractString(data, 'peer_hash') AS peer_hash,
    JSONExtractString(data, 'peer_ip') AS peer_ip,
    JSONExtractUInt(data, 'peer_asn') AS peer_asn,
    JSONExtractString(data, 'igp_router_id') AS igp_router_id,
    JSONExtractUInt(data, 'asn') AS asn,
    JSONExtractUInt(data, 'mt_id') AS mt_id,
    JSONExtractString(data, 'area_id') AS area_id,
    JSONExtractString(data, 'protocol') AS protocol,
    JSONExtractUInt(data, 'node_flags') AS node_flags,
    JSONExtractString(data, 'node_name') AS node_name,
    JSONExtractString(data, 'isis_area_id') AS isis_area_id,
    JSONExtractArrayRaw(data, 'sr_algorithm') AS sr_algorithm,
    JSONExtractString(data, 'sr_capabilities') AS sr_capabilities,
    JSONExtractString(data, 'action') AS action
FROM bgp_nats_queue
WHERE subject = 'gobmp.parsed.ls_node';

-- ====================
-- LINK-STATE LINKS
-- ====================
CREATE TABLE bgp_ls_links (
    timestamp DateTime64(6),
    router_hash String,
    router_ip String,
    peer_hash String,
    peer_ip String,
    peer_asn UInt32,
    local_node_hash String,
    remote_node_hash String,
    local_link_id UInt32,
    remote_link_id UInt32,
    local_link_ip String,
    remote_link_ip String,
    admin_group UInt32,
    max_link_bw UInt32,
    max_resv_bw UInt32,
    te_metric UInt32,
    igp_metric UInt32,
    action LowCardinality(String)
) ENGINE = MergeTree()
ORDER BY (timestamp, peer_ip, local_node_hash, remote_node_hash);

CREATE MATERIALIZED VIEW bgp_ls_links_mv TO bgp_ls_links AS
SELECT
    parseDateTime64BestEffort(JSONExtractString(data, 'timestamp')) AS timestamp,
    JSONExtractString(data, 'router_hash') AS router_hash,
    JSONExtractString(data, 'router_ip') AS router_ip,
    JSONExtractString(data, 'peer_hash') AS peer_hash,
    JSONExtractString(data, 'peer_ip') AS peer_ip,
    JSONExtractUInt(data, 'peer_asn') AS peer_asn,
    JSONExtractString(data, 'local_node_hash') AS local_node_hash,
    JSONExtractString(data, 'remote_node_hash') AS remote_node_hash,
    JSONExtractUInt(data, 'local_link_id') AS local_link_id,
    JSONExtractUInt(data, 'remote_link_id') AS remote_link_id,
    JSONExtractString(data, 'local_link_ip') AS local_link_ip,
    JSONExtractString(data, 'remote_link_ip') AS remote_link_ip,
    JSONExtractUInt(data, 'admin_group') AS admin_group,
    JSONExtractUInt(data, 'max_link_bw') AS max_link_bw,
    JSONExtractUInt(data, 'max_resv_bw') AS max_resv_bw,
    JSONExtractUInt(data, 'te_metric') AS te_metric,
    JSONExtractUInt(data, 'igp_metric') AS igp_metric,
    JSONExtractString(data, 'action') AS action
FROM bgp_nats_queue
WHERE subject = 'gobmp.parsed.ls_link';

-- ====================
-- LINK-STATE PREFIXES
-- ====================
CREATE TABLE bgp_ls_prefixes (
    timestamp DateTime64(6),
    router_hash String,
    router_ip String,
    peer_hash String,
    peer_ip String,
    peer_asn UInt32,
    local_node_hash String,
    prefix String,
    prefix_len UInt8,
    ospf_route_type UInt8,
    igp_flags UInt8,
    igp_metric UInt32,
    action LowCardinality(String)
) ENGINE = MergeTree()
ORDER BY (timestamp, peer_ip, local_node_hash, prefix);

CREATE MATERIALIZED VIEW bgp_ls_prefixes_mv TO bgp_ls_prefixes AS
SELECT
    parseDateTime64BestEffort(JSONExtractString(data, 'timestamp')) AS timestamp,
    JSONExtractString(data, 'router_hash') AS router_hash,
    JSONExtractString(data, 'router_ip') AS router_ip,
    JSONExtractString(data, 'peer_hash') AS peer_hash,
    JSONExtractString(data, 'peer_ip') AS peer_ip,
    JSONExtractUInt(data, 'peer_asn') AS peer_asn,
    JSONExtractString(data, 'local_node_hash') AS local_node_hash,
    JSONExtractString(data, 'prefix') AS prefix,
    JSONExtractUInt(data, 'prefix_len') AS prefix_len,
    JSONExtractUInt(data, 'ospf_route_type') AS ospf_route_type,
    JSONExtractUInt(data, 'igp_flags') AS igp_flags,
    JSONExtractUInt(data, 'igp_metric') AS igp_metric,
    JSONExtractString(data, 'action') AS action
FROM bgp_nats_queue
WHERE subject = 'gobmp.parsed.ls_prefix';

-- ====================
-- EVPN MESSAGES
-- ====================
CREATE TABLE bgp_evpn (
    timestamp DateTime64(6),
    router_hash String,
    router_ip String,
    peer_hash String,
    peer_ip String,
    peer_asn UInt32,
    rd String,
    rt String,
    esi String,
    ethernet_tag UInt32,
    mac_address String,
    ip_address String,
    ip_len UInt8,
    label Array(UInt32),
    action LowCardinality(String)
) ENGINE = MergeTree()
ORDER BY (timestamp, peer_ip, rd, mac_address);

CREATE MATERIALIZED VIEW bgp_evpn_mv TO bgp_evpn AS
SELECT
    parseDateTime64BestEffort(JSONExtractString(data, 'timestamp')) AS timestamp,
    JSONExtractString(data, 'router_hash') AS router_hash,
    JSONExtractString(data, 'router_ip') AS router_ip,
    JSONExtractString(data, 'peer_hash') AS peer_hash,
    JSONExtractString(data, 'peer_ip') AS peer_ip,
    JSONExtractUInt(data, 'peer_asn') AS peer_asn,
    JSONExtractString(data, 'rd') AS rd,
    JSONExtractString(data, 'rt') AS rt,
    JSONExtractString(data, 'esi') AS esi,
    JSONExtractUInt(data, 'ethernet_tag') AS ethernet_tag,
    JSONExtractString(data, 'mac_address') AS mac_address,
    JSONExtractString(data, 'ip_address') AS ip_address,
    JSONExtractUInt(data, 'ip_len') AS ip_len,
    JSONExtractArrayRaw(data, 'label') AS label,
    JSONExtractString(data, 'action') AS action
FROM bgp_nats_queue
WHERE subject = 'gobmp.parsed.evpn';

-- ====================
-- SR POLICY MESSAGES
-- ====================
CREATE TABLE bgp_sr_policy (
    timestamp DateTime64(6),
    router_hash String,
    router_ip String,
    peer_hash String,
    peer_ip String,
    peer_asn UInt32,
    distinguisher UInt32,
    color UInt32,
    endpoint String,
    is_ipv4 Bool,
    preference UInt32,
    binding_sid UInt32,
    action LowCardinality(String)
) ENGINE = MergeTree()
ORDER BY (timestamp, peer_ip, distinguisher, color);

CREATE MATERIALIZED VIEW bgp_sr_policy_mv TO bgp_sr_policy AS
SELECT
    parseDateTime64BestEffort(JSONExtractString(data, 'timestamp')) AS timestamp,
    JSONExtractString(data, 'router_hash') AS router_hash,
    JSONExtractString(data, 'router_ip') AS router_ip,
    JSONExtractString(data, 'peer_hash') AS peer_hash,
    JSONExtractString(data, 'peer_ip') AS peer_ip,
    JSONExtractUInt(data, 'peer_asn') AS peer_asn,
    JSONExtractUInt(data, 'distinguisher') AS distinguisher,
    JSONExtractUInt(data, 'color') AS color,
    JSONExtractString(data, 'endpoint') AS endpoint,
    JSONExtractBool(data, 'is_ipv4') AS is_ipv4,
    JSONExtractUInt(data, 'preference') AS preference,
    JSONExtractUInt(data, 'binding_sid') AS binding_sid,
    JSONExtractString(data, 'action') AS action
FROM bgp_nats_queue
WHERE subject IN ('gobmp.parsed.sr_policy', 'gobmp.parsed.sr_policy_v4', 'gobmp.parsed.sr_policy_v6');

-- ====================
-- STATISTICS MESSAGES
-- ====================
CREATE TABLE bgp_statistics (
    timestamp DateTime64(6),
    router_hash String,
    router_ip String,
    peer_hash String,
    peer_ip String,
    peer_asn UInt32,
    stats_type UInt32,
    stats_len UInt32,
    stats_data String
) ENGINE = MergeTree()
ORDER BY (timestamp, peer_ip, stats_type);

CREATE MATERIALIZED VIEW bgp_statistics_mv TO bgp_statistics AS
SELECT
    parseDateTime64BestEffort(JSONExtractString(data, 'timestamp')) AS timestamp,
    JSONExtractString(data, 'router_hash') AS router_hash,
    JSONExtractString(data, 'router_ip') AS router_ip,
    JSONExtractString(data, 'peer_hash') AS peer_hash,
    JSONExtractString(data, 'peer_ip') AS peer_ip,
    JSONExtractUInt(data, 'peer_asn') AS peer_asn,
    JSONExtractUInt(data, 'stats_type') AS stats_type,
    JSONExtractUInt(data, 'stats_len') AS stats_len,
    JSONExtractString(data, 'stats_data') AS stats_data
FROM bgp_nats_queue
WHERE subject = 'gobmp.parsed.statistics';

-- ====================
-- FLOWSPEC MESSAGES
-- ====================
CREATE TABLE bgp_flowspec (
    timestamp DateTime64(6),
    router_hash String,
    router_ip String,
    peer_hash String,
    peer_ip String,
    peer_asn UInt32,
    prefix String,
    prefix_len UInt8,
    is_ipv4 Bool,
    rules String,
    action LowCardinality(String)
) ENGINE = MergeTree()
ORDER BY (timestamp, peer_ip, prefix);

CREATE MATERIALIZED VIEW bgp_flowspec_mv TO bgp_flowspec AS
SELECT
    parseDateTime64BestEffort(JSONExtractString(data, 'timestamp')) AS timestamp,
    JSONExtractString(data, 'router_hash') AS router_hash,
    JSONExtractString(data, 'router_ip') AS router_ip,
    JSONExtractString(data, 'peer_hash') AS peer_hash,
    JSONExtractString(data, 'peer_ip') AS peer_ip,
    JSONExtractUInt(data, 'peer_asn') AS peer_asn,
    JSONExtractString(data, 'prefix') AS prefix,
    JSONExtractUInt(data, 'prefix_len') AS prefix_len,
    JSONExtractBool(data, 'is_ipv4') AS is_ipv4,
    JSONExtractString(data, 'rules') AS rules,
    JSONExtractString(data, 'action') AS action
FROM bgp_nats_queue
WHERE subject IN ('gobmp.parsed.flowspec', 'gobmp.parsed.flowspec_v4', 'gobmp.parsed.flowspec_v6');

-- -- ====================
-- -- USEFUL VIEWS FOR ANALYSIS
-- -- ====================

-- -- Current BGP table (latest state of all prefixes)
-- CREATE VIEW bgp_current_table AS
-- SELECT *
-- FROM bgp_unicast_prefixes
-- WHERE (peer_ip, prefix) IN (
--     SELECT peer_ip, prefix
--     FROM bgp_unicast_prefixes
--     WHERE action != 'del'
--     GROUP BY peer_ip, prefix
--     HAVING timestamp = max(timestamp)
-- );

-- -- Peer state summary
-- CREATE VIEW bgp_peer_summary AS
-- SELECT 
--     peer_ip,
--     peer_asn,
--     router_ip,
--     state,
--     count() as update_count,
--     max(timestamp) as last_update
-- FROM bgp_peer_states
-- GROUP BY peer_ip, peer_asn, router_ip, state
-- ORDER BY last_update DESC;
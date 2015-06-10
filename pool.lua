#!/usr/bin/env tarantool

local fiber = require('fiber')
local log = require('log')
local msgpack = require('msgpack')
local remote = require('net.box')
local yaml = require('yaml')

local servers = {}
local servers_n = 0
local zones_n = 0

local REMOTE_TIMEOUT = 500
local HEARTBEAT_TIMEOUT = 500
local DEAD_TIMEOUT = 10
local INFINITY_MIN = -1
local RECONNECT_AFTER = msgpack.NULL

local self_server
heartbeat_state = {}

local init_complete = false
local epoch_counter = 1
local configuration = {}
local pool_obj

-- heartbeat monitoring function
function heartbeat()
    log.debug('ping')
    return heartbeat_state
end

-- default callbacks
local function on_connfail(srv)
    log.info('%s connection failed', srv.uri)
end

local function on_connected_one(srv)
    log.info(' - %s - connected', srv.uri)
end

local function on_connected()
    log.info('connected to all servers')
end

local function on_disconnect_one(srv)
    log.info("kill %s by dead timeout", srv.uri)
end

local function on_disconnect_zone(name)
    log.info("zone %s has no active connections", name)
end

local function on_disconnect()
    log.info("there is no active connections")
end

local function on_init()
    log.info('started')
end


local function server_is_ok(srv, dead)
    return not srv.ignore and (srv.conn:is_connected() or dead)
end

local function merge_zones()
    local all_zones = {}
    i = 1
    for _, zone in pairs(servers) do
        for _, server in pairs(zone.list) do
            all_zones[i] = server
            i = i + 1
        end
    end
    return all_zones
end

local function all(zone_id, include_dead)
    local res = {}
    local k = 1
    local zone

    if zone_id ~= nil then
        zone = servers[zone_id]
    else
        zone = { list=merge_zones() }
    end

    for _, srv in pairs(zone.list) do
        if server_is_ok(srv, include_dead) then
            res[k] = srv
            k = k + 1
        end
    end
    return res
end

local function one(zone_id, include_dead)
    local active_list = all(zone_id, include_dead)
    return active_list[math.random(#active_list)]
end

local function zone_list()
    local names = {}
    local i = 1
    for z_name, _ in pairs(servers) do
        names[i] = z_name
        i = i + 1
    end
    return names
end

local function _on_disconnect(srv)
    pool_obj.on_disconnect_one(srv)

    -- check zone and pool
    local d = 0
    local all_zones = zone_list()
    for _, name in pairs(all_zones) do
        local alive = all(name)
        if #alive == 0 then
            pool_obj.on_disconnect_zone(name)
            d = d + 1
        end
    end
    if d == #all_zones then
        pool_obj.on_disconnect()
    end
end

local function monitor_fiber()
    fiber.name("monitor")
    local i = 0
    while true do
        i = i + 1
        local server = one(nil, true)
        local uri = server.uri
        local dead = false
        for k, v in pairs(heartbeat_state) do
            -- true only if there is stuff in heartbeat_state
            if k ~= uri then
                dead = true
                log.debug("monitoring: %s", uri)
                break
            end
        end
        for k, v in pairs(heartbeat_state) do
            -- kill only if DEAD_TIMEOUT become in all servers
            if k ~= uri and (v[uri] == nil or v[uri].try < DEAD_TIMEOUT) then
                log.debug("%s is alive", uri)
                dead = false
                break
            end
        end

        if dead then
            server.conn:close()
            server.ignore = true
            heartbeat_state[uri] = nil
            epoch_counter = epoch_counter + 1
            pool_obj._on_disconnect(server)
        end
        fiber.sleep(math.random(100)/1000)
    end
end

-- merge node response data with local table by fiber time
local function merge_tables(response)
    if response == nil then
        return
    end
    for seen_by_uri, node_data in pairs(heartbeat_state) do
        local node_table = response[seen_by_uri]
        if node_table ~= nil then
            for uri, data in pairs(node_table) do
                if data.ts > node_data[uri].ts then
                    log.debug('merged heartbeat from ' .. seen_by_uri .. ' with ' .. uri)
                    node_data[uri] = data
                end
            end
        end
    end
end

local function monitor_fail(uri)
    for _, zone in pairs(servers) do
        for _, server in pairs(zone.list) do
            if server.uri == uri then
                pool_obj.on_connfail(server)
                break
            end
        end
    end
end

-- heartbeat table and opinions management
local function update_heartbeat(uri, response, status)
    -- set or update opinions and timestamp
    local opinion = heartbeat_state[self_server.uri]
    if not status then
        opinion[uri].try = opinion[uri].try + 1
        monitor_fail(uri)
    else
        opinion[uri].try = 0
    end
    opinion[uri].ts = fiber.time()
    -- update local heartbeat table
    merge_tables(response)
end

-- heartbeat worker
local function heartbeat_fiber()
    fiber.name("heartbeat")
    local i = 0
    while true do
        i = i + 1
        -- random select node to check
        local server = one(nil, true)
        local uri = server.uri
        log.debug("checking %s", uri)

        -- get heartbeat from node
        local response
        local status, err_state = pcall(function()
            response = server.conn:timeout(
                HEARTBEAT_TIMEOUT):eval("return heartbeat()")
        end)
        -- update local heartbeat table
        update_heartbeat(uri, response, status)
        log.debug("%s", yaml.encode(heartbeat_state))
        -- randomized wait for next check
        fiber.sleep(math.random(1000)/1000)
    end
end

-- function to check a connection after it's established
local function check_connection(conn)
    return true
end

local function is_table_filled()
    local result = true
    for _, server in pairs(configuration.servers) do
        if heartbeat_state[server.uri] == nil then
            result = false
            break
        end
        for _, lserver in pairs(configuration.servers) do
            local srv = heartbeat_state[server.uri][lserver.uri]
            if srv == nil then
                result = false
                break
            end
        end
    end
    return result
end

local function wait_table_fill()
    while not is_table_filled() do
        fiber.sleep(0.01)
    end
end

local function fill_table()
    -- fill monitor table with start values
    for _, server in pairs(configuration.servers) do
        heartbeat_state[server.uri] = {}
        for _, lserver in pairs(configuration.servers) do
            heartbeat_state[server.uri][lserver.uri] = {
                try= 0,         
                ts=INFINITY_MIN
            }
        end
    end
end

local function get_heartbeat()
    return heartbeat_state
end

local function enable_operations()
    -- set helpers
    pool_obj.get_heartbeat = get_heartbeat
end

local function connect(id, server)
    local zone = servers[server.zone]
    local conn
    log.info(' - %s - connecting...', server.uri)
    while true do
        local uri = server.login..':'..server.password..'@'..server.uri
        conn = remote:new(uri, { reconnect_after = RECONNECT_AFTER })
        if conn:ping() and check_connection(conn) then
            local srv = {
                uri = server.uri, conn = conn,
                login=server.login, password=server.password,
                id = id
            }
            zone.n = zone.n + 1
            zone.list[zone.n] = srv
            pool_obj.on_connected_one(srv)
            if conn:eval("return box.info.server.uuid") == box.info.server.uuid then
                self_server = srv
            end
            break
        end
        conn:close()
        log.warn(" - %s - server check failure", server.uri)
        fiber.sleep(1)
    end
end

-- connect with servers
local function init(cfg)
    configuration = cfg
    log.info('establishing connection to cluster servers...')

    servers_n = 0
    zones_n = 0
    for id, server in pairs(cfg.servers) do
        servers_n = servers_n + 1
        local zone_name = server.zone
        if zone_name == nil then
            zone_name = 'default'
        end
        if servers[zone_name] == nil then
            zones_n = zones_n + 1
            servers[zone_name] = { id = zones_n, n = 0, list = {} }
        end

        connect(id, server)
    end
    pool_obj.on_connected()
    fill_table()

    -- run monitoring and heartbeat fibers by default
    if cfg.monitor == nil or cfg.monitor then
        fiber.create(heartbeat_fiber)
        fiber.create(monitor_fiber)
    end

    enable_operations()
    init_complete = true
    pool_obj.on_init()
    return true
end

local function len()
    return servers_n
end

local function is_connected()
    return init_complete
end

local function wait_connection()
    while not is_connected() do
        fiber.sleep(0.01)
    end
end

local function get_epoch()
    return epoch_counter
end

local function wait_epoch(epoch)
    while get_epoch() < epoch do
        fiber.sleep(0.01)
    end
end

pool_obj = {
    REMOTE_TIMEOUT = REMOTE_TIMEOUT,
    HEARTBEAT_TIMEOUT = HEARTBEAT_TIMEOUT,
    DEAD_TIMEOUT = DEAD_TIMEOUT,
    RECONNECT_AFTER = RECONNECT_AFTER,

    zones = servers,
    len = len,
    is_connected = is_connected,
    wait_connection = wait_connection,
    get_epoch = get_epoch,
    wait_epoch = wait_epoch,
    is_table_filled = is_table_filled,
    wait_table_fill = wait_table_fill,
    init = init,
    _on_disconnect = _on_disconnect,
    on_connfail = on_connfail,
    on_connected = on_connected,
    on_connected_one = on_connected_one,
    on_disconnect_one = on_disconnect_one,
    on_disconnect_zone = on_disconnect_zone,
    on_disconnect = on_disconnect,
    on_init = on_init,

    all = all,
    one = one,
    zone_list = zone_list,
}

return pool_obj
-- vim: ts=4:sw=4:sts=4:et

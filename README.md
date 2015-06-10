# Connection-pool
Lua connection pool for tarantool net.box with network zones support.

###api
* `pool:init(cfg)` - init connection pool with given config
* `pool:one(zone_id)`  - returns random active connection from given zone(can be nil)
* `pool:all(zone_id)`  - returns all active connections from given zone(can be nil)
* `pool:zone_list()` - returns list of network zones ids

if `zone_id` is nil - return connections from all zones

###available callbacks
* `on_connected` - all nodes connected
* `on_connected_one` - one node connected
* `on_disconnect` - lost all connations in pool
* `on_disconnect_one` - one node disconnect
* `on_disconnect_zone` - all nodes in zone disconnected
* `on_connfail` - monitoring detected connection problem

###configuration
global:
* `monitor` - enable connection monitoring(by default `true`)
* `server` - table with servers settings

servers:
* `uri` - server uri with port
* `login`
* `password`
* `zone` - network zone(can be nil)

###example
```lua
pool = require('pool')
-- set callback
pool.on_connected = function()
    log.info('hello world')
end

-- config with 2 nodes in 2 zones and monitoring
local cfg = {
    servers = {
        {
            uri = 'localhost:3313', login = 'tester',
            password = 'pass', zone = 'myzone1'
        };
        {
            uri = 'localhost:3314', login = 'tester',
            password = 'pass', zone = 'myzone2'
        };
    };
    monitor = true;
}

-- start
pool.init(cfg)
```
if there is no zone specified - all servers are in single zone

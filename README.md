# Connection-pool
Lua connection pool for tarantool net.box

###api
* `pool:init()` - init connection pool
* `pool:one()`  - returns random active connection
* `pool:all()`  - returns all active connections

###available callbacks
* `on_connected` - all nodes event
* `on_connected_one`
* `on_disconnect_one`
* `on_connfail` - monitoring detected connection problem

### configuration example
```lua
pool = require('pool')
pool.on_connected = function()
    log.info('hello world')
end
local cfg = {
    servers = {
        {
            uri = 'localhost:3313', login = 'tester',
            password = 'pass', binary = 3313
        };
        {
            uri = 'localhost:3314', login = 'tester',
            password = 'pass', binary = 3314
        };
    };
    monitor = true;
}
pool.init(cfg)
```

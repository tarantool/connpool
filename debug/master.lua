lib_pool = require('pool')
log = require('log')
yaml = require('yaml')
pool = lib_pool.new()
pool.on_connected = function()
    log.info('on_connect callback')
end

pool.on_init = function()
    log.info('on_init callback')
end

local cfg = {
    pool_name = 'mypool';
    servers = {
        { 
            uri = 'localhost:3313', login = 'tester', 
            password = 'pass', zone = '0'
        };
        { 
            uri = 'localhost:3314', login = 'tester', 
            password = 'pass', zone = '1'
        };
    };
}

box.cfg {
    slab_alloc_arena = 1.0;
    slab_alloc_factor = 1.06;
    slab_alloc_minimal = 16;
    wal_mode = 'none';
    logger = 'm1.log';
    log_level = 5;
    listen = 3313;
}

box.schema.user.create('tester', { password = 'pass' })
box.schema.user.grant('tester', 'read,write,execute', 'universe')

-- init connections
pool:init(cfg)

-- wait for operations
require('fiber').sleep(3)

-- show results
log.info('Len=%d', #pool:all())
log.info(yaml.encode(pool:get_heartbeat()))

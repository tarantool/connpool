#!/usr/bin/env tarantool
pool = require('pool')
log = require('log')
os = require('os')
fiber = require('fiber')

local cfg = {
    servers = {
        { 
            uri = 'localhost:33130', login = 'tester', 
            password = 'pass', zone = 'myzone1'
        };
        { 
            uri = 'localhost:33131', login = 'tester', 
            password = 'pass', zone = 'myzone2'
        };
        {
            uri = 'localhost:33132', login = 'tester', 
            password = 'pass', zone = 'myzone3'
        };

    };
}

box.cfg {
    slab_alloc_arena = 0.1;
    wal_mode = 'none';
    listen = 33130;
    custom_proc_title  = "master"
}

require('console').listen(os.getenv('ADMIN'))

pcall(function()
  box.schema.user.create('tester', { password = 'pass'})
  box.schema.user.grant('tester', 'read,write,execute', 'universe')
end)

i = 1
j = 1
results = {}
d_results = {}

pool.on_init = function()
    results[i] = 'init complete'
    i = i + 1
end

pool.on_connected_one = function(srv)
    results[i] = 'server connected'
    i = i + 1
end

pool.on_connected = function()
    results[i] = 'all nodes connected'
    i = i + 1
end

pool.on_disconnect_one = function(srv)
    d_results[j] = 'server disconnected'
    j = j + 1
end

pool.on_disconnect_zone = function(name)
    d_results[j] = 'zone ' .. name ..' disconnected'
    j = j + 1
end

pool.on_connfail = function(srv)
    d_results[j] = 'server ' .. srv.uri .. ' connection fail'
    j = j + 1
end

-- init
fiber.create(function()
    pool.init(cfg)
end)


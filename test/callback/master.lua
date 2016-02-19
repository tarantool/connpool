#!/usr/bin/env tarantool
lib_pool = require('connpool')
log = require('log')
os = require('os')
fiber = require('fiber')

local cfg = {
    pool_name = 'mypool';
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

box.once("bootstrap", function()
  box.schema.user.create('tester', { password = 'pass'})
  box.schema.user.grant('tester', 'read,write,execute', 'universe')
end)

i = 1
j = 1
results = {}
d_results = {}
fails = 0
pool = lib_pool.new()

pool.on_init = function(self)
    results[i] = 'init complete'
    i = i + 1
end

pool.on_connected_one = function(self, srv)
    results[i] = 'server connected'
    i = i + 1
end

pool.on_connected = function(self)
    results[i] = 'all nodes connected'
    i = i + 1
end

pool.on_disconnect_one = function(self, srv)
    d_results[j] = 'server disconnected'
    j = j + 1
end

pool.on_disconnect_zone = function(self, name)
    d_results[j] = 'zone ' .. name ..' disconnected'
    j = j + 1
end

pool.on_connfail = function(self, srv)
    fails = fails + 1
end

-- init
fiber.create(function()
    pool:init(cfg)
end)


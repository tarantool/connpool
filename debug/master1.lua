pool = require('pool')
log = require('log')
yaml = require('yaml')

local cfg = {
    servers = {
        { uri = 'localhost:3313', login = 'tester', password = 'pass', binary = 3313 };
        { uri = 'localhost:3314', login = 'tester', password = 'pass', binary = 3314 };
    };
}

box.cfg {
    slab_alloc_arena = 1.0;
    slab_alloc_factor = 1.06;
    slab_alloc_minimal = 16;
    wal_mode = 'none';
    logger = 'm2.log';
    work_dir = 'work';
    log_level = 5;
    listen = 3314;
}

box.schema.user.create('tester', { password = 'pass' })
box.schema.user.grant('tester', 'read,write,execute', 'universe')

-- init shards
pool.init(cfg)

-- wait for operations
require('fiber').sleep(3)

-- show results
log.info('Len=%d', #pool.all())

package = 'pool'
version = 'scm-1'
source  = {
    url    = 'git://github.com/tarantool/connection-pool.git',
    branch = 'master',
}
description = {
    summary  = "Net box connection pool for Tarantool",
    homepage = 'https://github.com/tarantool/connection-pool.git',
    license  = 'BSD',
}
dependencies = {
    'lua >= 5.1'
}
build = {
    type = 'builtin',

    modules = {
        ['pool'] = 'pool.lua'
    }
}

-- vim: syntax=lua

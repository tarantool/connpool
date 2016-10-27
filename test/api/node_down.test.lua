env = require('test_run')
test_run = env.new()
test_run:cmd("create server master1 with script='api/master1.lua', lua_libs='api/lua/connpool.lua'")
test_run:cmd("create server master2 with script='api/master2.lua', lua_libs='api/lua/connpool.lua'")
test_run:cmd("start server master1")
test_run:cmd("start server master2")
pool:wait_connection()
--shard.wait_epoch(3)
pool:wait_table_fill()
pool:is_table_filled()

test_run:cmd("switch master1")
pool:wait_table_fill()
pool:is_table_filled()

test_run:cmd("switch master2")
pool:wait_table_fill()
pool:is_table_filled()

test_run:cmd("switch default")

servers = pool:all()
#servers

-- Kill server and wait for monitoring fibers kill
_ = test_run:cmd("stop server master1")

-- Check that node is removed from shard
pool:wait_epoch(2)
pool:is_table_filled()

test_run:cmd("switch master2")
pool:wait_epoch(2)
pool:is_table_filled()
test_run:cmd("switch default")

servers = pool:all()
#servers

_ = test_run:cmd("stop server master2")
test_run:cmd("cleanup server master1")
test_run:cmd("cleanup server master2")
test_run:cmd("restart server default with cleanup=1")

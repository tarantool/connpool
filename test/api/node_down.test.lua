--# create server master1 with script='api/master1.lua', lua_libs='api/lua/connpool.lua'
--# create server master2 with script='api/master2.lua', lua_libs='api/lua/connpool.lua'
--# start server master1
--# start server master2
--# set connection default
pool:wait_connection()
--shard.wait_epoch(3)
pool:wait_table_fill()
pool:is_table_filled()

--# set connection master1
pool:wait_table_fill()
pool:is_table_filled()

--# set connection master2
pool:wait_table_fill()
pool:is_table_filled()

--# set connection default

servers = pool:all()
#servers

-- Kill server and wait for monitoring fibers kill
--# stop server master1

-- Check that node is removed from shard
pool:wait_epoch(2)
pool:is_table_filled()

--# set connection master2
pool:wait_epoch(2)
pool:is_table_filled()
--# set connection default

servers = pool:all()
#servers

--# stop server master2
--# cleanup server master1
--# cleanup server master2
--# stop server default
--# start server default
--# set connection default

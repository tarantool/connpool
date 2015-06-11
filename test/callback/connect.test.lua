--# create server master1 with script='callback/master1.lua', lua_libs='callback/lua/pool.lua'
--# create server master2 with script='callback/master2.lua', lua_libs='callback/lua/pool.lua'
--# start server master1
--# start server master2
--# set connection default

pool:wait_connection()
pool:wait_table_fill()
results

--# stop server master1
--# cleanup server master1
--# stop server master2
--# cleanup server master2
--# stop server default
--# start server default
--# set connection default

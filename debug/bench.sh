killall tarantool
rm *.snap
rm *.log
rm work/*.log
rm work/*.snap

tarantool master.lua &
tarantool master1.lua &


--[[
Casino Mod
This will include several machines/nodes which allow
players to play casino like games within minetest.

The currency is credits, therefore it looks for
an installed money2 or at least money mod in order
to work.

]]

-- start with some basic values/settings

if not minetest.get_modpath( 'money2' ) or not minetest.get_modpath( 'money' ) then
	print( '[casino] Missing dependency: money2 or money' )
end

casino = {}

casino.__version = 136457

function casino.get_version( )
	return casino.__version
end

-- ! Set this to any amount. This is the amount of chipcoins
-- each new player would get on server join. Default is 0,
-- since we want the players to convert their credits into coins

casino.initial_coins = 0

-- platform compatibility
casino.sep = package.config:sub(1,1)

-- the following function definitions depend on the money mod installed
-- to allow us of charging the user in any way without getting errors
--[[
Note: I designed the following section in order to keep the intepreted
code a bit smaller but increasing loading time of the server. The
interpreter will only define the function that fits the installed
dependency.
]]

if minetest.get_modpath( 'money2' ) then
	function casino.charge_user( name, amount )
		local result = money.dec( name, amount )
		if result then
			return false
		else
			return true
		end
	end

	function casino.pay_user( name, amount )
		if money.add( name, amount ) then
			return false
		else
			return true
		end
	end
else
	function casino.charge_user( name, amount )
		if not money.accounts[name] or money.accounts[name].money then
			return false
		end
		-- money.get_money() should return normal int
		local user_credits = money.get_money( name )
		if user_credits >= amount then
			money.set_money( name, user_credits - amount )
			return true
		else
			return false
		end
	end

	function casino.pay_user( name, amount )
		if not money.accounts[name] or money.accounts[name].money then
			return false
		end
		money.set_money( name, money.accounts[name].money + amount )
		return true
	end
end

-- Some things that the other mods can access

casino.mod_data = {}

function casino.save_data( )
	local data_file = io.open( minetest.get_worldpath()..casino.sep..'casino_data', 'w' )
	if not data_file then
		minetest.log( 'error', '[casino] Could not open file in order to save data. All not saved data may be lost' )
		return
	end
	data_file:write( minetest.serialize( casino.mod_data ) )
	data_file:close()
end

function casino.get_data( )
	local data_file = io.open( minetest.get_worldpath()..casino.sep..'casino_data', 'r' )
	if not data_file then
		minetest.log( 'error', '[casino] Could not open file in order to load data. No data will be available.' )
		return
	end
	local data = minetest.deserialize( data_file:read( '*all' ) )
	if type( data ) == type( {} ) then
		casino.mod_data = data
	else
		minetest.log( 'error' , '[casino] Data returned by file <'..minetest.get_worldpath()..casino.sep..'casino_data'..'> fits not expected format' )
		casino.mod_data = {}
		return
	end
end

casino.get_data()

-- test suite
dofile( minetest.get_modpath( 'casino' )..casino.sep..'lotto.lua' )

-- everything ready to go
print( '[casino] v'..casino.__version..' loaded ' )

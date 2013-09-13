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

casino.__version = 67849

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
end


-- chipcoin related

casino.accounts = {}

function casino.save_data( )
	-- always overwrite existing file
	local account_file = io.open( minetest.get_worldpath()..casino.sep..'casino_accounts', 'w' )
	if account_file then
		account_file:write( minetest.serialize( casino.accounts ) )
		account_file:close()
	else
		minetest.log( 'error' , '[casino] Was not able to save user data...' )
	end
end

function casino.load_data( )
	local account_file = io.open( minetest.get_worldpath()..casino.sep..'casino_accounts', 'r' )
	if account_file then
		local temp_account_data = minetest.deserialize( account_file:read('*all') )
		if temp_account_data and type( temp_account_data ) == type( {} ) then
			casino.accounts = temp_account_data
		else
			minetest.log( 'info', '[casino] Could not read existin account file. Creating new' )
		end
	else
		minetest.log( 'info' , '[casino] Account file does not exist or cannot be opened. Creating new' )
	end
end

function casino.charge_player( name, amount )
	local return_bool = nil
	if casino.accounts[name] and casino.accounts[name] >= amount then
		casino.accounts[name] = casino.accounts[name] - amount
		return_bool = true
	else
		return_bool = false
	end
	casino.save_data()
end

function casino.pay_player( name, amount )
	local return_bool = nil
	if casino.accounts[name] then
		casino.accounts[name] = casino.accounts[name] + amount
		return_bool = true
	else
		return_bool = false
	end
	casino.save_data()
end

function casino.player_coins( name )
	if casino.accounts[name] then
		return casino.accounts[name]
	else
		return false
	end
end

function casino.new_player( name )
	if not casino.accounts[name] then
		casino.accounts[name] = casino.initial_coins
		casino.save_data()
	end
end


-- test suite
dofile( minetest.get_modpath( 'casino' )..casino.sep..'lotto.lua' )

-- everything ready to go
print( '[casino] v'..casino.__version..' loaded ' )

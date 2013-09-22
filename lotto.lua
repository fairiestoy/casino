--[[
Lotto based game.
The user can buy a ticket at one of the machines and
chooses a number. Each player has a limit set in
one of the vars below. At the end of a specific timespan,
this script will choose a random number. If this fits one
of the registered numbers, the specific user or users will
get the amount of credits payed minus a percentage of the
total amount. It doesn't matter if this user is not online,
he will get a mail (if chatplus or similiar is installed)

Note:
The way how this is payed is changed a bit. Instead of getting
it payed even if you are online is no longer implemented.
Instead the user is forced to carry the fitting ticket to a
second machine which will then pay the amount the user has
won.

Note:
The following is for somebody who wants to work on this (and
for me to remember what i am doing here. It needs a lot of
iterations, maybe i should change this into something
more comfortable to work with.

player_register table structur

player_register = {
	player_name = {
		last_login = [os.time() value],
		1(index) = {
			session_id = [session_id number],
			tickets = {
				1(index) = [number],
				2(index) = [number],
				3(index) = [number],
				4(index) = [number]
				},
			},
		2(index) = {
			session_id = [session_id number],
			tickets = {
				1(index) = [number],
				2(index) = [number],
				3(index) = [number],
				4(index) = [number]
				},
			},
		3(index) = {
			session_id = [session_id number],
			tickets = {
				1(index) = [number],
				2(index) = [number],
				3(index) = [number],
				4(index) = [number]
				},
			},
	},
}

win_register table structur

win_register = {
	1(index) = {
		session_id = [session_id number],
		jackpot_per_person = [jackpot divided by winners],
		remaining_pays = [number],
		},
	2(index) = {
		session_id = [session_id number],
		jackpot_per_person = [jackpot divided by winners],
		remaining_pays = [number],
		},
}
]]

-- version: 139529 (00022109)

lotto = {}

-- price setting (in credits)

lotto.ticket_price = 200

--[[
the following value will decrease the amount of the jackpot by this amount ( in percent ). This will take some credits out of the
game without letting the user notice it.
]]
lotto.managing_cost = 10

-- timespan until decision (counted in days)

lotto.timespan = 7 -- default 7 days

-- Change this value if you have to many active players (maybe change this to automagically choose a number from player files)
-- Currently the default value is 1000. So with 30 active members and a limit of 4 tickets per person, we have about 120 possible
-- numbers. So each user has a theoretical win chance of 0,4%. If you want to raise this, just change the ticket limit or this max value,
-- but be carefull with this values. They may increase the chance to much, and take the 'Luck' out of the game

lotto.max_number = 1000
lotto.max_ticket_per_user = 4

--[[
lotto.max_stored_sessions indicates how many sessions (including the current one) are stored for the winning numbers.
The default is 3, therefore we only store 3 winnumber/session_id combinations once a time. With the default
timespan (7 days), the user has 3 weeks to get his price before it vanishes.
]]

lotto.max_stored_sessions = 3

--[[
The following setting is very sensitive. It will be included in the eChat mod also. It shows the time until a user gets deleted from the
register to keep the table clean. Otherwise, this mod would slowly fed up with user data from users, that log in once and never come back.
Not the case we want (since it is kind of a memory leak).
]]

lotto.user_time_before_delete = 90 -- count as days (90 days, about 3 months should be a nice value)

--[[
ToDo:
Add some kind of builtin informer, in case of missing chatplus
or eChat mod(s).
]]
if minetest.get_modpath( 'chatplus' ) then
	function lotto.inform_winner( name , amount )
		if chatplus.players[name] then
			table.insert( chatplus.players[name].messages , '[Lotto] Congratulations. You won the incredible amount of '..amount..'cr! Go to a Lotto Price machine to get your money!' )
			chatplus.save()
		else
			minetest.log( 'error', '[lotto] For some reason, the player '..name..' could not be found in the chatplus data.' )
		end
	end
elseif minetest.get_modpath( 'echat' ) then
	function lotto.inform_winner( name, amount )
		if eChat.players[name] then
			table.insert( eChat.players[name].messages, '[Lotto] Congratulations. You won the incredible amount of '..amount..'cr! Go to a Lotto Price machine to get your money!' )
			table.insert( eChat.players.update_list, name )
			eChat.save()
		else
			minetest.log( 'error' , '[lotto] For some reason, the player '..name..' could not be found in the eChat data.' )
		end
	end
else
	function lotto.inform_winner( name, amount )
		-- ToDO: Add a replacement function here
		minetest.chat_send_all( '[lotto] Congratulations '..name..', you won '..amount..'cr! Please go to a Price machine to get your money!' )
		return
	end
end

function lotto.init()
	if not casino.mod_data.lotto then
		-- something went wrong with the data, or its the first init, create new
		casino.mod_data.lotto = {}
		casino.mod_data.lotto.jackpot = 0
		casino.mod_data.lotto.session_id = lotto.generate_session_id()
		casino.mod_data.lotto.start_date = os.time()
		casino.mod_data.lotto.end_date = ( ( ( lotto.timespan * 24 ) * 60 ) * 60 ) + os.time()
		casino.mod_data.lotto.player_register = {}
		casino.mod_data.lotto.win_register = {}
		casino.save_data( )
		minetest.log( 'debug' , '[lotto] Has been initialized for the first time or after an error with non-existent data' )
		return
	end
	-- make a check if our timespan is over after initiliazing all other mods
	minetest.after( 15 , lotto.check_date )
	-- here goes the major cleanup of the player_register table
	local date = os.time()
	local index = 1
	for player_name, data_ref in pairs( casino.mod_data.lotto.player_register ) do
		if os.difftime( date , data_ref.last_login ) >= ( ( lotto.user_time_before_delete * 24 ) * 60 ) * 60 then
			table.remove( casino.mod_data.lotto.player_register, index )
			minetest.log( 'action', '[lotto] Player '..player_name..' has been deleted from active register' )
			casino.save_data()
		end
		index = index + 1
	end
	minetest.log( 'debug' , '[lotto] Has been initialized' )
end

function lotto.check_date( )
	local today = os.time()
	if today >= casino.mod_data.lotto.end_date then
		local win_number = lotto.choose_win_number()
		local temp_winners = {}
		for player_name, data_ref in pairs( casino.mod_data.lotto.player_register ) do
			if data_ref.session_id == casino.mod_data.lotto.session_id then
				for index, ticket_number in pairs( data_ref.tickets ) do
					if ticket_number == win_number then
						-- looks like we have a winner
						table.insert( temp_winners, player_name )
					end
				end
			end
		end
		if #temp_winners ~= 0 then
			-- we have at least one winner
			local jackpot_divided_by_winners = math.floor( casino.mod_data.lotto.jackpot / #temp_winners )
			for index, player_name in pairs( temp_winners ) do
				lotto.inform_winner( player_name, jackpot_divided_by_winners )
			end
			if #casino.mod_data.lotto.win_register == 3 then
				table.remove( casino.mod_data.lotto.win_register, 1 )
			end
			table.insert( casino.mod_data.lotto.win_register, { session_id = casino.mod_data.lotto.session_id, jackpot_pp = jackpot_divided_by_winners, remaining_pays = #temp_winners } )
			casino.mod_data.lotto.jackpot = 0
			casino.save_data()
		end
	end
end

function lotto.generate_session_id( )
	-- we make a simple number out of the date plus the timespan
	local today = os.date( '*t' )
	local current_time = os.time()
	local timespan_end = os.date( '*t' , current_time + ( ( ( lotto.timespan * 24 ) * 60 ) * 60 ) )
	local session_id = '0x'..today.year..''..
		today.day..''..today.month..''..
		timespan_end.day..''..timespan_end.month
	session_id = tonumber( session_id )
	if not session_id then
		-- fail part, will be deleted once considered useless
		minetest.log( 'error', '[lotto] Internal Error. Could not format session string into number' )
		return nil
	end
	print( 'Generated Current ID: '..session_id )
	return session_id
end

function lotto.choose_win_number( )
	-- returns a number within 1...lotto.max_number
	-- we generate 4 pseudo-random numbers and then choose
	-- with another pseudo-random number one of these values.
	-- this decreases the win chance also a bit.
	local first_level_numbers = {}
	local random_operands = { 256, 8, 1024, 32 }
	for index = 1, 4, 1 do
		math.randomseed( ( os.time() / 8192 ) * random_operands[index] )
		table.insert( first_level_numbers, math.random( 1, lotto.max_number ) )
	end
	return first_level_numbers[math.random(1,4)]
end

minetest.register_on_joinplayer( function( player_ref )
	-- To keep our register as clean as possible
	local player_name = player_ref:get_player_name()
	if casino.mod_data.lotto.player_register[player_name] then
		local date_data = os.time()
		casino.mod_data.lotto.player_register[player_name].last_login = date_data
	end
end )


-- Init everything!

dofile( minetest.get_modpath( 'casino' )..casino.sep..'lotto_machines.lua' )
lotto.init()

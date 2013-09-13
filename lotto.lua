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
]]

-- version: 70409

lotto = {}
lotto.settings = {}

-- price setting (in credits)

lotto.ticket_price = 200

lotto.settings.jackpot = 0 -- never touch this! except you want a base amount from nowhere

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
ToDo:
Add some kind of builtin informer, in case of missing chatplus
or eChat mod(s).
]]
if minetest.get_modpath( 'chatplus' ) then
	function lotto.inform_winner( name , amount )
		if chatplus.players[name] then
			table.insert( chatplus.players[name].messages , '[Lotto] Congratulations. You won the incredible amount of '..amount..'cr!' )
			chatplus.save()
		else
			minetest.log( 'error', '[lotto] For some reason, the player '..name..' could not be found in the chatplus data.' )
		end
	end
elseif minetest.get_modpath( 'echat' ) then
	function lotto.inform_winner( name, amount )
		if eChat.players[name] then
			table.insert( eChat.players[name].messages, '[Lotto] Congratulations. You won the incredible amount of '..amount..'cr!' )
			table.insert( eChat.players.update_list, name )
			eChat.save()
		else
			minetest.log( 'error' , '[lotto] For some reason, the player '..name..' could not be found in the eChat data.' )
		end
	end
end

-- system

function lotto.save_settings( )
	local settings_file = io.open( minetest.get_worldpath()..casino.sep..'lotto_settings', 'w' )
	if not settings_file then
		minetest.log( 'error', '[lotto] could not open file to save data.' )
		return
	end
	settings_file:write( minetest.serialize( lotto.settings ) )
	settings_file:close()
end

-- get the last saved session ID and player registrations

function lotto.get_settings( )
	local settings_file = io.open( minetest.get_worldpath()..casino.sep..'lotto_settings' , 'r' )
	if not settings_file then
		minetest.log( 'info' , '[lotto] Was not able to open settings file. Building new.' )
		lotto.settings = {}
		lotto.settings.player_register = {}
		lotto.settings.session_id = nil
		lotto.generate_session_id()
		lotto.settings.start_date = os.date('*t')
		lotto.settings.end_date = os.date('*t', os.time() + ( ( ( lotto.timespan * 24 ) * 60 ) * 60 ) )
		lotto.save_settings()
	else
		local temp_data = minetest.deserialize( settings_file:read('*all') )
		if type( temp_data ) ~= type( {} ) then
			minetest.log( 'debug' , '[lotto] After minetest.deserialize(), returned data is not fitting expected format.')
			lotto.settings = {}
			lotto.settings.player_register = {}
			lotto.settings.start_date = os.date('*t')
			lotto.settings.end_date = os.date('*t', os.time() + ( ( ( lotto.timespan * 24 ) * 60 ) * 60 ) )
			lotto.generate_session_id()
			lotto.save_settings()
		end
		lotto.settings = temp_data
	end
end

function lotto.init()
	lotto.get_settings()
	-- make a check if our timespan is over
	lotto.check_date()

end

function lotto.check_date( )
	local today = os.date('*t')
	if today.day >= lotto.end_date.day or ( today.day < lotto.end_date.day and today.month > lotto.end_date.month ) or
		( ( today.day < lotto.end_date.day and today.month < lotto.end_date.month ) and today.year > lotto.end_date.year ) then
		-- looks like time is over
		local win_number = lotto.choose_win_number()
		local temp_winners = {}
		for index, user in pairs( lotto.settings.player_register[lotto.settings.session_id] ) do
			if user[win_number] then
				table.insert( temp_winners, index )
			end
		end
		local amount_per_user = lotto



-- end of system

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
		-- fail safe part, will be deleted once considered useless
		minetest.log( 'error', '[lotto] Internal Error. Could not format session string into number' )
		return nil
	end
	lotto.settings.session_id = session_id
	lotto.save_settings()
	print( 'Generated Current ID: '..session_id )
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

-- our ticket machine

local formspec_buy_menu = "size[8,5]"..
	"label[1,0;Please insert a number you want for your ticket]"..
	"field[1,1;6,1;number_input;;]"..
	"button[1,2;6,1;proceed_button;Buy ticket ("..lotto.ticket_price.."cr)]"..
	"button_exit[1,3;6,1;cancel_button;Cancel"

local formspec_buy_error_menu = 'size[8,5]'..
	'label[1,0;Sorry but i need a number not something else]'..
	'field[1,1;6,1;number_input;;]'..
	'button[1,2;6,1;proceed_button;Buy ticket ('..lotto.ticket_price..'cr)]'..
	'button_exit[1,3;6,1;cancel_button;Cancel'


local machine_def = {
	drawtype = 'normal',
	tiles = {
		'default_chest_top.png',
		'default_chest_top.png',
		'default_chest_side.png',
		'default_chest_side.png',
		'default_chest_side.png',
		'default_chest_front.png' },
	paramtype2 = "facedir",
	on_punch = function( pos, node, puncher )
		local player_name = nil
		if type( puncher ) ~= type( '' ) then
			-- should be a reference
			player_name = puncher:get_player_name()
		else
			player_name = puncher
		end
		minetest.show_formspec( player_name, 'casino:ticket_machine', formspec_buy_menu )
	end
	}
minetest.register_node( 'casino:ticket_machine', machine_def )

minetest.register_on_player_receive_fields( function( player, formname, fields )
	local player_name = nil
	if type( player ) ~= type( '' ) then
		player_name = player:get_player_name()
	else
		player_name = player
	end
	-- better do a check at this point, to prevend buying a ticket with the old ID
	lotto.check_date()
	-- end
	local player_check_number = tonumber( fields.number_input )
	if not player_check_number and not fields.cancel_button then
		minetest.show_formspec( player_name, 'casino:ticket_machine', formspec_buy_error_menu )
	elseif player_check_number and not fields.cancel_button then
		local PlayerInv = player:get_inventory()
		local ticketStack = ItemStack( 'casino:lotto_ticket 1' )
		local itemRef = ticketStack:to_table()
		local tmp_meta = parse_item_meta( itemRef['metadata'] )
		tmp_meta['session_id'] = lotto.settings.session_id
		tmp_meta['user_number'] = player_check_number
		itemRef['metadata'] = save_item_meta( tmp_meta )
		ticketStack:replace( itemRef )
		if PlayerInv:room_for_item( 'main', ticketStack ) then
			PlayerInv:add_item( 'main', ticketStack )
			minetest.show_formspec( player_name, 'casino:ticket_machine', 'size[8,5]label[1,0;You just bought ticket no: '..player_check_number..']' )
		else
			minetest.show_formspec( player_name, 'casino:ticket_machine', 'size[8,5]label[1,0;You have no free inventory slot. Buy request canceled]' )
		end
	end
end )

-- the ticket item definition

minetest.register_tool("casino:lotto_ticket", {
	description = "Lotto ticket",
	visual_scale = 1.0,
	inventory_image = "casino_ticket.png",
	on_use = function( itemstack, user, pointed_thing )
		local itemRef = itemstack:to_table()
		local tmp_meta = parse_item_meta( itemRef['metadata'] )
		local session_id = tmp_meta['session_id']
		local user_number = tmp_meta['user_number']
		minetest.chat_send_player( user:get_player_name(), 'Ticket has ID '..user_number..' from session '..session_id )
		return nil
	end,
})


-- helper functions for meta access
--[[
Credits for this code goes to RealBadAngel and is copied
from his repo:
github.com/RealBadAngel/technic
]]

function parse_item_meta( StackRef )
	if string.find( StackRef, 'return {' ) then
		return minetest.deserialize( StackRef )
	else return {}
	end
end

function save_item_meta( MetaRef )
	return minetest.serialize( MetaRef )
end


-- Init everything!

lotto.get_settings()

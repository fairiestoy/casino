--[[
The lotto machine definitions, ticket definitions
go here. (seperated to keep the code more cleaner to read through)


v270601 (00042109)
]]

lotto.TMBuyForm = "size[8,5]"..
	"label[1,0;Please insert a number you want for your ticket]"..
	"field[1,1;6,1;number_input;;]"..
	"button[1,2;6,1;proceed_button;Buy ticket ("..lotto.ticket_price.."cr)]"..
	"button_exit[1,3;6,1;cancel_button;Cancel"

lotto.TMVErrorForm = 'size[8,5]'..
	'label[1,0;Sorry but i need a number not something else]'..
	'field[1,1;6,1;number_input;;]'..
	'button[1,2;6,1;proceed_button;Buy ticket ('..lotto.ticket_price..'cr)]'..
	'button_exit[1,3;6,1;cancel_button;Cancel'

lotto.TMOFErrorForm = 'size[8,5]'..
	'label[1,0;Too high value, number has to be between 1 - '..lotto.max_number..']'..
	'field[1,1;6,1;number_input;;]'..
	'button[1,2;6,1;proceed_button;Buy ticket ('..lotto.ticket_price..'cr)]'..
	'button_exit[1,3;6,1;cancel_button;Cancel'

lotto.TMMTErrorForm = 'size[8,5]label[1,0;You cannot buy anymore tickets (maximum is '..lotto.max_ticket_per_user..']'

lotto.TMFIErrorForm = 'size[8,5]label[1,0;You have no free inventory slot. Buy request canceled]'

lotto.TMSBForm = 'size[8,5]label[1,0;Thank you for using our service. Hope to see you soon again.]'


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
		minetest.show_formspec( player_name, 'casino:ticket_machine', lotto.TMBuyForm )
	end,
	}


function lotto.ticket_machine_routine( player, formname, fields )
	if formname ~= 'casino:ticket_machine' then
		return
	end
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
	if not player_check_number then
		minetest.show_formspec( player_name, 'casino:ticket_machine', lotto.TMVErrorForm )
	elseif player_check_number > lotto.max_number then
		minetest.show_formspec( player_name, 'casino:ticket_machine', lotto.TMOFErrorForm )
	elseif player_check_number then
		-- first, do a check if our player exists
		local player_reg = casino.mod_data.lotto.player_register[player_name]
		if not player_reg then
			casino.mod_data.lotto.player_register[player_name] = { last_login = os.time() }
			casino.save_data()
			player_reg = casino.mod_data.lotto.player_register[player_name]
		end
		local pos_index = 0
		local g_data = nil
		for index, data in pairs( player_reg ) do
			pos_index = pos_index + 1
			if type( data ) == type( {} ) then
				if data.session_id == casino.mod_data.lotto.session_id then
					g_data = data
					break
				end
			end
		end
		if not g_data then
			-- looks like we don't have a reference up to now
			table.insert( casino.mod_data.lotto.player_register[player_name], { session_id = casino.mod_data.lotto.session_id, tickets = {} } )
			player_reg = casino.mod_data.lotto.player_register[player_name]
			g_data = player_reg[#player_reg]
		end
		if #g_data.tickets == lotto.max_ticket_per_user + 1 then
			minetset.show_formspec( player_name, 'casino:ticket_machine', lotto.TMMTErrorForm )
			return
		end
		if #g_data == lotto.max_stored_sessions + 1 then
			-- no more stored sessions here
			local pos_index = 1
			for _, data in pairs( player_reg ) do
				if type( data ) == type( {} ) then
					-- delete first occurence of a table, but check that this is not the active one
					if data.session_id ~= casino.mod_data.lotto.session_id then
						table.remove( casino.mod_data.lotto.player_register[player_name], pos_index )
						casino.save_data()
						break
					end
				end
			end
		end


		local PlayerInv = player:get_inventory()
		if not PlayerInv:room_for_item( 'main', ticketStack ) then
			minetest.show_formspec( player_name, 'casino:ticket_machine', lotto.TMFIErrorForm )
			return
		end

		local ticketStack = ItemStack( 'casino:lotto_ticket 1' )
		local itemRef = ticketStack:to_table()
		local tmp_meta = parse_item_meta( itemRef['metadata'] )
		tmp_meta['session_id'] = casino.mod_data.lotto.session_id
		tmp_meta['user_number'] = player_check_number
		itemRef['metadata'] = save_item_meta( tmp_meta )
		ticketStack:replace( itemRef )
		-- make sure to save this ticket
		table.insert( casino.mod_data.lotto.player_register[player_name][#casino.mod_data.lotto.player_register[player_name]].tickets, player_check_number )
		casino.save_data()
		PlayerInv:add_item( 'main', ticketStack )
		casino.charge_user( player_name, lotto.ticket_price )
		minetest.show_formspec( player_name, 'casino:ticket_machine', lotto.TMSBForm )
	end
end

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

minetest.register_node( 'casino:ticket_machine', machine_def )

minetest.register_on_player_receive_fields( lotto.ticket_machine_routine )

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

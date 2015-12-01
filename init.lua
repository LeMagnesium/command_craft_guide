--[[
	=-[ Command Craft Guide ]-=-=-=-=-=-=-=-=-=-=-=
	|  License : see LICENSE                      |
	=  A mod for minetest : https://minetest.net  =
	|  Last modification : 11/29/15 ßÿ Mg         |
	=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
--]]

cc_guide = {}
cc_guide.contexts = {}
cc_guide.icons = {
	["normal"] = "command_craft_guide_normal.png",
	["shapeless"] = "command_craft_guide_normal.png",
	["cooking"] = "default_furnace_front.png",
	["fuel"] = "default_furnace_front.png",
}
cc_guide.groups = {}

function cc_guide.do_work(name)
	local recipes = cc_guide.contexts[name]["data"]
	local index = cc_guide.contexts[name]["recp"]
	local width = recipes[index].width
	if width == 0 then
		width = 3
		recipes[index].type = "shapeless"
	end

	minetest.log("action", "[CC_Guide] Form update for player " .. name .. " at index " .. index)

	local answer = "size[4,4]" ..
		"list[detached:cc_output_" .. name .. ";output;0,0;3,3;]" ..
		"button_exit[2.5,3.5;1.5,1;quit_search;Close]" ..
		"image[3,1;1,1;" .. cc_guide.icons[recipes[index].type] .. "]"

	cc_guide.contexts[name]["inv"]:set_list("output", {[1] = "", [9] = ""})
	for i, stack in pairs(recipes[index].items) do
		local newind = i + (math.floor((i-1)/width) * (3 - width))
		if stack:split(":")[1] ~= "group" then
			cc_guide.contexts[name]["inv"]:set_stack("output", newind, ItemStack(stack))
		else
			cc_guide.contexts[name]["inv"]:set_stack("output", newind, ItemStack(cc_guide.groups[stack:split(":")[2]]))
		end
	end

	if table.getn(recipes) > 1 then
		if index < table.getn(recipes) then
			answer = answer .. "button[3,2;1,1;cc_next;>>]"
		end
		if index > 1 then
			answer = answer .. "button[3,0;1,1;cc_prev;<<]"
		end
		answer = answer .. "label[0,3.6;Recipe " .. index .. "/" .. table.getn(recipes) .. "]"
	end

	cc_guide.contexts[name]["formspec"] = answer
end
	

minetest.register_chatcommand("craft_help", {
	privs = {interact = true, shout = true},
	params = "<itemstring>",
	func = function(name, param)
		if not minetest.get_player_by_name(name) then
			return false, "You need to be online to be shown formspecs"
		end
		if param == "" then
			return false, "Give an itemstring to look for (use /craft_search <name> to search the itemstring of an item)"
		end

		if not minetest.registered_items[param] then
			return false, "Unknown item : " .. param
		end

		local recipes = minetest.get_all_craft_recipes(param)
		if not recipes then
			return false, "No recipe for item " .. param
		end

		if cc_guide.contexts[name] then
			minetest.get_player_by_name(name):set_inventory_formspec(cc_guide.contexts[name]["oldformspec"])
		end

		cc_guide.contexts[name] = {
			["itemstring"] = param,
			["data"] = recipes,
			["recp"] = 1,
			["oldformspec"] = minetest.get_player_by_name(name):get_inventory_formspec(),
			["inv"] = minetest.create_detached_inventory("cc_output_" .. name, {
				allow_move = function()
					return 0
				end,
				allow_take = function()
					return 0
				end,
				allow_put = function()
					return 0
				end,
			}),
		}
		cc_guide.contexts[name]["inv"]:set_size("output", 3*3)

		cc_guide.do_work(name)
		minetest.get_player_by_name(name):set_inventory_formspec(cc_guide.contexts[name]["formspec"])

		return true, table.getn(recipes) .. " recipes found for item " .. param ..
			"\nOpen your inventory to see the results"
	end,
})

minetest.register_chatcommand("craft_search", {
	privs = {shout = true},
	params = "<description>",
	func = function(name, param)
		if param == "" then
			minetest.chat_send_player("Warning: searching without any parameter will return every registered item on the server")
		end

		local answer = "size[10,10]" ..
			"label[0,0;The following itemstring matched :]" ..
			"table[0,0.5;9.7,8.7;search_results;"

		local found = 0
		for itemstring, def in pairs(minetest.registered_items) do
			if def.description and def.description ~= "" and (def.description:lower():find(param:lower()) or
				itemstring:find(param:lower())) then
				answer = answer .. itemstring .. " (" ..def.description .. "),"
				found = found + 1
			end
		end

		answer = answer .. "\b;]" ..
			"button_exit[8.5,9.5;1.5,1;quit_search;Close]"

		minetest.show_formspec(name, "cc_g:search_results", answer)
		return true, found .. " recipes found for item " .. param
	end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()
	if formname ~= "" or not cc_guide.contexts[name] then
		return
	end

	if fields.quit then
		player:set_inventory_formspec(cc_guide.contexts[name]["oldformspec"])
		cc_guide.contexts[name] = nil
		minetest.log("action", "[CC_Guide] Player " .. name .. " closed their help window")
		return
	elseif fields.cc_next then
		cc_guide.contexts[name]["recp"] = cc_guide.contexts[name]["recp"] + 1
	elseif fields.cc_prev then
		cc_guide.contexts[name]["recp"] = cc_guide.contexts[name]["recp"] - 1
	end
	cc_guide.do_work(name)
	player:set_inventory_formspec(cc_guide.contexts[name]["formspec"])
end)

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	if cc_guide.contexts[player_name] then
		player:set_inventory_formspec(cc_guide.contexts[player_name]["oldformspec"])
		cc_guide.contexts[player_name] = nil
	end
end)

minetest.after(0, function() -- Retrieve all groups
	for item, def in pairs(minetest.registered_items) do
		for group in pairs(def.groups) do
			if not cc_guide.groups[group] then
				cc_guide.groups[group] = item
			end
		end
	end
end)

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
	["nil"] = "command_craft_guide_nil.png",
}

function cc_guide.investigate_groups(tab)
	if table.getn(tab) == 0 then
		return {}
	end
	local tmp = {}
	for _, group in pairs(tab) do
		tmp[group] = {}
	end

	for item, def in pairs(minetest.registered_items) do
		if def.description and def.description ~= "" then
			for group, tab in pairs(tmp) do
				if def.groups[group] then
					table.insert(tab, item)
				end
			end
		end
	end

	local tab_min = nil
	for group, tab in pairs(tmp) do
		if (not tab_min) or (table.getn(tab) < table.getn(tab_min)) then
			tab_min = tab
		end
	end

	local returned_results = {}
	for _, item in pairs(tab_min) do
		local found = true
		for group, tab in pairs(tmp) do
			local inside = false
			for _, entry in pairs(tab) do
				if entry == item then
					inside = true
					break
				end
			end
			if not inside then
				found = false
				break
			end
		end
		if found then
			table.insert(returned_results, item)
		end
	end

	return returned_results
end

function cc_guide.get_context(name)
	if not cc_guide.contexts[name] then
		return nil
	end
	return cc_guide.contexts[name][cc_guide.contexts[name]["data"]["depth"]]
end

function cc_guide.clean_context(name)
	if not cc_guide.contexts[name] then
		return nil
	end
	minetest.get_player_by_name(name):set_inventory_formspec(cc_guide.contexts[name]["data"]["primaryformspec"])
	cc_guide.contexts[name] = nil
	minetest.log("action", "[CC_Guide] Player " .. name .. " closed their windows")
end

function cc_guide.create_context(name, mode)
	if cc_guide.contexts[name] then
		cc_guide.clean_context(name)
	end

	cc_guide.contexts[name] = {
		["data"] = {
			["primaryformspec"] = minetest.get_player_by_name(name):get_inventory_formspec(),
			["depth"] = 1,
		},
		[1] = {
			["mode"] = mode,
		},
	}
	return cc_guide.contexts[name][1]
end

function cc_guide.get_data(name)
	if not cc_guide.contexts[name] then
		return nil
	else
		return cc_guide.contexts[name]["data"]
	end
end

function cc_guide.go_deeper(name, mode)
	if not cc_guide.contexts[name] then
		return nil
	end
	cc_guide.contexts[name]["data"]["depth"] = cc_guide.contexts[name]["data"]["depth"] + 1
	cc_guide.contexts[name][cc_guide.contexts[name]["data"]["depth"]] = {
		["mode"] = mode,
	}
	return cc_guide.contexts[name][cc_guide.contexts[name]["data"]["depth"]]
end

function cc_guide.go_upper(name)
	if not cc_guide.contexts[name] then
		return nil
	end
	cc_guide.contexts[name][cc_guide.contexts[name]["data"]["depth"]] = nil
	cc_guide.contexts[name]["data"]["depth"] = cc_guide.contexts[name]["data"]["depth"] - 1
	minetest.get_player_by_name(name):set_inventory_formspec(cc_guide.contexts[name][cc_guide.contexts[name]["data"]["depth"]]["formspec"])
	return cc_guide.get_context()
end


-- Will change the formspec depending on what event/mode are in the context
function cc_guide.do_work(name)
	local context = cc_guide.get_context(name)
	local data = cc_guide.get_data(name)
	if not context or not data then return end

	-- The "show" mode shows the craft recipes available for an item
	if context["mode"] == "show" then
		local answer = "size[4,4.5]" ..
			"button_exit[2.5,3.75;1.5,1;quit_search;Close]"
		if data["depth"] > 1 then
			answer = answer .. "button[2.5,3;1.5,1;go_back;Back]"
		end

		local recipes = minetest.get_all_craft_recipes(context["itemstring"])
		if recipes then
			local index = context["recp"]
			local width = recipes[index].width
			if width == 0 then
				width = 3
				recipes[index].type = "shapeless"
			end

			answer = answer .. "image[3,1;1,1;" .. cc_guide.icons[recipes[index].type] .. "]"
			for row = 1, 3 do
				for column = 1, 3 do
					if column <= width then
						local desc = ""
						local stack = ""
						local ind = column + ((row - 1) * width)
						if recipes[index].items[ind] then
							local s = recipes[index].items[ind]
							if s:split(":")[1] ~= "group" then
								stack = s
							else
								stack = cc_guide.investigate_groups(s:split(":")[2]:split(","))[1]
								desc = "G."
							end
						end
						answer = answer .. string.format("item_image_button[%d,%d;1,1;%s;cc_g_%d_%d_%s;%s]", column - 1, row - 1, stack, row, column, stack, desc)
					end
				end
			end

			if table.getn(recipes) > 1 then
				if index < table.getn(recipes) then
					answer = answer .. "button[3,2;1,1;cc_next;>>]"
				end
				if index > 1 then
					answer = answer .. "button[3,0;1,1;cc_prev;<<]"
				end
				answer = answer .. "label[0,3.5;Recipe " .. index .. "/" .. table.getn(recipes) .. "]"
			end
		else
			answer = answer .. "image[3,1;1,1;" .. cc_guide.icons["nil"] .. "]"
		end
		context["formspec"] = answer
		minetest.log("action", "[CC_Guide] Form 'show' updated for player " .. name .. " at depth " .. data["depth"])

	-- The "list" mode is a list of results from an item querry
	elseif context["mode"] == "list" then
		local list = context["list"]
		local answer = "size[10,10]" ..
			"label[0,0;The following itemstring(s) matched :]" ..
			"textlist[0,0.5;9.7,8.7;search_results;"

		for i, item in pairs(list) do
			if i > 1 then
				answer = answer .. ","
			end
			answer = answer .. item
		end

		answer = answer .. ";" .. context["selected_item"] .. ";]" ..
			"button_exit[8.5,9.5;1.5,1;quit_search;Close]"
		context["formspec"] = answer
	else
		error("No cc_guide mode " .. dump(context["mode"]))
	end
	minetest.get_player_by_name(name):set_inventory_formspec(cc_guide.get_context(name)["formspec"])
end


-- Chatcommands to trigger the modes
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

		local context = cc_guide.create_context(name, "show")
		context["itemstring"] = param
		context["recp"] = 1

		cc_guide.do_work(name)

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

		if cc_guide.contexts[name] then
			minetest.get_player_by_name(name):set_inventory_formspec(cc_guide.contexts[name]["primaryformspec"])
		end

		local context = cc_guide.create_context(name, "list")
		local found = 0
		local items = {}
		for itemstring, def in pairs(minetest.registered_items) do
			if def.description and def.description ~= "" and (def.description:lower():find(param:lower()) or
				itemstring:find(param:lower())) then
				table.insert(items, string.format("%s (%s)", itemstring, def.description))
				found = found + 1
			end
		end
		context["query"] = param
		context["size"] = found
		context["list"] = items
		context["selected_item"] = 1
		cc_guide.do_work(name)

		return true, found .. " recipes found for item " .. param
			.. "\nOpen your inventory to see the results"
	end
})


-- Event handling using on_player_receive_fields
minetest.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()
	if formname ~= "" or not cc_guide.contexts[name] then
		return
	end

	local context = cc_guide.get_context(name)
	local data = cc_guide.get_data(name)

	if fields.quit then
		cc_guide.clean_context(name)
		return

	elseif fields.go_back then
		local context = cc_guide.go_upper(name)
		if cc_guide.get_data(name)["depth"] <= 0 then
			cc_guide.clean_context(name)
		end

	elseif fields.cc_next then
		context["recp"] = context["recp"] + 1
	elseif fields.cc_prev then
		context["recp"] = context["recp"] - 1
	end

	if context["mode"] == "show" then
		for key, val in pairs(fields) do
			if key:split("_")[5] and minetest.registered_items[key:split("_")[5]] then
				local context = cc_guide.go_deeper(name, "show")
				context["itemstring"] = key:split("_")[5]
				context["recp"] = 1
				break
			end
		end
	elseif context["mode"] == "list" then
		local event = minetest.explode_textlist_event(fields.search_results)
		if event.type == "DCL" then
			local elem = context["list"][event.index]:split(" ")[1]
			context["selected_item"] = event.index

			local context = cc_guide.go_deeper(name, "show")
			context["itemstring"] = elem
			context["recp"] = 1
		end
	end

	cc_guide.do_work(name)
end)

-- Clean when leaving
minetest.register_on_leaveplayer(function(player)
	cc_guide.clean_context(player:get_player_name())
end)


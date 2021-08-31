---@class FreeMarket : module
local M = {}


--#region Constants
local match = string.match
local call = remote.call
local anchor = {gui = defines.relative_gui_type.controller_gui, position = defines.relative_gui_position.top}
--#endregion


--#region Settings
local update_tick = settings.global["MUI_update-tick"].value
--#endregion


--#region utils

local function create_relative_gui(player)
	local relative = player.gui.relative
	local main_frame = relative.add{type = "frame", name = "money_frame", anchor = anchor}
	main_frame.style.vertical_align = "center"
	main_frame.style.horizontally_stretchable = false
	main_frame.style.bottom_margin = -14
	local frame = main_frame.add{type = "frame", name = "content", style = "inside_shallow_frame"}
	frame.style.right_padding = 6
	local button = frame.add{type = "sprite-button", name = "MUI_money", sprite = "item/coin", style = "slot_button_in_shallow_frame"}
	button.style.size = 48
	local main_table = frame.add{type = "table", name = "table", column_count = 2}
	main_table.style.vertical_spacing = 0
	main_table.add{type = "label", style = "money_title", caption = {'', {"money-UI.player-balance"}, {"colon"}, " "}}
	main_table.add{type = "label", name = "player_balance", style = "money_label"}
	main_table.add{type = "label", style = "money_title", caption = {'', {"money-UI.team-balance"}, {"colon"}, " "}}
	main_table.add{type = "label", name = "force_balance", style = "money_label"}
end

--#endregion


--#region Functions of events

local function on_player_created(event)
	create_relative_gui(game.get_player(event.player_index))
end

local GUIS = {
	MUI_money = function(element, player)
		player.print("WIP")
	end
}
local function on_gui_click(event)
	local player = game.get_player(event.player_index)
	local element = event.element
	if not match(element.name, "^MUI_") then return end

	local f = GUIS[element.name]
	if f then f(element, player) end
end

local function check_GUIs()
	local forces_money = call("EasyAPI", "get_forces_money")
	local players_money = call("EasyAPI", "get_players_money")
	for _, force in pairs(game.forces) do
		local force_money = tostring(forces_money[force.index] or "NaN")
		for _, player in pairs(force.connected_players) do
			if player.opened_self then
				local table = player.gui.relative.money_frame.content.table
				table.player_balance.caption = tostring(players_money[player.index] or "NaN")
				table.force_balance.caption = force_money
			end
		end
	end
end

local mod_settings = {
	["MUI_update-tick"] = function(value)
		script.on_nth_tick(update_tick, nil)
		update_tick = value
		script.on_nth_tick(value, check_GUIs)
	end
}
local function on_runtime_mod_setting_changed(event)
	if event.setting_type ~= "runtime-global" then return end
	if not match(event.setting, "^MUI_") then return end

	local f = mod_settings[event.setting]
	if f then f(settings.global[event.setting].value) end
end

--#endregion


--#region Pre-game stage

local function add_remote_interface()
	-- https://lua-api.factorio.com/latest/LuaRemote.html
	remote.remove_interface("money-UI") -- For safety
	remote.add_interface("money-UI", {})
end

M.on_init = function()
	for _, player in pairs(game.players) do
		if player.valid then
			create_relative_gui(player)
		end
	end
end
M.add_remote_interface = add_remote_interface

--#endregion


M.events = {
	[defines.events.on_player_created] = on_player_created,
	[defines.events.on_gui_click] = function(event)
		pcall(on_gui_click, event)
	end,
	[defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed
}

M.on_nth_tick = {
	[update_tick] = check_GUIs
}

return M

---@class FreeMarket : module
local M = {}


--#region Global data
---@class mod_data
local mod_data

--- {[player index] = {GuiElement, GuiElement, force index}}
---@class opened_money_UI
---@type table<integer, table>
---@field [1] GuiElement #player_balance
---@field [2] GuiElement #force_balance
---@field [3] integer #Force index
local opened_money_UI
--#endregion


--#region Constants
local tostring = tostring
local call = remote.call
local money_anchor = {gui = defines.relative_gui_type.controller_gui, position = defines.relative_gui_position.top}
local controller_type = defines.gui_type.controller
--#endregion


--#region Settings
local update_tick = settings.global["MUI_update-tick"].value
local show_player_money = settings.global["MUI_show_player_money"].value
--#endregion


--#region utils

local function create_relative_gui(player)
	local relative = player.gui.relative
	local main_frame = relative.add{type = "frame", name = "money_frame", anchor = money_anchor}
	main_frame.style.vertical_align = "center"
	main_frame.style.horizontally_stretchable = false
	main_frame.style.bottom_margin = -14
	local frame = main_frame.add{type = "frame", name = "content", style = "inside_shallow_frame"}
	frame.style.right_padding = 6
	local button = frame.add{type = "sprite-button", name = "MUI_money", sprite = "item/coin", style = "slot_button_in_shallow_frame"}
	button.style.size = 48
	local main_table = frame.add{type = "table", name = "table", column_count = 2}
	main_table.style.vertical_spacing = 0
	main_table.add{type = "label", name = "player_money_label", style = "money_title", caption = {'', {"money-UI.player-balance"}, {"colon"}, " "}}.visible = show_player_money
	main_table.add{type = "label", name = "player_balance", style = "money_label"}.visible = show_player_money
	main_table.add{type = "label", name = "force_money_label", style = "money_title", caption = {'', {"money-UI.team-balance"}, {"colon"}, " "}}
	main_table.add{type = "label", name = "force_balance", style = "money_label"}
end

--#endregion


--#region Functions of events

local function on_player_created(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end
	create_relative_gui(player)
end

local function on_player_changed_force(event)
	local player_index = event.player_index
	local player_data = opened_money_UI[player_index]
	if player_data == nil then return end
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	player_data[3] = player.force.index
end

local function on_gui_opened(event)
	if event.gui_type ~= controller_type then return end
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end
	if not player.opened_self then return end

	-- TODO: improve (update GUI)
	local gui = player.gui.relative.money_frame.content.table
	opened_money_UI[player_index] = {
		gui.player_balance,
		gui.force_balance,
		player.force.index
	}
end

local function on_gui_closed(event)
	if event.gui_type ~= controller_type then return end
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end
	if player.opened_self then return end
	opened_money_UI[player_index] = nil
end

local function on_gui_click(event)
	local element = event.element
	if not (element and element.valid) then return end
	if element.name ~= "MUI_money" then return end

	local table_elem = element.parent.table
	local player_index = event.player_index
	local player_money = call("EasyAPI", "get_online_player_money", player_index)
	if player_money then
		table_elem.player_balance.caption = tostring(player_money)
	else
		table_elem.player_balance.caption = "NaN"
	end
	local player = game.get_player(player_index)
	local force_money = call("EasyAPI", "get_force_money", player.force.index)
	if force_money then
		table_elem.force_balance.caption = tostring(force_money)
	else
		table_elem.force_balance.caption = "NaN"
	end
end

local function check_GUIs()
	if next(opened_money_UI) == nil then return end

	local forces_money = call("EasyAPI", "get_forces_money")
	local players_money = call("EasyAPI", "get_online_players_money")
	for player_index, data in pairs(opened_money_UI) do
		data[1].caption = tostring(players_money[player_index] or "NaN")
		data[2].caption = tostring(forces_money[data[3]] or "NaN") -- TODO: optimize
	end
end

local function short_check_GUIs()
	if next(opened_money_UI) == nil then return end

	local forces_money = call("EasyAPI", "get_forces_money")
	for _, data in pairs(opened_money_UI) do
		data[2].caption = tostring(forces_money[data[3]] or "NaN") -- TODO: optimize
	end
end

local mod_settings = {
	["MUI_show_player_money"] = function(value)
		show_player_money = value
		local f = (value and check_GUIs) or short_check_GUIs
		script.on_nth_tick(update_tick, f)
		for _, player in pairs(game.players) do
			if player.valid then
				local elem = player.gui.relative.money_frame.content.table
				elem.player_money_label.visible = value
				elem.player_balance.visible = value
			end
		end
	end,
	["MUI_update-tick"] = function(value)
		script.on_nth_tick(update_tick, nil)
		M.on_nth_tick[update_tick] = nil
		update_tick = value
		local f = (show_player_money and check_GUIs) or short_check_GUIs
		script.on_nth_tick(value, f)
		M.on_nth_tick[update_tick] = f
	end
}
local function on_runtime_mod_setting_changed(event)
	local setting_name = event.setting
	local f = mod_settings[setting_name]
	if f == nil then return end
	f(settings.global[setting_name].value)
end

--#endregion


--#region Pre-game stage

local function link_data()
	mod_data = global.MUI
	if mod_data then
		opened_money_UI = mod_data.opened_money_UI
	end
end

local function update_global_data()
	global.MUI = global.MUI or {}
	mod_data = global.MUI
	mod_data.opened_money_UI = {}

	link_data()
end

local function add_remote_interface()
	-- https://lua-api.factorio.com/latest/LuaRemote.html
	remote.remove_interface("money-UI") -- For safety
	remote.add_interface("money-UI", {})
end

M.on_init = function()
	update_global_data()

	for _, player in pairs(game.players) do
		if player.valid then
			create_relative_gui(player)
		end
	end
end
M.on_configuration_changed = function(event)
	update_global_data()

	local mod_changes = event.mod_changes["money-UI"]
	if not (mod_changes and mod_changes.old_version) then return end

	local old_version = tonumber(string.gmatch(mod_changes.old_version, "%d+.%d+")())

	if old_version < 0.9 then
		for _, player in pairs(game.players) do
			if player.valid then
				local money_frame = player.gui.relative.money_frame
				if money_frame and money_frame.valid then
					money_frame.destroy()
				end
				create_relative_gui(player)
			end
		end
	end
end
M.on_load = link_data
M.add_remote_interface = add_remote_interface

--#endregion


M.events = {
	[defines.events.on_player_created] = on_player_created,
	[defines.events.on_player_changed_force] = on_player_changed_force,
	[defines.events.on_player_removed] = function(event)
		opened_money_UI[event.player_index] = nil
	end,
	[defines.events.on_player_left_game] = function(event)
		opened_money_UI[event.player_index] = nil
	end,
	[defines.events.on_player_joined_game] = function()
		if #game.connected_players == 1 then
			mod_data.opened_money_UI = {}
			opened_money_UI = mod_data.opened_money_UI
		end
	end,
	[defines.events.on_gui_opened] = on_gui_opened,
	[defines.events.on_gui_closed] = on_gui_closed,
	[defines.events.on_gui_click] = on_gui_click,
	[defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed
}

M.on_nth_tick = {
	[update_tick] = (show_player_money and check_GUIs) or short_check_GUIs
}

return M

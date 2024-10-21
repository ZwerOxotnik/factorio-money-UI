---@class MUI : module
local M = {
	on_nth_tick = {}
}


--#region Global data
---@class mod_data
local mod_data

--- {{GuiElement, GuiElement, force index, player index}}
---@class opened_money_UI
---@type table[]
---@field [1] GuiElement #force_balance
---@field [2] integer #Force index
---@field [3] GuiElement #player_balance
---@field [4] integer #Player index
local opened_money_UI

---@class opened_money_UI_refs
---@type table<integer, table>
local opened_money_UI_refs
--#endregion


--#region Constants
local handle_tick_events
local money_anchor = {gui = defines.relative_gui_type.controller_gui, position = defines.relative_gui_position.top}
local controller_type = defines.gui_type.controller
local tremove = table.remove
local call = remote.call
local setmetatable = setmetatable
local tostring = tostring
local int_to_string_mt = {
	__index = function(self, k)
		v = tostring(k)
		self[k] = v
		return v
	end
}
local int_to_string_data = setmetatable({}, int_to_string_mt)
--#endregion


--#region Settings
local update_tick = settings.global["MUI_update-tick"].value
local is_player_money_visible = settings.global["MUI_show_player_money"].value
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
	main_table.add{type = "label", name = "player_money_label", style = "money_title", caption = {'', {"money-UI.player-balance"}, {"colon"}, " "}}.visible = is_player_money_visible
	main_table.add{type = "label", name = "player_balance", style = "money_label"}.visible = is_player_money_visible
	main_table.add{type = "label", name = "force_money_label", style = "money_title", caption = {'', {"money-UI.team-balance"}, {"colon"}, " "}}
	main_table.add{type = "label", name = "force_balance", style = "money_label"}
end

--#endregion


--#region Functions of events

function remove_player_data_event(event)
	local player_index = event.player_index
	local data = opened_money_UI_refs[player_index]
	if data == nil then return end
	opened_money_UI_refs[event.player_index] = nil
	for i=#opened_money_UI, 1, -1 do
		if opened_money_UI[i] == data then
			tremove(opened_money_UI, i)
			handle_tick_events()
			return
		end
	end
end

local function on_player_created(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end
	create_relative_gui(player)
end

local function on_player_changed_force(event)
	local player_index = event.player_index
	local player_data = opened_money_UI_refs[player_index]
	if player_data == nil then return end
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	player_data[2] = player.force.index
end

local function on_gui_opened(event)
	if event.gui_type ~= controller_type then return end
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end
	if not player.opened_self then return end

	-- TODO: improve (update GUI)
	local gui = player.gui.relative.money_frame.content.table
	local data = {
		gui.force_balance,
		player.force.index,
		gui.player_balance,
		player_index
	}
	opened_money_UI[#opened_money_UI+1] = data
	opened_money_UI_refs[player_index] = data
	if #opened_money_UI == 1 then
		handle_tick_events()
	end
end

local function on_gui_closed(event)
	if event.gui_type ~= controller_type then return end
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end
	if player.opened_self then return end

	local data = opened_money_UI_refs[player_index]
	opened_money_UI_refs[player_index] = nil
	for i=#opened_money_UI, 1, -1 do
		if opened_money_UI[i] == data then
			tremove(opened_money_UI, i)
			if #opened_money_UI == 0 then
				handle_tick_events()
			end
			return
		end
	end
end

local function on_gui_click(event)
	local element = event.element
	if not (element and element.valid) then return end
	if element.name ~= "MUI_money" then return end

	local table_elem = element.parent.table
	local player_index = event.player_index
	local player_money = call("EasyAPI", "get_online_player_money", player_index)
	local elem = table_elem.player_balance
	elem.caption = (player_money and tostring(player_money)) or "NaN"
	local player = game.get_player(player_index)
	local force_money = call("EasyAPI", "get_force_money", player.force.index)
	elem = table_elem.force_balance
	elem.caption = (force_money and tostring(force_money)) or "NaN"
end

local function check_GUIs()
	local forces_money = call("EasyAPI", "get_forces_money")
	local players_money = call("EasyAPI", "get_online_players_money")
	for i=1, #opened_money_UI do
		local data = opened_money_UI[i]
		local money = forces_money[data[2]]
		data[1].caption = (money and int_to_string_data[money]) or "NaN"
		money = players_money[data[4]]
		data[3].caption = (money and int_to_string_data[money]) or "NaN"
	end
end

local function short_check_GUIs()
	local forces_money = call("EasyAPI", "get_forces_money")
	for i=1, #opened_money_UI do
		local data = opened_money_UI[i]
		local money = forces_money[data[2]]
		data[1].caption = (money and int_to_string_data[money]) or "NaN"
	end
end

local function reset_temp_data()
	int_to_string_data = setmetatable({}, int_to_string_mt)
end

handle_tick_events = function()
	if #opened_money_UI == 0 then
		script.on_nth_tick(update_tick * 30, nil)
		script.on_nth_tick(update_tick, nil)
		M.on_nth_tick[update_tick * 30] = nil
		M.on_nth_tick[update_tick] = nil
		return
	end
	script.on_nth_tick(update_tick * 30, reset_temp_data)
	M.on_nth_tick[update_tick * 30] = reset_temp_data
	local f = (is_player_money_visible and check_GUIs) or short_check_GUIs
	script.on_nth_tick(update_tick, f)
	M.on_nth_tick[update_tick] = f
end

local mod_settings = {
	["MUI_show_player_money"] = function(value)
		is_player_money_visible = value
		handle_tick_events()
		for _, player in pairs(game.players) do
			if player.valid then
				local elem = player.gui.relative.money_frame.content.table
				elem.player_money_label.visible = value
				elem.player_balance.visible = value
			end
		end
	end,
	["MUI_update-tick"] = function(value)
		script.on_nth_tick(update_tick * 30, nil)
		M.on_nth_tick[update_tick * 30] = nil
		script.on_nth_tick(update_tick, nil)
		M.on_nth_tick[update_tick] = nil
		update_tick = value
		handle_tick_events()
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
	mod_data = storage.MUI
	if mod_data == nil then return end
	opened_money_UI = mod_data.opened_money_UI
	opened_money_UI_refs = mod_data.opened_money_UI_refs
end

local function update_global_data()
	storage.MUI = storage.MUI or {}
	mod_data = storage.MUI
	mod_data.opened_money_UI = {}
	mod_data.opened_money_UI_refs = {}

	link_data()
end

local function add_remote_interface()
	-- https://lua-api.factorio.com/latest/LuaRemote.html
	remote.remove_interface("money-UI") -- For safety
	remote.add_interface("money-UI", {})
end

M.on_init = function()
	update_global_data()
	handle_tick_events()

	for _, player in pairs(game.players) do
		if player.valid then
			create_relative_gui(player)
		end
	end
end
M.on_configuration_changed = function(event)
	update_global_data()
	handle_tick_events()

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
M.on_load = function()
	link_data()
	handle_tick_events()
end
M.add_remote_interface = add_remote_interface

--#endregion


M.events = {
	[defines.events.on_player_created] = on_player_created,
	[defines.events.on_player_changed_force] = on_player_changed_force,
	[defines.events.on_player_removed] = remove_player_data_event,
	[defines.events.on_player_left_game] = remove_player_data_event,
	[defines.events.on_player_joined_game] = function()
		if #game.connected_players ~= 1 then return end
		mod_data.opened_money_UI = {}
		mod_data.opened_money_UI_refs = {}
		opened_money_UI = mod_data.opened_money_UI
		opened_money_UI_refs = mod_data.opened_money_UI_refs
	end,
	[defines.events.on_gui_opened] = on_gui_opened,
	[defines.events.on_gui_closed] = on_gui_closed,
	[defines.events.on_gui_click] = on_gui_click,
	[defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed
}

return M

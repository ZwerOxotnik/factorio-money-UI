data:extend({
	{
		type = "int-setting", name = "MUI_update-tick",
		setting_type = "runtime-global", localised_name = {"mod-setting-name.update-tick"},
		default_value = 30, minimum_value = 1, maximum_value = 60 * 60 * 2
	},
	{
		type = "bool-setting", name = "MUI_show_player_money",
		setting_type = "runtime-global", default_value = true
	}
})

return {
	"glepnir/dashboard-nvim",
	event = "VimEnter",
	dependencies = { { "nvim-tree/nvim-web-devicons" } },
	config = function()
		local function default_header()
			return {
				"",
				"",
				"",
				"",
				"███╗░░░███╗██████╗░░░░░██████╗░█████╗░██████╗░██████╗░████████╗",
				"████╗░████║██╔══██╗░░░██╔════╝██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝",
				"██╔████╔██║██████╔╝░░░╚█████╗░██║░░╚═╝██████╔╝██████╔╝░░░██║░░░",
				"██║╚██╔╝██║██╔══██╗░░░░╚═══██╗██║░░██╗██╔══██╗██╔═══╝░░░░██║░░░",
				"██║░╚═╝░██║██║░░██║██╗██████╔╝╚█████╔╝██║░░██║██║░░░░░░░░██║░░░",
				"╚═╝░░░░░╚═╝╚═╝░░╚═╝╚═╝╚═════╝░░╚════╝░╚═╝░░╚═╝╚═╝░░░░░░░░╚═╝░░░",
				"",
				"",
			}
		end

		require("dashboard").setup({
			theme = "doom",
			config = {
				header = default_header(),
				center = {
					{
						icon = "󰙅 ",
						icon_hl = "Title",
						desc = "[R]estore session",
						desc_hl = "String",
						key = "r",
						keymap = "SPC r",
						key_hl = "Number",
						action = ":SessionRestore",
					},
					{
						icon = "󰙅 ",
						icon_hl = "Title",
						desc = "Open [E]xplorer",
						desc_hl = "String",
						key = "e",
						keymap = "SPC e",
						key_hl = "Number",
						action = ":Neotree float",
					},
					{
						icon = "󰈞 ",
						icon_hl = "Title",
						desc = "[F]ind files",
						desc_hl = "String",
						key = "f",
						keymap = "SPC f f",
						key_hl = "Number",
						action = ":Telescope find_files",
					},
					{
						icon = " ",
						icon_hl = "Title",
						desc = "Find [W]ord in project",
						desc_hl = "String",
						key = "w",
						keymap = "SPC f w",
						key_hl = "Number",
						action = ":Telescope live_grep",
					},
					{
						icon = " ",
						icon_hl = "Title",
						desc = "Git [B]raches",
						desc_hl = "String",
						key = "b",
						keymap = "SPC g b",
						key_hl = "Number",
						action = ":Telescope git_branches",
					},
				},
			},
		})
	end,
}

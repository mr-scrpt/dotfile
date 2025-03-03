return {
	"rcarriga/nvim-notify",
	event = "VeryLazy",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	config = function()
		local async = require("plenary.async")
		local notify = require("notify")
		local nfasync = notify.async

		vim.opt.termguicolors = true
		vim.notify = notify

		vim.notify.setup({ background_colour = "#000000" })

		local keymap = vim.keymap -- for conciseness

		keymap.set("n", "<leader>nc", function()
			-- notify("Let's wait for this to close")
			notify.dismiss()
		end, { desc = "[N]otify [C]lose" })

		-- keymap.set(
		-- 	"n",
		-- 	"<leader>nc",
		-- 	async.run(function()
		-- 		notify.async("Let's wait for this to close").events.close()
		-- 		notify.async("It closed!")
		-- 	end),
		-- 	{ desc = "Mark file with harpoon" }
		-- )
		-- keymap.set(
		-- 	"n",
		-- 	"nc",
		-- 	async.run(function()
		-- 		-- notify.async().dismiss()
		-- 	end),
		-- 	{ desc = "Dismiss notifycation" }
		-- )

		-- local async = require("plenary.async")
		-- local notify = require("notify").async
		--
		-- vim.opt.termguicolors = true
		-- vim.notify = require("notify").async

		-- local keymap = vim.keymap -- for conciseness
		-- keymap.set(
		-- 	"n",
		-- 	"nc",
		-- 	async.run(function()
		-- 		notify("Let's wait for this to close").events.close()
		-- 		-- notify().dismiss()
		-- 	end),
		-- 	{ desc = "Dismiss notifycation" }
		-- )
	end,
}

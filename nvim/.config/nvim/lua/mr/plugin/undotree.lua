return {
	"mbbill/undotree",
	event = { "BufReadPre", "BufNewFile" },

	config = function()
		local map = function(keys, func, desc, mode)
			mode = mode or "n"
			vim.keymap.set(mode, keys, func, { desc = "Undotree: " .. desc })
		end

		map("<leader>u", vim.cmd.UndotreeToggle, "Toggle [U]ndotree")

		-- vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)
		vim.cmd([[
      let g:undotree_SetFocusWhenToggle = 1
    ]])
	end,
}

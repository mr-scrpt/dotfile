-- Bridge module for flat_favorites commands
-- Neo-tree expects commands at neo-tree.sources.<name>.commands

vim.notify("[bridge/commands] Loading flat_favorites commands from neotree-favorites plugin", vim.log.levels.INFO)

return require("neotree-favorites.commands")

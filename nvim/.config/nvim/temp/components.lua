-- Bridge module for flat_favorites components
-- Neo-tree expects components at neo-tree.sources.<name>.components

vim.notify("[bridge/components] Loading flat_favorites components from neotree-favorites plugin", vim.log.levels.INFO)

-- Return standard components (flat_favorites uses filesystem components)
return require("neo-tree.sources.common.components")

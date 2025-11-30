-- Default configuration for flat_favorites source

return {
  window = {
    mappings = {
      -- Fuzzy finder commands (специфичны для filesystem-like sources)
      ["/"] = "fuzzy_finder",
      ["#"] = "fuzzy_sorter",
      ["D"] = "fuzzy_finder_directory",
      ["f"] = "filter_on_submit",
      ["<c-x>"] = "clear_filter",
    },
  },
}

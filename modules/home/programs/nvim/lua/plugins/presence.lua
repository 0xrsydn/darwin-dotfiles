return {
  -- Discord Rich Presence (minimal + Neovim branding)
  {
    "andweeb/presence.nvim",
    event = "VeryLazy",
    opts = {
      -- Neovim branding
      neovim_image_text = "Neovim",
      main_image = "neovim",

      -- Minimal/privacy-focused text (no file or workspace details)
      editing_text = "Editing",
      file_explorer_text = "Browsing files",
      git_commit_text = "Committing changes",
      plugin_manager_text = "Managing plugins",
      reading_text = "Reading",
      workspace_text = nil,
      line_number_text = nil,
    },
  },
}

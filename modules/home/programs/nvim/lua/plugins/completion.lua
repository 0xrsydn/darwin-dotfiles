return {
  -- Modern completion engine with built-in fuzzy matching
  -- Note: Installed via Nix with pre-built Rust backend (see neovim.nix)
  {
    "saghen/blink.cmp",
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    version = "1.*",
    event = "InsertEnter",
    build = nil, -- Disable build since Nix provides pre-compiled version
    opts = {
      -- Keymap preset options: 'default' | 'super-tab' | 'enter'
      keymap = { preset = "super-tab" },

      appearance = {
        -- Use mono nerd font variant
        nerd_font_variant = "mono",
      },

      -- Default completion sources
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },

      completion = {
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 500,
        },
        menu = {
          draw = {
            columns = { { "label", "label_description", gap = 1 }, { "kind_icon", "kind" } },
          },
        },
      },

      -- Fuzzy matching implementation
      -- Using "rust" since Nix provides pre-built native module
      fuzzy = {
        use_typo_resistance = true,
        use_frecency = true,
        use_proximity = true,
      },
    },
    opts_extend = { "sources.default" },
  },
}

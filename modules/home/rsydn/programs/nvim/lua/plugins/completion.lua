return {
  -- Modern completion engine with built-in fuzzy matching
  {
    "saghen/blink.cmp",
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    version = "1.*",
    event = "InsertEnter",
    opts = {
      -- Keymap preset options: 'default' | 'super-tab' | 'enter'
      keymap = { preset = "default" },

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
      -- Options: "prefer_rust_with_warning" | "rust" | "lua"
      fuzzy = {
        implementation = "prefer_rust_with_warning",
      },
    },
    opts_extend = { "sources.default" },
  },
}

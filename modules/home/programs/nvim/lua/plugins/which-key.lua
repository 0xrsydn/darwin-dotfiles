return {
  -- Disable which-key (we use mini.clue instead)
  { "folke/which-key.nvim", enabled = false },

  -- mini.clue - Lightweight keybind hints
  {
    "nvim-mini/mini.clue",
    event = "VeryLazy",
    config = function()
      local miniclue = require("mini.clue")
      miniclue.setup({
        triggers = {
          -- Leader triggers
          { mode = "n", keys = "<Leader>" },
          { mode = "x", keys = "<Leader>" },

          -- Built-in completion
          { mode = "i", keys = "<C-x>" },

          -- `g` key
          { mode = "n", keys = "g" },
          { mode = "x", keys = "g" },

          -- Marks
          { mode = "n", keys = "'" },
          { mode = "n", keys = "`" },
          { mode = "x", keys = "'" },
          { mode = "x", keys = "`" },

          -- Registers
          { mode = "n", keys = '"' },
          { mode = "x", keys = '"' },
          { mode = "i", keys = "<C-r>" },
          { mode = "c", keys = "<C-r>" },

          -- Window commands
          { mode = "n", keys = "<C-w>" },

          -- `z` key
          { mode = "n", keys = "z" },
          { mode = "x", keys = "z" },

          -- Bracketed commands
          { mode = "n", keys = "[" },
          { mode = "n", keys = "]" },
        },

        clues = {
          -- Enhance this by adding descriptions for <Leader> mapping groups
          miniclue.gen_clues.builtin_completion(),
          miniclue.gen_clues.g(),
          miniclue.gen_clues.marks(),
          miniclue.gen_clues.registers(),
          miniclue.gen_clues.windows(),
          miniclue.gen_clues.z(),

          -- Custom leader key descriptions
          { mode = "n", keys = "<Leader>b", desc = "+buffer" },
          { mode = "n", keys = "<Leader>c", desc = "+code" },
          { mode = "n", keys = "<Leader>d", desc = "+diagnostics" },
          { mode = "n", keys = "<Leader>e", desc = "+explorer" },
          { mode = "n", keys = "<Leader>f", desc = "+find" },
          { mode = "n", keys = "<Leader>o", desc = "+open" },
          { mode = "n", keys = "<Leader>r", desc = "+rename" },
          { mode = "n", keys = "<Leader>s", desc = "+search" },
          { mode = "n", keys = "<Leader>t", desc = "+toggle" },
        },

        window = {
          delay = 300, -- Show hints after 300ms
          config = {
            width = "auto",
            border = "rounded",
          },
        },
      })
    end,
  },
}

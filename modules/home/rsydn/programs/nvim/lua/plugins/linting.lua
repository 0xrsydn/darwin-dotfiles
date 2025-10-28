return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile", "BufWritePost" },
    opts = {
      events = { "BufWritePost", "BufReadPost", "InsertLeave" },
      linters_by_ft = {
        -- Add linters per filetype here
        -- fish = { "fish" },
        -- javascript = { "eslint_d" },
        -- python = { "ruff" },
      },
      linters = {},
    },
    config = function(_, opts)
      local lint = require("lint")

      -- Merge custom linter configs
      for name, linter in pairs(opts.linters) do
        if type(linter) == "table" and type(lint.linters[name]) == "table" then
          lint.linters[name] = vim.tbl_deep_extend("force", lint.linters[name], linter)
        else
          lint.linters[name] = linter
        end
      end

      lint.linters_by_ft = opts.linters_by_ft

      -- Debounced lint function
      local function debounce_lint()
        local timer = vim.uv.new_timer()
        return function()
          timer:start(100, 0, vim.schedule_wrap(lint.try_lint))
        end
      end

      local lint_fn = debounce_lint()

      -- Create autocommand for linting
      vim.api.nvim_create_autocmd(opts.events, {
        group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
        callback = function()
          lint_fn()
        end,
      })
    end,
  },
}

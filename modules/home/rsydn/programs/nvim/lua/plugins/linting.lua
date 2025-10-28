return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile", "BufWritePost" },
    opts = {
      events = { "BufWritePost", "BufReadPost", "InsertLeave" },
      linters_by_ft = {
        javascript = { "eslint" },
        typescript = { "eslint" },
        javascriptreact = { "eslint" },
        typescriptreact = { "eslint" },
        python = { "ruff" },
        sh = { "shellcheck" },
        bash = { "shellcheck" },
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

      -- Debounced lint function with proper timer management
      local timer = vim.uv.new_timer()
      local function debounce_lint()
        -- Stop existing timer before starting new one to prevent EALREADY error
        timer:stop()
        timer:start(100, 0, vim.schedule_wrap(lint.try_lint))
      end

      -- Create autocommand for linting
      vim.api.nvim_create_autocmd(opts.events, {
        group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
        callback = debounce_lint,
      })

      -- Clean up timer on exit
      vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("nvim-lint-cleanup", { clear = true }),
        callback = function()
          if timer and not timer:is_closing() then
            timer:stop()
            timer:close()
          end
        end,
      })
    end,
  },
}

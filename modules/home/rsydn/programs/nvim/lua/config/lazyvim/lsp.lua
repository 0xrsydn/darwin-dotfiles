-- Enable language servers defined in nvim-lspconfig using the Nvim 0.11 API.
return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      local ensure = {
        "clangd",
        "gopls",
        "lua-language-server",
        "nil",
        "pyright",
        "rust-analyzer",
        "typescript-language-server",
      }
      for _, tool in ipairs(ensure) do
        if not vim.tbl_contains(opts.ensure_installed, tool) then
          table.insert(opts.ensure_installed, tool)
        end
      end
    end,
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    opts = function(_, opts)
      opts.servers = vim.tbl_deep_extend(
        "force",
        {
          lua_ls = {},
          nil_ls = {},
          pyright = {},
          ts_ls = {},
          rust_analyzer = {},
          gopls = {},
          clangd = {},
        },
        opts.servers or {}
      )
    end,
    config = function(_, opts)
      if vim.fn.has("nvim-0.11") == 0 then
        vim.notify("nvim-lspconfig requires Neovim 0.11+ for vim.lsp.config", vim.log.levels.ERROR)
        return
      end

      for name, server_opts in pairs(opts.servers or {}) do
        if server_opts ~= false then
          local config = type(server_opts) == "table" and vim.deepcopy(server_opts) or {}

          if config.enabled ~= false then
            config.enabled = nil

            -- Integrate blink.cmp capabilities with LSP
            local has_blink, blink = pcall(require, "blink.cmp")
            if has_blink then
              config.capabilities = blink.get_lsp_capabilities(config.capabilities)
            end

            if next(config) ~= nil then
              vim.lsp.config(name, config)
            end

            vim.lsp.enable(name)
          end
        end
      end
    end,
  },
}

-- Declare language servers provided via Nix so LazyVim skips Mason installs.
return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = {}
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      local servers = {
        lua_ls = { mason = false },
        nil_ls = { mason = false },
        pyright = { mason = false },
        tsserver = { mason = false },
        rust_analyzer = { mason = false },
        gopls = { mason = false },
        clangd = { mason = false },
      }

      for server, server_opts in pairs(servers) do
        local existing = opts.servers[server] or {}
        opts.servers[server] = vim.tbl_deep_extend("force", existing, server_opts)
      end
    end,
  },
}

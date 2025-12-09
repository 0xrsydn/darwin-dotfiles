-- LazyVim utilities module
-- Provides helper functions for plugin configuration

local M = {}

-- Mini module utilities
M.mini = {}

-- Setup mini.pairs with given options
function M.mini.pairs(opts)
  require("mini.pairs").setup(opts)
end

-- Text object for entire buffer
M.mini.ai_buffer = function(ai)
  local n_lines = vim.fn.line("$")
  local start_line, end_line = 1, n_lines
  if n_lines == 0 then
    return { from = { line = 0, col = 0 } }
  end
  local start_col, end_col = 1, math.max(vim.fn.getline(end_line):len(), 1)
  return {
    from = { line = start_line, col = start_col },
    to = { line = end_line, col = end_col },
  }
end

-- Text object hints are now handled by mini.clue

-- Run callback when plugin is loaded
function M.on_load(name, fn)
  local Config = require("lazy.core.config")
  if Config.plugins[name] and Config.plugins[name]._.loaded then
    vim.schedule(function()
      fn(name)
    end)
  else
    vim.api.nvim_create_autocmd("User", {
      pattern = "LazyLoad",
      callback = function(event)
        if event.data == name then
          fn(name)
          return true
        end
      end,
    })
  end
end

-- Make LazyVim global
_G.LazyVim = M

return M

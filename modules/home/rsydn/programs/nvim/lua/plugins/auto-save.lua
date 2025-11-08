return {
  "okuuva/auto-save.nvim",
  event = { "InsertLeave", "TextChanged" },
  opts = {
    enabled = true, -- Plugin is loaded but conditional on manual toggle
    execution_message = {
      enabled = true,
      message = function()
        return "AutoSave: saved at " .. vim.fn.strftime("%H:%M:%S")
      end,
      dim = 0.18,
      cleaning_interval = 1250,
    },
    trigger_events = {
      immediate_save = { "BufLeave", "FocusLost" },
      defer_save = { "InsertLeave", "TextChanged" },
      cancel_deferred_save = { "InsertEnter" },
    },
    condition = function(buf)
      -- Only save if manually enabled
      if not vim.g.auto_save_enabled then
        return false
      end

      local fn = vim.fn
      local utils = require("auto-save.utils.data")

      -- Don't save for special buffer types
      if utils.not_in(fn.getbufvar(buf, "&filetype"), {}) and fn.getbufvar(buf, "&buftype") == "" and fn.filereadable(fn.bufname(buf)) == 1 then
        return true
      end

      return false
    end,
    write_all_buffers = false,
    debounce_delay = 1000, -- Wait 1 second after typing stops before saving
  },
  keys = {
    {
      "<leader>ta",
      function()
        vim.g.auto_save_enabled = not vim.g.auto_save_enabled
        if vim.g.auto_save_enabled then
          vim.notify("Auto-save enabled", vim.log.levels.INFO)
        else
          vim.notify("Auto-save disabled", vim.log.levels.INFO)
        end
      end,
      desc = "Toggle auto-save",
    },
  },
}

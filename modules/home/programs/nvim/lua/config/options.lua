-- Minimal essential options
local opt = vim.opt

-- Leader keys
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true

-- UI
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Clipboard
opt.clipboard = "unnamedplus"

-- On a Linux machine with no display (SSH, OrbStack), copy through the
-- terminal with OSC 52. Nvim would otherwise pick OrbStack's pbcopy shim,
-- which fails silently on an isolated machine ("dial: no such file").
-- Paste reads Nvim's own register, since terminals often refuse OSC 52 reads.
if vim.fn.has("mac") == 0 and not vim.env.WAYLAND_DISPLAY and not vim.env.DISPLAY then
  local osc52 = require("vim.ui.clipboard.osc52")
  local function paste()
    return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
  end
  vim.g.clipboard = {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = paste, ["*"] = paste },
  }
end

-- Undo
opt.undofile = true

-- Mouse
opt.mouse = "a"

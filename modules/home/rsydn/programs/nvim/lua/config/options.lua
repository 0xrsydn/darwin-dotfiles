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

-- Undo
opt.undofile = true

-- Mouse
opt.mouse = "a"

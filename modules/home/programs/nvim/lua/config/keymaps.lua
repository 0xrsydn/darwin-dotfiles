-- Essential keymaps (minimal improvements over default Vim)
local keymap = vim.keymap

-- Clear search highlight with <esc>
keymap.set("n", "<esc>", "<cmd>noh<cr>", { desc = "Clear search highlight" })

-- Better indenting (stay in visual mode)
keymap.set("v", "<", "<gv")
keymap.set("v", ">", ">gv")

-- Load configuration
require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.notes")

-- Load LazyVim utilities before lazy plugin manager
require("config.lazyvim")

require("config.lazy")

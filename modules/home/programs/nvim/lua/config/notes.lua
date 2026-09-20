local M = {}

local default_root = vim.fn.expand("~/Development/MyWeb/magnum-opus/main")
local root = vim.fs.normalize(vim.env.RASYIDANAF_SITE_ROOT or default_root)
local notes_directory = vim.fs.normalize(root .. "/vault/public-notes")
local blog_directory = vim.fs.normalize(root .. "/vault/blog")

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "Notes" })
end

local function last_line(value)
	local output = vim.trim(value or "")
	return output:match("([^\r\n]+)$")
end

local function first_matching_line(value, pattern)
	for line in (value or ""):gmatch("[^\r\n]+") do
		local candidate = vim.trim(line)
		if candidate:match(pattern) then
			return candidate
		end
	end
end

local function first_actionable_line(value)
	for line in (value or ""):gmatch("[^\r\n]+") do
		local candidate = vim.trim(line)
		if candidate ~= "" and not candidate:match("^%$ ") and not candidate:match('^error: script ".-" exited') then
			return candidate
		end
	end
end

local function command_error(result)
	return first_matching_line(result.stdout, "^ERROR%s")
		or first_actionable_line(result.stderr)
		or first_actionable_line(result.stdout)
		or "Notes command failed."
end

local function run(arguments, options)
	options = options or {}

	if vim.fn.executable("direnv") ~= 1 then
		notify("direnv is not available in PATH.", vim.log.levels.ERROR)
		return
	end

	local command = {
		"direnv",
		"exec",
		root,
		"bun",
		"run",
	}
	vim.list_extend(command, arguments)

	notify(options.progress or "Running Notes command…")
	vim.system(
		command,
		{
			cwd = root,
			text = true,
		},
		vim.schedule_wrap(function(result)
			if result.code ~= 0 then
				notify(command_error(result), vim.log.levels.ERROR)
				return
			end

			if options.on_success then
				options.on_success(vim.trim(result.stdout or ""))
				return
			end

			notify(last_line(result.stdout) or options.success or "Notes command finished.")
		end)
	)
end

local function open_created_entry(output)
	local relative_path = last_line(output)
	if not relative_path then
		notify("The Notes command did not return a file path.", vim.log.levels.ERROR)
		return
	end

	local path = relative_path
	if not vim.startswith(path, "/") then
		path = root .. "/" .. path
	end

	vim.cmd.edit(vim.fn.fnameescape(vim.fs.normalize(path)))
	notify("Draft created: " .. relative_path)
end

local function create_entry(kind, title)
	local arguments = { "notes:new", "--", "--kind", kind }

	if title and title ~= "" then
		vim.list_extend(arguments, { "--title", title })
	end

	run(arguments, {
		progress = "Creating " .. kind .. " draft…",
		on_success = open_created_entry,
	})
end

function M.new_log()
	vim.ui.input({
		prompt = "Log title (optional): ",
	}, function(title)
		if title == nil then
			return
		end

		create_entry("log", vim.trim(title))
	end)
end

function M.new_note()
	vim.ui.input({
		prompt = "Note title: ",
	}, function(title)
		if title == nil then
			return
		end

		title = vim.trim(title)
		if title == "" then
			notify("A Note requires a title.", vim.log.levels.WARN)
			return
		end

		create_entry("note", title)
	end)
end

local function current_path()
	local path = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
	if path == "" then
		notify("The current buffer has no file.", vim.log.levels.ERROR)
		return nil
	end
	return path
end

local function current_entry()
	local path = current_path()
	if not path then
		return nil
	end

	if not vim.startswith(path, notes_directory .. "/") or not path:match("%.md$") then
		notify("Open a Markdown file inside vault/public-notes/ first.", vim.log.levels.ERROR)
		return nil
	end

	return path
end

local function current_taggable_content()
	local path = current_path()
	if not path then
		return nil
	end

	local is_public_note = vim.startswith(path, notes_directory .. "/") and path:match("%.md$")
	local is_blog_post = vim.startswith(path, blog_directory .. "/")
		and (path:match("/index%.md$") or path:match("/index%.mdx$"))
	if not is_public_note and not is_blog_post then
		notify("Open a Draft in vault/public-notes/ or vault/blog/ first.", vim.log.levels.ERROR)
		return nil
	end

	return path
end

local function save_current_buffer()
	if not vim.bo.modified then
		return true
	end
	local saved, error_message = pcall(vim.cmd.write)
	if not saved then
		notify("Could not save the content: " .. tostring(error_message), vim.log.levels.ERROR)
		return false
	end
	return true
end

function M.publish()
	local path = current_entry()
	if not path then
		return
	end

	if not save_current_buffer() then
		return
	end

	vim.ui.select({ "Publish", "Cancel" }, {
		prompt = "Publish " .. vim.fn.fnamemodify(path, ":t") .. "?",
	}, function(choice)
		if choice ~= "Publish" then
			return
		end

		run({ "notes:publish", path }, {
			progress = "Publishing Entry…",
			on_success = function(output)
				vim.cmd.edit(vim.fn.fnameescape(path))
				notify(last_line(output) or "Entry published.")
			end,
		})
	end)
end

function M.auto_tag()
	local path = current_taggable_content()
	if not path or not save_current_buffer() then
		return
	end

	run({ "content:tag", path }, {
		progress = "Generating tags…",
		on_success = function(output)
			vim.cmd.edit(vim.fn.fnameescape(path))
			notify(last_line(output) or "Tags applied.")
		end,
	})
end

function M.validate()
	run({ "notes:validate" }, {
		progress = "Validating Notes…",
		success = "Notes validation passed.",
	})
end

function M.build()
	run({ "build" }, {
		progress = "Building the website…",
		success = "Website build passed.",
	})
end

vim.api.nvim_create_user_command("NotesNewLog", M.new_log, {
	desc = "Create a public Log draft",
})
vim.api.nvim_create_user_command("NotesNewNote", M.new_note, {
	desc = "Create a public Note draft",
})
vim.api.nvim_create_user_command("NotesPublish", M.publish, {
	desc = "Publish the current public Notes Entry",
})
vim.api.nvim_create_user_command("ContentAutoTag", M.auto_tag, {
	desc = "Automatically tag the current Draft Note or Blog Post",
})
vim.api.nvim_create_user_command("NotesValidate", M.validate, {
	desc = "Validate public Notes",
})
vim.api.nvim_create_user_command("NotesBuild", M.build, {
	desc = "Build the website",
})

vim.keymap.set("n", "<localleader>nl", M.new_log, { desc = "New log" })
vim.keymap.set("n", "<localleader>nn", M.new_note, { desc = "New note" })
vim.keymap.set("n", "<localleader>np", M.publish, { desc = "Publish current note" })
vim.keymap.set("n", "<localleader>nt", M.auto_tag, { desc = "Auto-tag current draft" })
vim.keymap.set("n", "<localleader>nv", M.validate, { desc = "Validate notes" })
vim.keymap.set("n", "<localleader>nb", M.build, { desc = "Build website" })

return M

-- nvim\lua\pLAyME\init.lua
require("pLAyME.remap")
require("pLAyME.set")
require("pLAyME.lazy_init")
require("pLAyME.compile_langs")

local augroup = vim.api.nvim_create_augroup
local pLAyMEGroup = augroup('pLAyME', {})

local autocmd = vim.api.nvim_create_autocmd
local yank_group = augroup('HighlightYank', {})

function R(name)
	require("plenary.reload").reload_module(name)
end

-- ==========================================================
--  1. CONFIGURATION FOR PHP / BLADE (Laravel)
-- ==========================================================
autocmd("FileType", {
    pattern = { "php", "blade" },
    callback = function()
        local root = vim.fn.getcwd():gsub("\\", "/")

        -- 1. Set the Search Path
        vim.opt_local.path:append(root .. "/resources/views")

        -- 2. Add the extension
        vim.opt_local.suffixesadd:append(".blade.php")

        -- 3. THE FIX: Use 'tr' instead of 'substitute'
        -- This simply turns every dot (.) into a slash (/) without complex regex
        vim.opt_local.includeexpr = [[tr(v:fname, '.', '/')]]

        vim.keymap.set("n", "gf", function()
            local line = vim.fn.expand("<cfile>")
            -- Convert dot to slash
            local file = line:gsub("%.", "/")
            -- Add extension and views folder
            local filepath = "resources/views/" .. file .. ".blade.php"
            -- Open it
            vim.cmd("edit " .. filepath)
        end, { buffer = true, desc = "Go to Laravel View" })

        -- 4. Ensure dots are considered part of the filename so 'gf' grabs the whole string
        vim.opt_local.isfname:append("@-@")
    end,
})

-- Force .blade.php files to be recognized as 'blade' filetype
vim.filetype.add({
    pattern = {
        ['.*%.blade%.php'] = 'blade',
    },
})

-- ==========================================================
-- Other CONFIGURATION
-- ==========================================================
vim.filetype.add({
    extension = {
        templ = 'templ',
    }
})

vim.api.nvim_create_user_command("Vrn", function(opts)
    -- 1. Get the range of the visual selection
    -- '< and '> marks are updated after leaving visual mode (which happens when you press :)
    local vstart = vim.fn.getpos("'<")
    local vend = vim.fn.getpos("'>")

    local line_start = vstart[2] - 1
    local col_start = vstart[3] - 1
    local line_end = vend[2] - 1
    local col_end = vend[3] -- get_text is exclusive at end, but getpos is inclusive, adjustments handled below

    -- 2. Get the actual text from the buffer
    -- We use nvim_buf_get_text for character-wise precision
    local lines = vim.api.nvim_buf_get_text(0, line_start, col_start, line_end, col_end, {})
    local selection = table.concat(lines, "\n")

    -- If selection is empty, stop
    if selection == "" then
        print("No text selected")
        return
    end

    -- 3. Prepare the Search Pattern
    -- We replace actual newlines with "\n" for the regex to work across lines if needed
    selection = selection:gsub("\n", "\\n")
    -- \V (very nomagic) tells Vim to treat characters like '.', '*', '[' as literal text, not regex
    -- We only need to escape '\' and the delimiter '/'
    local search_pattern = "\\V" .. vim.fn.escape(selection, "/\\")

    -- 4. Prepare the Replacement String
    -- The user input (opts.args) becomes the replacement.
    -- We must escape the delimiter '/' here as well.
    local replacement = vim.fn.escape(opts.args, "/")

    -- 5. Construct and Execute the Command
    -- Structure: %s / {search} / {replacement} / gc
    -- % = whole file
    -- g = global (all occurrences on a line)
    -- c = confirm (ask yes/no)
    local cmd = string.format("%%s/%s/%s/gc", search_pattern, replacement)

    -- Print info and execute
    vim.cmd(cmd)

end, {
nargs = '+', -- Requires at least one argument (the new name)
range = true, -- Allows the command to be run while a range is active
desc = "Visual Rename: Replace selected text with arg across whole file with confirmation"
})

-- Optional: Create a lowercase alias ':vrn' that triggers ':Vrn'
vim.cmd([[cnoreabbrev <expr> vrn (getcmdtype() == ':' && getcmdline() == 'vrn') ? 'Vrn' : 'vrn']])

vim.filetype.add({
    extension = {
        templ = 'templ',
    }
})
autocmd('TextYankPost', {
    group = yank_group,
    pattern = '*',
    callback = function()
        vim.highlight.on_yank({
            higroup = 'IncSearch',
            timeout = 40,
        })
    end,
})

autocmd('LspAttach', {
    group = pLAyMEGroup,
    callback = function(e)
        local opts = { buffer = e.buf }
        vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
        vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
        vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
        vim.keymap.set("n", "<leader>vd", function() vim.diagnostic.open_float() end, opts)
        vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
        vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
        vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
        vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)
        vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end, opts)
        vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end, opts)
    end
})

vim.g.do_filetype_lua = 1
vim.g.netrw_browse_split = 0
vim.g.netrw_banner = 0
vim.g.netrw_winsize = 25



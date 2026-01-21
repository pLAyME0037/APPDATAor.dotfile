-- nvim\lua\pLAyME\init.lua 
require("pLAyME.remap")
require("pLAyME.set")
require("pLAyME.lazy_init")

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
-- autocmd("FileType", {
--     pattern = { "php", "blade" },
--     callback = function()
--         local root = vim.fn.getcwd():gsub("\\", "/")
--
--         -- 1. Set the Search Path
--         vim.opt_local.path:append(root .. "/resources/views")
--
--         -- 2. Add the extension
--         vim.opt_local.suffixesadd:append(".blade.php")
--
--         -- 3. THE FIX: Use 'tr' instead of 'substitute'
--         -- This simply turns every dot (.) into a slash (/) without complex regex
--         vim.opt_local.includeexpr = [[tr(v:fname, '.', '/')]]
--
--         vim.keymap.set("n", "gf", function()
--             local line = vim.fn.expand("<cfile>")
--             -- Convert dot to slash
--             local file = line:gsub("%.", "/")
--             -- Add extension and views folder
--             local filepath = "resources/views/" .. file .. ".blade.php"
--             -- Open it
--             vim.cmd("edit " .. filepath)
--         end, { buffer = true, desc = "Go to Laravel View" })
--
--         -- 4. Ensure dots are considered part of the filename so 'gf' grabs the whole string
--         vim.opt_local.isfname:append("@-@")
--     end,
-- })

-- Force .blade.php files to be recognized as 'blade' filetype
-- vim.filetype.add({
--     pattern = {
--         ['.*%.blade%.php'] = 'blade',
--     },
-- })

-- ==========================================================
-- Other CONFIGURATION 
-- ==========================================================
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

vim.g.netrw_browse_split = 0
vim.g.netrw_banner = 0
vim.g.netrw_winsize = 25

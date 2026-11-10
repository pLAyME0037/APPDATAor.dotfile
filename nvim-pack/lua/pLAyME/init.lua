-- nvim\lua\pLAyME\init.lua
-- require("vim._core.ui2").enable({})
require("pLAyME.remap")
require("pLAyME.set")
require("pLAyME.pack")
require("pLAyME/setup-pack")
require("pLAyME.command")
require("pLAyME.compile_langs")

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local yank_group = augroup('HighlightYank', {})

-- function R(name)
-- 	require("plenary.reload").reload_module(name)
-- end

-- vim.lsp.enable("clangd")

-- ==========================================================
-- Auto-update tags safely on save (with HOME safety guards)
-- ==========================================================
local ctags_job = nil
local ctags_timer = nil
local home_dir = vim.fs.normalize(vim.fn.expand("~"))

local ctags_excludes = {
    "--exclude=.git",
    "--exclude=.cache",
    "--exclude=.cargo",
    "--exclude=.local",
    "--exclude=node_modules",
    "--exclude=build",
    "--exclude=bin",
    "--exclude=obj",
    "--exclude=dist",
    "--exclude=vendor",
    "--exclude=compile_commands.json",
}

local function run_ctags()
    if ctags_job then
        vim.fn.jobstop(ctags_job)
        ctags_job = nil
    end

    -- 1. ONLY look for .git (NEVER search for "tags", otherwise ~/tags traps $HOME forever)
    local root = vim.fs.root(0, { ".git" })

    -- 2. SAFETY GUARD: If not in a git repo, DO NOT run ctags automatically
    if not root or root == "" then
        return
    end

    root = vim.fs.normalize(root)

    -- 3. SAFETY GUARD: NEVER run ctags on $HOME or the filesystem root /
    if root == home_dir or root == "/" then
        return
    end

    local cmd = { "ctags", "-R" }
    vim.list_extend(cmd, ctags_excludes)
    vim.list_extend(cmd, { "-f", "tags", "." })

    ctags_job = vim.fn.jobstart(cmd, {
        cwd = root,
        on_exit = function()
            ctags_job = nil
        end,
    })
end

vim.api.nvim_create_user_command("TagsGenerate", function()
    local root = vim.fs.root(0, { ".git" })
    if not root or root == "" then
        root = vim.fs.normalize(vim.fn.getcwd())
    else
        root = vim.fs.normalize(root)
    end

    if root == home_dir or root == "/" then
        vim.notify("Refusing to run ctags in $HOME or /", vim.log.levels.WARN)
        return
    end

    local cmd = { "ctags", "-R" }
    vim.list_extend(cmd, ctags_excludes)
    vim.list_extend(cmd, { "-f", "tags", "." })

    vim.fn.jobstart(cmd, {
        cwd = root,
        on_exit = function(_, code)
            if code == 0 then
                vim.notify("Tags built successfully", vim.log.levels.INFO)
            else
                vim.notify("Tags build failed", vim.log.levels.ERROR)
            end
        end,
    })
end, { desc = "Generate ctags file safely" })

vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("AutoCtags", { clear = true }),
    pattern = "*",
    callback = function()
        -- Skip special buffers or git commit buffers
        if vim.bo.buftype ~= "" or vim.fn.expand("%"):match("^%.git") then
            return
        end

        -- Debounce: wait 1.5s after editing stops before triggering
        if ctags_timer then
            ctags_timer:stop()
        end
        ctags_timer = vim.defer_fn(run_ctags, 1500)
    end,
})

-- ==========================================================
--  1. CONFIGURATION FOR FILE TYPE
-- ==========================================================
autocmd("FileType", {
    pattern = { "php", "blade" },
    callback = function(args)
        local root = vim.fn.getcwd():gsub("\\", "/")

        vim.opt_local.path:append(root .. "/resources/views")

        vim.opt_local.suffixesadd:append(".blade.php")

        -- This simply turns every dot (.) into a slash (/) without complex regex
        vim.opt_local.includeexpr = [[tr(v:fname, '.', '/')]]

        vim.keymap.set("n", "gf", function()
            local line = vim.fn.expand("<cfile>")
            local file = line:gsub("%.", "/")
            local filepath = "resources/views/" .. file .. ".blade.php"
            vim.cmd("edit " .. filepath)
        end, { buffer = args.buf, desc = "Go to Laravel View" })

        -- Ensure dots are considered part of the filename so 'gf' grabs the whole string
        vim.opt_local.isfname:append("@-@")
    end,
})

-- Force .blade.php files to be recognized as 'blade' filetype
vim.filetype.add({
    pattern = {
        ['.*%.blade%.php'] = 'blade',
        ['.*%.h%.tt'] = 'html',
    },
})

-- ==========================================================
-- Other CONFIGURATION
-- ==========================================================

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

-- autocmd('LspAttach', {
--     callback = function(e)
--         local opts = { buf = e.buf }
--         vim.keymap.set("n", "<leader>fm",  vim.lsp.buf.format)
--         vim.keymap.set("n", "<leader>vd",  function() vim.diagnostic.open_float() end, opts)
--         vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
--         vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
--         vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
--         vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
--         vim.keymap.set("i", "<C-h>",       function() vim.lsp.buf.signature_help() end, opts)
--         vim.keymap.set("n", "gd",          function() vim.lsp.buf.definition() end, opts)
--         vim.keymap.set("n", "K",           function() vim.lsp.buf.hover() end, opts)
--         vim.keymap.set("n", "[d",          function() vim.diagnostic.jump({ count = 1, float = true }) end, opts)
--         vim.keymap.set("n", "]d",          function() vim.diagnostic.jump({ count = -1, float = true }) end, opts)
--     end
-- })

vim.g.netrw_browse_split = 0
vim.g.netrw_winsize = 30

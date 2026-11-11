require("pLAyME.remap")
require("pLAyME.set")
require("pLAyME.pack")
require("pLAyME.setup-pack")
require("pLAyME.command")
require("pLAyME.compile_langs")

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local yank_group = augroup("HighlightYank", {})

-- Disable LSP semantic tokens so Tree-sitter and theme define syntax colors
vim.api.nvim_create_autocmd("LspAttach", {
    desc = "Disable LSP semantic tokens to let Tree-sitter control syntax colors",
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client then
            client.server_capabilities.semanticTokensProvider = nil
        end
    end,
})

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
    "--exclude=resource",
    "--exclude=asset",
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

    local root = vim.fs.root(0, { ".git" })
    if not root or root == "" then
        return
    end

    root = vim.fs.normalize(root)
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
        if vim.bo.buftype ~= "" or vim.fn.expand("%"):match("^%.git") then
            return
        end

        if ctags_timer then
            ctags_timer:stop()
        end
        ctags_timer = vim.defer_fn(run_ctags, 1500)
    end,
})

-- ==========================================================
-- CONFIGURATION FOR FILE TYPE
-- ==========================================================
autocmd("FileType", {
    pattern = { "php", "blade" },
    callback = function(args)
        local root = vim.fn.getcwd():gsub("\\", "/")
        vim.opt_local.path:append(root .. "/resources/views")
        vim.opt_local.suffixesadd:append(".blade.php")
        vim.opt_local.includeexpr = [[tr(v:fname, '.', '/')]]

        vim.keymap.set("n", "gf", function()
            local line = vim.fn.expand("<cfile>")
            local file = line:gsub("%.", "/")
            local filepath = "resources/views/" .. file .. ".blade.php"
            vim.cmd("edit " .. filepath)
        end, { buffer = args.buf, desc = "Go to Laravel View" })

        vim.opt_local.isfname:append("@-@")
    end,
})

vim.filetype.add({
    pattern = {
        [".*%.blade%.php"] = "blade",
        [".*%.h%.tt"] = "html",
    },
})

-- ==========================================================
-- Other CONFIGURATION
-- ==========================================================
autocmd("TextYankPost", {
    group = yank_group,
    pattern = "*",
    callback = function()
        vim.highlight.on_yank({
            higroup = "IncSearch",
            timeout = 40,
        })
    end,
})

vim.g.netrw_browse_split = 0
vim.g.netrw_winsize = 30

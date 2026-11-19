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
local uv = vim.uv
if uv == nil then
    uv = vim.loop
end

local ctags_job = nil
local ctags_timer = nil
local home_dir = vim.fs.normalize(vim.fn.expand("~"))

local ctags_excludes = {
    "--links=no",
    "--exclude=.wine",
    "--exclude=.git",
    "--exclude=.cache",
    "--exclude=.cargo",
    "--exclude=.local",
    "--exclude=*.h.tt",
    "--exclude=*.html",
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

local function run_ctags(root)
    if vim.fn.executable("ctags") ~= 1 then
        return
    end

    if ctags_job then
        vim.fn.jobstop(ctags_job)
        ctags_job = nil
    end

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
    if vim.fn.executable("ctags") ~= 1 then
        vim.notify("ctags binary not found", vim.log.levels.WARN)
        return
    end

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

-- Walk up from buffer dir: update tags only where tags file already exists.
-- Stop at .git boundary, $HOME, or / — never auto-create tags.
local function find_tags_dir(start_dir)
    local dir = vim.fs.normalize(start_dir)
    while true do
        if dir == home_dir or dir == "/" then
            return nil
        end

        if vim.fn.filereadable(dir .. "/tags") == 1 then
            return dir
        end

        -- .git can be dir (normal) or file (worktree/submodule)
        if vim.fn.isdirectory(dir .. "/.git") == 1 or vim.fn.filereadable(dir .. "/.git") == 1 then
            return nil
        end

        local parent = vim.fs.dirname(dir)
        if parent == dir then
            return nil
        end
        dir = parent
    end
end

vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("AutoCtags", { clear = true }),
    pattern = "*",
    callback = function(args)
        if not vim.api.nvim_buf_is_valid(args.buf) then
            return
        end
        if vim.bo[args.buf].buftype ~= "" then
            return
        end

        local buf_name = vim.api.nvim_buf_get_name(args.buf)
        if buf_name == "" then
            return
        end
        if buf_name:match("/%.git/") or buf_name:match("^%.git") then
            return
        end

        local raw_dir = vim.fs.dirname(buf_name)
        local start_dir = uv.fs_realpath(raw_dir) or raw_dir

        local tags_dir = find_tags_dir(start_dir)
        if not tags_dir then
            return
        end

        if ctags_timer == nil or ctags_timer:is_closing() then
            ctags_timer = uv.new_timer()
        else
            ctags_timer:stop()
        end

        if ctags_timer ~= nil then
            ctags_timer:start(1500, 0, vim.schedule_wrap(function()
                run_ctags(tags_dir)
            end))
        end
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
            if vim.fn.filereadable(filepath) == 1 then
                vim.cmd("edit " .. vim.fn.fnameescape(filepath))
            else
                vim.cmd("normal! gf")
            end
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

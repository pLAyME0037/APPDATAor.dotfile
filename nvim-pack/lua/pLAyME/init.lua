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
    "--exclude=.tags.tmp*",
}

local ctags_flags = {
    "--kinds-C=+pxlz",
    "--kinds-C++=+pxlz",
    "--fields=+iaSl",
    "--extras=+qf",
}

local function run_ctags(root, notify)
    if vim.fn.executable("ctags") ~= 1 then
        if notify then
            vim.notify("ctags binary not found", vim.log.levels.WARN)
        end
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
        if notify then
            vim.notify("Refusing to run ctags in $HOME or /", vim.log.levels.WARN)
        end
        return
    end

    local tmp_name = ".tags.tmp." .. tostring(uv.hrtime())
    local tmp_path = root .. "/" .. tmp_name
    local out_path = root .. "/tags"

    local cmd = { "ctags", "-R" }
    vim.list_extend(cmd, ctags_flags)
    vim.list_extend(cmd, ctags_excludes)
    vim.list_extend(cmd, { "-f", tmp_name, "." })

    local this_job = nil
    this_job = vim.fn.jobstart(cmd, {
        cwd = root,
        on_exit = function(_, code)
            if ctags_job == this_job then
                ctags_job = nil
            end
            if code == 0 then
                local ok_ren = uv.fs_rename(tmp_path, out_path)
                if notify then
                    if ok_ren then
                        vim.notify("Tags built successfully", vim.log.levels.INFO)
                    else
                        pcall(uv.fs_unlink, tmp_path)
                        vim.notify("Failed to rename tags file", vim.log.levels.ERROR)
                    end
                end
            else
                pcall(uv.fs_unlink, tmp_path)
                if notify then
                    vim.notify("Tags build failed", vim.log.levels.ERROR)
                end
            end
        end,
    })
    ctags_job = this_job
end

vim.api.nvim_create_user_command("TagsGenerate", function()
    if vim.fn.executable("ctags") ~= 1 then
        vim.notify("ctags binary not found", vim.log.levels.WARN)
        return
    end

    local start_dir = vim.fn.getcwd()
    if vim.bo.buftype == "" then
        local buf_name = vim.api.nvim_buf_get_name(0)
        if buf_name ~= "" then
            start_dir = vim.fs.dirname(buf_name)
        end
    end
    start_dir = vim.fs.normalize(uv.fs_realpath(start_dir) or start_dir)

    if start_dir == home_dir or start_dir == "/" then
        vim.notify("Refusing to run ctags in $HOME or /", vim.log.levels.WARN)
        return
    end

    local root = nil
    local dir = start_dir
    while true do
        if dir == home_dir or dir == "/" then
            break
        end
        if vim.fn.filereadable(dir .. "/tags") == 1 then
            root = dir
            break
        end
        if vim.fn.isdirectory(dir .. "/.git") == 1 or vim.fn.filereadable(dir .. "/.git") == 1 then
            root = dir
            break
        end
        local parent = vim.fs.dirname(dir)
        if parent == dir then
            break
        end
        dir = parent
    end

    if root == nil then
        local cwd = vim.fn.getcwd()
        root = vim.fs.normalize(uv.fs_realpath(cwd) or cwd)
    end

    if root == home_dir or root == "/" then
        vim.notify("Refusing to run ctags in $HOME or /", vim.log.levels.WARN)
        return
    end

    local tmp_name = ".tags.tmp." .. tostring(uv.hrtime())
    local tmp_path = root .. "/" .. tmp_name
    local out_path = root .. "/tags"

    local cmd = { "ctags", "-R" }
    vim.list_extend(cmd, ctags_flags)
    vim.list_extend(cmd, ctags_excludes)
    vim.list_extend(cmd, { "-f", tmp_name, "." })

    vim.fn.jobstart(cmd, {
        cwd = root,
        on_exit = function(_, code)
            if code == 0 then
                local ok_ren = uv.fs_rename(tmp_path, out_path)
                if ok_ren then
                    vim.notify("Tags built successfully in " .. root, vim.log.levels.INFO)
                else
                    pcall(uv.fs_unlink, tmp_path)
                    vim.notify("Failed to rename tags file", vim.log.levels.ERROR)
                end
            else
                pcall(uv.fs_unlink, tmp_path)
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
-- Generic C/C++ header path (gf) & resolved header tags
-- ==========================================================
local compiler_inc_cache = {}
local header_tags_job    = nil

local function split_shell_args(raw)
    local args      = {}
    local cur       = {}
    local in_single = false
    local in_double = false
    local escaped   = false
    local has_tok   = false

    for i = 1, #raw do
        local ch = raw:sub(i, i)
        if escaped then
            table.insert(cur, ch)
            escaped = false
            has_tok = true
        elseif ch == "\\" and not in_single then
            escaped = true
            has_tok = true
        elseif ch == "'" and not in_double then
            in_single = not in_single
            has_tok   = true
        elseif ch == '"' and not in_single then
            in_double = not in_double
            has_tok   = true
        elseif ch:match("%s") and not in_single and not in_double then
            if has_tok then
                table.insert(args, table.concat(cur))
                cur     = {}
                has_tok = false
            end
        else
            table.insert(cur, ch)
            has_tok = true
        end
    end

    if has_tok then
        table.insert(args, table.concat(cur))
    end
    return args
end

local function resolve_rel_path(base_dir, p)
    if p == "" then
        return p
    end
    if p:sub(1, 1) == "/" then
        return vim.fs.normalize(p)
    end
    return vim.fs.normalize(base_dir .. "/" .. p)
end

local function parse_compiler_args(args, base_dir, default_compiler)
    local compiler = default_compiler
    local idx = 1
    if #args >= 1 and args[1]:sub(1, 1) ~= "-" then
        local base = vim.fs.basename(args[1])
        if (base == "ccache" or base == "sccache" or base == "distcc") and #args >= 2 and args[2]:sub(1, 1) ~= "-" then
            compiler = args[2]
            idx = 3
        else
            compiler = args[1]
            idx = 2
        end
    end

    local probe_flags       = {}
    local dep_flags         = {}
    local next_is_path_flag = nil
    local next_is_val_flag  = nil

    for i = idx, #args do
        local a = args[i]
        if next_is_path_flag ~= nil then
            local resolved = resolve_rel_path(base_dir, a)
            table.insert(probe_flags, next_is_path_flag)
            table.insert(probe_flags, resolved)
            table.insert(dep_flags, next_is_path_flag)
            table.insert(dep_flags, resolved)
            next_is_path_flag = nil
        elseif next_is_val_flag ~= nil then
            if next_is_val_flag == "-target" or next_is_val_flag == "--target" then
                table.insert(probe_flags, next_is_val_flag)
                table.insert(probe_flags, a)
            end
            table.insert(dep_flags, next_is_val_flag)
            table.insert(dep_flags, a)
            next_is_val_flag = nil
        elseif a == "-I" or a == "-isystem" or a == "-iquote" or a == "-idirafter" or a == "-isysroot" or a == "--sysroot" then
            next_is_path_flag = a
        elseif a == "-D" or a == "-U" or a == "-target" or a == "--target" or a == "-include" then
            next_is_val_flag = a
        elseif a == "-nostdinc" or a == "-nostdinc++" or vim.startswith(a, "-stdlib=") or vim.startswith(a, "--target=") then
            table.insert(probe_flags, a)
            table.insert(dep_flags, a)
        elseif vim.startswith(a, "--sysroot=") then
            local val = "--sysroot=" .. resolve_rel_path(base_dir, a:sub(11))
            table.insert(probe_flags, val)
            table.insert(dep_flags, val)
        elseif vim.startswith(a, "-I") and #a > 2 then
            local val = "-I" .. resolve_rel_path(base_dir, a:sub(3))
            table.insert(probe_flags, val)
            table.insert(dep_flags, val)
        elseif vim.startswith(a, "-isystem") and #a > 8 then
            local val = "-isystem" .. resolve_rel_path(base_dir, a:sub(9))
            table.insert(probe_flags, val)
            table.insert(dep_flags, val)
        elseif vim.startswith(a, "-iquote") and #a > 7 then
            local val = "-iquote" .. resolve_rel_path(base_dir, a:sub(8))
            table.insert(probe_flags, val)
            table.insert(dep_flags, val)
        elseif vim.startswith(a, "-D") or vim.startswith(a, "-U") or vim.startswith(a, "-std=") or vim.startswith(a, "--std=") then
            table.insert(dep_flags, a)
        end
    end

    return {
        compiler    = compiler,
        probe_flags = probe_flags,
        dep_flags   = dep_flags,
    }
end

local function default_compiler_for_ft(ft)
    if ft == "cpp" then
        if vim.env.CXX and vim.env.CXX ~= "" then
            return vim.env.CXX
        end
        if vim.env.CC and vim.env.CC ~= "" then
            return vim.env.CC
        end
        return "c++"
    end
    if vim.env.CC and vim.env.CC ~= "" then
        return vim.env.CC
    end
    return "cc"
end

local function resolve_c_compile_env(bufnr)
    local ft   = vim.bo[bufnr].filetype
    local lang = "c"
    if ft == "cpp" then
        lang = "c++"
    end
    local def_cc = default_compiler_for_ft(ft)

    local buf_name  = vim.api.nvim_buf_get_name(bufnr)
    local start_dir = vim.fn.getcwd()
    local buf_real  = ""
    if buf_name ~= "" then
        buf_real = uv.fs_realpath(buf_name) or vim.fs.normalize(buf_name)
        start_dir = vim.fs.dirname(buf_real)
    end
    start_dir = vim.fs.normalize(start_dir)

    if start_dir == home_dir or start_dir == "/" then
        return {
            root        = start_dir,
            lang        = lang,
            compiler    = def_cc,
            probe_flags = {},
            dep_flags   = {},
            tu_list     = {},
        }
    end

    local cc_json = vim.fs.find("compile_commands.json", { path = start_dir, upward = true, stop = home_dir })[1]
    if cc_json ~= nil then
        local raw = table.concat(vim.fn.readfile(cc_json), "\n")
        local ok_dec, entries = pcall(vim.json.decode, raw)
        if ok_dec and type(entries) == "table" and #entries > 0 then
            local cc_dir  = vim.fs.dirname(cc_json)
            local chosen  = entries[1]
            local tu_list = {}
            for _, entry in ipairs(entries) do
                if type(entry) == "table" and type(entry.file) == "string" then
                    local edir = cc_dir
                    if type(entry.directory) == "string" and entry.directory ~= "" then
                        edir = entry.directory
                    end
                    local fpath    = resolve_rel_path(edir, entry.file)
                    local freal    = uv.fs_realpath(fpath) or fpath
                    local raw_args = entry.arguments
                    if type(raw_args) ~= "table" and type(entry.command) == "string" then
                        raw_args = split_shell_args(entry.command)
                    end
                    if type(raw_args) == "table" then
                        local parsed = parse_compiler_args(raw_args, edir, def_cc)
                        table.insert(tu_list, {
                            file      = freal,
                            compiler  = parsed.compiler,
                            dep_flags = parsed.dep_flags,
                        })
                        if freal == buf_real then
                            chosen = entry
                        end
                    end
                end
            end

            local chosen_dir = cc_dir
            if type(chosen.directory) == "string" and chosen.directory ~= "" then
                chosen_dir = chosen.directory
            end
            local chosen_args = chosen.arguments
            if type(chosen_args) ~= "table" and type(chosen.command) == "string" then
                chosen_args = split_shell_args(chosen.command)
            end
            if type(chosen_args) == "table" then
                local parsed = parse_compiler_args(chosen_args, chosen_dir, def_cc)
                return {
                    root        = cc_dir,
                    lang        = lang,
                    compiler    = parsed.compiler,
                    probe_flags = parsed.probe_flags,
                    dep_flags   = parsed.dep_flags,
                    tu_list     = tu_list,
                }
            end
        end
    end

    local cf_txt = vim.fs.find("compile_flags.txt", {
        path   = start_dir,
        upward = true,
        stop   = home_dir
    })[1]
    if cf_txt ~= nil then
        local cf_dir    = vim.fs.dirname(cf_txt)
        local flag_args = {}
        for _, line in ipairs(vim.fn.readfile(cf_txt)) do
            local trimmed = vim.trim(line)
            if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
                table.insert(flag_args, trimmed)
            end
        end
        local parsed = parse_compiler_args(flag_args, cf_dir, def_cc)
        return {
            root        = cf_dir,
            lang        = lang,
            compiler    = parsed.compiler,
            probe_flags = parsed.probe_flags,
            dep_flags   = parsed.dep_flags,
            tu_list     = {},
        }
    end

    local root = vim.fs.root(bufnr, { ".git" })
    if not root or root == "" or root == home_dir or root == "/" then
        root = start_dir
    else
        root = vim.fs.normalize(root)
    end
    return {
        root        = root,
        lang        = lang,
        compiler    = def_cc,
        probe_flags = {},
        dep_flags   = {},
        tu_list     = {},
    }
end

local function header_tags_file_for_root(root)
    local tags_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "tags")
    return tags_dir, vim.fs.joinpath(tags_dir, vim.fn.sha256(root) .. ".tags")
end

local function probe_compiler_includes(compiler, lang, probe_flags, on_done)
    local cache_key = compiler .. "|" .. lang .. "|" .. table.concat(probe_flags, "|")
    if compiler_inc_cache[cache_key] ~= nil then
        on_done(compiler_inc_cache[cache_key])
        return
    end
    if vim.fn.executable(compiler) ~= 1 then
        on_done({})
        return
    end

    local cmd = { compiler }
    vim.list_extend(cmd, probe_flags)
    vim.list_extend(cmd, { "-E", "-Wp,-v", "-x" .. lang, "/dev/null" })

    vim.system(cmd, { text = true }, function(res)
        vim.schedule(function()
            local dirs = {}
            local seen = {}
            local in_list = false
            for _, line in ipairs(vim.split(res.stderr or "", "\n", { plain = true })) do
                if line:find("#include \"...\" search starts here:", 1, true)
                    or line:find("#include <...> search starts here:", 1, true) then
                    in_list = true
                elseif line:find("End of search list.", 1, true) then
                    in_list = false
                elseif in_list then
                    local raw_dir = vim.trim(line:gsub("%s*%(framework directory%)$", ""))
                    local real_dir = uv.fs_realpath(raw_dir) or vim.fs.normalize(raw_dir)
                    if real_dir ~= "" and not seen[real_dir] and vim.fn.isdirectory(real_dir) == 1 then
                        seen[real_dir] = true
                        table.insert(dirs, real_dir)
                    end
                end
            end
            compiler_inc_cache[cache_key] = dirs
            on_done(dirs)
        end)
    end)
end

local function parse_dep_headers(dep_path, skip_file)
    local ok_read, lines = pcall(vim.fn.readfile, dep_path)
    if not ok_read or #lines == 0 then
        return {}
    end
    local joined = table.concat(lines, "\n"):gsub("\\\r?\n", " ")
    joined = joined:gsub("^_TARGET_:%s*", "")

    local headers = {}
    local cur = {}
    local escaped = false
    for i = 1, #joined do
        local ch = joined:sub(i, i)
        if escaped then
            table.insert(cur, ch)
            escaped = false
        elseif ch == "\\" then
            escaped = true
        elseif ch:match("%s") then
            if #cur > 0 then
                table.insert(headers, table.concat(cur))
                cur = {}
            end
        else
            table.insert(cur, ch)
        end
    end
    if #cur > 0 then
        table.insert(headers, table.concat(cur))
    end

    local out = {}
    for _, h in ipairs(headers) do
        local real = uv.fs_realpath(h) or vim.fs.normalize(h)
        if real ~= "" and real ~= skip_file and vim.fn.filereadable(real) == 1 then
            table.insert(out, real)
        end
    end
    return out
end

autocmd("FileType", {
    group   = augroup("CCompileHeaders", { clear = true }),
    pattern = { "c", "cpp" },
    callback = function(args)
        local bufnr         = args.buf
        local env           = resolve_c_compile_env(bufnr)
        local _, htags_path = header_tags_file_for_root(env.root)

        vim.api.nvim_buf_call(bufnr, function()
            if not vim.tbl_contains(vim.opt_local.tags:get(), htags_path) then
                vim.opt_local.tags:append(htags_path)
            end
        end)

        probe_compiler_includes(env.compiler, env.lang, env.probe_flags, function(dirs)
            if not vim.api.nvim_buf_is_valid(bufnr) or #dirs == 0 then
                return
            end
            vim.api.nvim_buf_call(bufnr, function()
                local new_path = { "." }
                vim.list_extend(new_path, dirs)
                table.insert(new_path, "")
                vim.opt_local.path = new_path
            end)
        end)
    end,
})

vim.api.nvim_create_user_command("TagsHeaders", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local ft    = vim.bo[bufnr].filetype
    if ft ~= "c" and ft ~= "cpp" then
        vim.notify("TagsHeaders only supports C/C++ buffers", vim.log.levels.WARN)
        return
    end
    if vim.fn.executable("ctags") ~= 1 then
        vim.notify("ctags binary not found", vim.log.levels.WARN)
        return
    end

    local env     = resolve_c_compile_env(bufnr)
    if env.root == home_dir or env.root == "/" then
        vim.notify("Refusing to index header tags from $HOME or /", vim.log.levels.WARN)
        return
    end
    local targets = env.tu_list
    if #targets == 0 then
        local buf_path = vim.api.nvim_buf_get_name(bufnr)
        if buf_path == "" then
            vim.notify("Save buffer or add compile_commands.json first", vim.log.levels.WARN)
            return
        end
        local real  = uv.fs_realpath(buf_path) or vim.fs.normalize(buf_path)
        local flags = vim.deepcopy(env.dep_flags)
        local ext   = vim.fn.fnamemodify(real, ":e")
        if ext == "h" or ext == "hpp" or ext == "hh" then
            table.insert(flags, "-x" .. env.lang .. "-header")
        else
            table.insert(flags, "-x" .. env.lang)
        end
        targets = {
            {
                file      = real,
                compiler  = env.compiler,
                dep_flags = flags,
            },
        }
    end

    local tags_dir, htags_path = header_tags_file_for_root(env.root)
    vim.fn.mkdir(tags_dir, "p")

    local seen        = {}
    local pending     = #targets

    local function finish_deps()
        local header_list = vim.tbl_keys(seen)
        if #header_list == 0 then
            vim.notify("No resolved headers found (check compiler/flags)", vim.log.levels.WARN)
            return
        end
        table.sort(header_list)

        if header_tags_job ~= nil then
            vim.fn.jobstop(header_tags_job)
            header_tags_job = nil
        end

        local stamp     = tostring(uv.hrtime())
        local list_path = htags_path .. ".list." .. stamp
        local tmp_tags  = htags_path .. ".tmp." .. stamp
        vim.fn.writefile(header_list, list_path)

        local cmd = {
            "ctags",
            "--languages=C,C++",
            "--guess-language-eagerly",
            "--kinds-C=+px",
            "--kinds-C++=+px",
            "--fields=+iaSl",
            "--extras=+qf",
            "-L",
            list_path,
            "-f",
            tmp_tags,
        }

        local this_job = nil
        this_job = vim.fn.jobstart(cmd, {
            on_exit = function(_, code)
                pcall(uv.fs_unlink, list_path)
                if header_tags_job == this_job then
                    header_tags_job = nil
                end
                if code == 0 then
                    local ok_ren = uv.fs_rename(tmp_tags, htags_path)
                    if ok_ren then
                        if vim.api.nvim_buf_is_valid(bufnr) then
                            vim.api.nvim_buf_call(bufnr, function()
                                if not vim.tbl_contains(vim.opt_local.tags:get(), htags_path) then
                                    vim.opt_local.tags:append(htags_path)
                                end
                            end)
                        end
                        vim.notify("Indexed " .. tostring(#header_list) .. " headers into tags", vim.log.levels.INFO)
                    else
                        pcall(uv.fs_unlink, tmp_tags)
                        vim.notify("Failed to rename header tags file", vim.log.levels.ERROR)
                    end
                else
                    pcall(uv.fs_unlink, tmp_tags)
                    vim.notify("ctags failed on resolved headers", vim.log.levels.ERROR)
                end
            end,
        })
        header_tags_job = this_job
    end

    for _, tu in ipairs(targets) do
        if vim.fn.executable(tu.compiler) ~= 1 then
            pending = pending - 1
            if pending == 0 then
                finish_deps()
            end
        else
            local tmp_dep = vim.fn.tempname() .. ".d"
            local cmd = { tu.compiler }
            vim.list_extend(cmd, tu.dep_flags)
            vim.list_extend(cmd, { "-E", "-M", "-MG", "-MT", "_TARGET_", "-MF", tmp_dep, tu.file })

            vim.system(cmd, { text = true }, function(_)
                vim.schedule(function()
                    for _, h in ipairs(parse_dep_headers(tmp_dep, tu.file)) do
                        if not seen[h] then
                            seen[h] = true
                        end
                    end
                    pcall(uv.fs_unlink, tmp_dep)
                    pending = pending - 1
                    if pending == 0 then
                        finish_deps()
                    end
                end)
            end)
        end
    end
end, { desc = "Index compiler-resolved headers (-M) into tags" })

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
            local line     = vim.fn.expand("<cfile>")
            local file     = line:gsub("%.", "/")
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
    group   = yank_group,
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

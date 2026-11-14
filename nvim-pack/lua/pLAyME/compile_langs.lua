local function compile()
    _G.compile_timings = {}

    vim.cmd("wall")

    local ft = vim.bo.filetype
    local filename = vim.fn.expand("%:t")
    local exec_name = vim.fn.expand("%:t:r")
    -- Resolve symlinks before compiling: nvim-dap sends nvim_buf_get_name()
    -- (which is the REAL path, e.g. /mnt/disk2/mythings/...) to the debug
    -- adapter, but gcc records DW_AT_comp_dir from this compile cwd. If the
    -- buffer was opened via the ~/mythings symlink, codelldb can't match the
    -- breakpoint source and answers "Resolved locations: 0"
    -- (= DapBreakpointRejected on every breakpoint).
    local raw_dir = vim.fn.expand("%:p:h")
    local dir = vim.uv.fs_realpath(raw_dir) or raw_dir
    local file = dir .. "/" .. filename
    local target = dir .. "/" .. exec_name

    local s_file = vim.fn.shellescape(file)
    local s_filename = vim.fn.shellescape(filename)
    local s_target = vim.fn.shellescape(target)
    local s_dir = vim.fn.shellescape(dir)
    local s_class = vim.fn.shellescape(exec_name)

    local perf_base = vim.fn.tempname()
    local perf_script = perf_base .. ".sh"
    local perf_out = perf_base .. ".perf"
    local s_perf_script = vim.fn.shellescape(perf_script)
    local s_perf_out = vim.fn.shellescape(perf_out)

    local wrote_ok = vim.fn.writefile({
        "_perf() {",
        "    _n=$(date +%s%N)",
        string.format('    printf "[%%sms] %%s\\n" "$(( (_n - _t) / 1000000 ))" "$*" >> %s', s_perf_out),
        "    _t=$_n",
        "}",
        "_t=$(date +%s%N)",
    }, perf_script)

    if wrote_ok ~= 0 then
        vim.notify("Failed to write perf script", vim.log.levels.ERROR)
        return
    end

    local perf_fn = string.format(". %s && rm -f %s && ", s_perf_script, s_perf_script)
    local cmd = ""
    local cwd = dir

    local bts = {
        "Makefile",
        "CMakeLists.txt",
        "build.sh",
        "nob.c",
        "Cargo.toml",
    }

    local home_dir = vim.fs.normalize(vim.fn.expand("~"))
    local function find_project_root(start)
        local d = start
        if not d or d == "" then
            return nil, nil
        end
        d = vim.fs.normalize(d)

        while true do
            if d == home_dir or d == "/" then
                break
            end

            for _, m in ipairs(bts) do
                if vim.fn.filereadable(d .. "/" .. m) == 1 then
                    return d, m
                end
            end

            if vim.fn.glob(d .. "/*.csproj") ~= "" then
                return d, "*.csproj"
            end

            local parent = vim.fn.fnamemodify(d, ":h")
            if parent == d then
                break
            end
            d = parent
        end

        return nil, nil
    end

    local root, marker = find_project_root(dir)

    if root and marker then
        cwd = root

        if marker == "build.sh" then
            cmd = perf_fn .. "./build.sh; _rc=$?; _perf 'compilation'; exit $_rc"
        elseif marker == "Makefile" then
            cmd = perf_fn .. "make -B; _rc=$?; _perf 'compilation'; exit $_rc"
        elseif marker == "CMakeLists.txt" then
            cmd = perf_fn .. "mkdir -p build && cd build && cmake .. && cmake --build . -j $(nproc); _rc=$?; _perf 'compilation'; exit $_rc"
        elseif marker == "nob.c" then
            local nob_src = vim.fn.shellescape(root .. "/nob.c")
            local nob_bin = vim.fn.shellescape(root .. "/nob")
            cmd = perf_fn .. string.format(
                "cc -Wall -Wextra -o %s %s; _rc=$?; _perf 'compilation'; if [ $_rc -eq 0 ]; then %s; _rc=$?; _perf 'run'; fi; exit $_rc",
                nob_bin, nob_src, nob_bin
            )
        elseif marker == "Cargo.toml" then
            cmd = perf_fn .. "cargo build --color=always; _rc=$?; _perf 'compilation'; if [ $_rc -eq 0 ]; then cargo run --color=always; _rc=$?; _perf 'run'; fi; exit $_rc"
        elseif marker == "*.csproj" then
            cmd = perf_fn .. "dotnet build; _rc=$?; _perf 'compilation'; if [ $_rc -eq 0 ]; then dotnet run --no-build; _rc=$?; _perf 'run'; fi; exit $_rc"
        end
    elseif ft == "cs" then
        cmd = perf_fn .. string.format(
            "dotnet run --project %s; _rc=$?; if [ $_rc -ne 0 ]; then csc %s; _rc=$?; _perf 'compilation'; if [ $_rc -eq 0 ]; then mono %s; _rc=$?; _perf 'run'; fi; else _perf 'run'; fi; exit $_rc",
            s_dir, s_file, vim.fn.shellescape(target .. ".exe")
        )
    elseif ft == "python" then
        cmd = perf_fn .. string.format("python3 %s; _rc=$?; _perf 'run'; exit $_rc", s_file)
    elseif ft == "php" then
        cmd = perf_fn .. string.format("php %s; _rc=$?; _perf 'run'; exit $_rc", s_file)
    elseif ft == "cpp" or ft == "cc" then
        local out_bin = vim.fn.shellescape("./bin/" .. exec_name)
        cmd = perf_fn .. string.format(
            "cd %s && mkdir -p ./bin && g++ -Wall -Wextra -ggdb -fdiagnostics-color=always -o %s %s; _rc=$?; _perf 'compilation'; if [ $_rc -eq 0 ]; then %s; _rc=$?; _perf 'run'; fi; exit $_rc",
            s_dir, out_bin, s_filename, out_bin
        )
    elseif ft == "c" then
        local out_bin = vim.fn.shellescape("./bin/" .. exec_name)
        cmd = perf_fn .. string.format(
            "cd %s && mkdir -p ./bin && cc -Wall -Wextra -ggdb -fdiagnostics-color=always -o %s %s; _rc=$?; _perf 'compilation'; if [ $_rc -eq 0 ]; then %s; _rc=$?; _perf 'run'; fi; exit $_rc",
            s_dir, out_bin, s_filename, out_bin
        )
    elseif ft == "lua" then
        cmd = perf_fn .. string.format("lua %s; _rc=$?; _perf 'run'; exit $_rc", s_filename)
    elseif ft == "java" then
        local awk_colors = [[awk '{
            gsub(/[^ \t:]+\.java/, "\033[1;33m&\033[0m");
            gsub(/errors|error:/,  "\033[1;31m&\033[0m");
            gsub(/warning:/,       "\033[1;33mwarning:\033[0m");
            gsub(/location/,       "\033[1;35mlocation\033[0m");
            gsub(/symbol/,         "\033[1;34msymbol\033[0m");
            gsub(/:/,              "\033[1;36m:\033[0m");
            gsub(/\^/,             "\033[1;32m^\033[0m"); print
        }']]
        local pkg = nil
        for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, 50, false)) do
            local found_pkg = line:match("^%s*package%s+([%w_%.]+)%s*;")
            if found_pkg then
                pkg = found_pkg
                break
            end
        end
        local fqcn = exec_name
        local class_rel = exec_name .. ".class"
        if pkg ~= nil then
            fqcn = pkg .. "." .. exec_name
            class_rel = pkg:gsub("%.", "/") .. "/" .. exec_name .. ".class"
        end
        local class_file = vim.fn.shellescape("./bin/" .. class_rel)
        local s_fqcn = vim.fn.shellescape(fqcn)
        cmd = perf_fn .. string.format(
            "cd %s && rm -f %s && javac -d ./bin %s 2>&1 | %s; _perf 'compilation'; if [ -f %s ]; then java -cp ./bin %s; _rc=$?; _perf 'run'; exit $_rc; fi",
            s_dir, class_file, s_filename, awk_colors, class_file, s_fqcn
        )
    elseif ft == "rust" then
        cmd = perf_fn .. string.format(
            "rustc --color=always %s -o %s; _rc=$?; _perf 'compilation'; if [ $_rc -eq 0 ]; then %s; _rc=$?; _perf 'run'; fi; exit $_rc",
            s_file, s_target, s_target
        )
    elseif ft == "cabal.haskell" then
        cmd = perf_fn .. "cabal build; _rc=$?; _perf 'compilation'; if [ $_rc -eq 0 ]; then cabal run; _rc=$?; _perf 'run'; fi; exit $_rc"
    elseif ft == "haskell" then
        local hs_out_dir = vim.fn.shellescape(dir .. "/bin/" .. exec_name)
        local hs_bin = vim.fn.shellescape(dir .. "/bin/" .. exec_name .. "/" .. exec_name)
        cmd = perf_fn .. string.format(
            "mkdir -p %s && ghc -dynamic -outputdir %s -o %s %s; _rc=$?; _perf 'compilation'; if [ $_rc -eq 0 ]; then %s; _rc=$?; _perf 'run'; fi; exit $_rc",
            hs_out_dir, hs_out_dir, hs_bin, s_filename, hs_bin
        )
    elseif ft == "sh" then
        if vim.fn.executable(file) == 1 then
            cmd = perf_fn .. string.format("%s; _rc=$?; _perf 'run'; exit $_rc", vim.fn.shellescape("./" .. filename))
        else
            cmd = perf_fn .. string.format("sh %s; _rc=$?; _perf 'run'; exit $_rc", vim.fn.shellescape(filename))
        end
    else
        vim.fn.delete(perf_script)
        print("No runner for: " .. ft)
        return
    end

    local old_bufs = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.b[buf].is_compile_output and vim.api.nvim_buf_is_valid(buf) then
            table.insert(old_bufs, buf)
        end
    end

    vim.cmd("botright 10new")
    local new_buf = vim.api.nvim_get_current_buf()
    vim.b[new_buf].is_compile_output = true
    vim.b[new_buf].compile_dir = dir

    for _, old_buf in ipairs(old_bufs) do
        if old_buf ~= new_buf and vim.api.nvim_buf_is_valid(old_buf) then
            pcall(vim.api.nvim_buf_delete, old_buf, { force = true })
        end
    end

    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = new_buf,
        callback = function()
            _G.compile_timings = {}
            vim.fn.delete(perf_script)
            vim.fn.delete(perf_out)
        end,
    })

    _G.compile_timings = {}
    vim.fn.delete(perf_out)

    local job_id = vim.fn.jobstart(cmd, {
        cwd = cwd,
        term = true,
        env = {
            FORCE_COLOR = "1",
            CLICOLOR_FORCE = "1",
            PYTHONUNBUFFERED = "1",
        },
        on_exit = function(_, _, _)
            local ok, lines = pcall(vim.fn.readfile, perf_out)
            if ok then
                for _, line in ipairs(lines) do
                    local ms, label = line:match("%[(%d+)ms%]%s+(.+)")
                    if ms and label then
                        _G.compile_timings[label] = ms .. "ms"
                    end
                end
            end
            vim.fn.delete(perf_script)
            vim.fn.delete(perf_out)
        end,
    })

    if job_id <= 0 then
        vim.fn.delete(perf_script)
        vim.fn.delete(perf_out)
        vim.notify("Failed to start compile job", vim.log.levels.ERROR)
        return
    end

    vim.cmd("startinsert")

    vim.keymap.set("t", "jk", "<C-\\><C-n>", { buffer = new_buf, noremap = true, silent = true })
    vim.keymap.set("n", "q", ":bd!<CR>", { buffer = new_buf, noremap = true, silent = true })
end

function _G.compile_perf_component()
    local t = _G.compile_timings or {}
    if not t.compilation and not t.run then return "" end
    local parts = {}
    if t.compilation then parts[#parts + 1] = " " .. t.compilation end
    if t.run then parts[#parts + 1] = " " .. t.run end
    return table.concat(parts, " ") .. " |"
end

vim.keymap.set("n", "<leader>r", compile, { desc = "Clean Build and run" })

local function goto_error_line()
    local raw = vim.api.nvim_get_current_line()
    local err = raw:gsub("\x1b%[[%d;]*[a-zA-Z]", "")

    local file, err_line = err:match("^%s*lua: ([^:]+):(%d+):")

    if not file then
        -- C/GCC: hash_table.c:86:1: or hash_table.c:86:
        file, err_line = err:match("^%s*([^:]+):(%d+):%d*:")
    end
    if not file then
        -- Java: iostream.java:41: error:
        file, err_line = err:match("^%s*([^:]+):(%d+):%s+error:")
    end
    if not file then
        -- Python: File "/path/main.py", line 16
        file, err_line = err:match('^%s*File "([^"]+)", line (%d+)')
    end
    if not file then
        -- Bash: ./script.sh: line 3: or script.sh: line 3:
        file, err_line = err:match("^%s*([^:]+): line (%d+):")
    end

    if not file or not err_line then
        return
    end

    file = vim.trim(file)
    local line_num = tonumber(err_line)
    if not line_num then
        return
    end

    local uv = vim.uv
    if not uv then
        uv = vim.loop
    end

    local buf = vim.api.nvim_get_current_buf()
    local dir = vim.b[buf].compile_dir

    if file:sub(1, 1) ~= "/" then
        if dir and dir ~= "" then
            local rel_candidate = vim.fs.normalize(dir .. "/" .. file)
            local stat = uv.fs_stat(rel_candidate)
            if stat then
                file = rel_candidate
            else
                file = vim.fs.normalize(file)
            end
        else
            file = vim.fs.normalize(file)
        end
    else
        file = vim.fs.normalize(file)
    end

    if vim.fn.filereadable(file) ~= 1 then
        vim.notify("Error target not readable: " .. file, vim.log.levels.WARN)
        return
    end

    local target_win = nil
    local prev_win = vim.fn.win_getid(vim.fn.winnr("#"))
    if prev_win ~= 0 and vim.api.nvim_win_is_valid(prev_win) then
        local prev_buf = vim.api.nvim_win_get_buf(prev_win)
        if not vim.b[prev_buf].is_compile_output and vim.bo[prev_buf].buftype == "" then
            target_win = prev_win
        end
    end

    if target_win == nil then
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local win_buf = vim.api.nvim_win_get_buf(win)
            if not vim.b[win_buf].is_compile_output and vim.bo[win_buf].buftype == "" then
                target_win = win
                break
            end
        end
    end

    if target_win ~= nil then
        vim.api.nvim_set_current_win(target_win)
    else
        vim.cmd("aboveleft split")
    end

    vim.cmd("edit " .. vim.fn.fnameescape(file))
    pcall(vim.api.nvim_win_set_cursor, 0, { line_num, 0 })
end

vim.keymap.set("n", "<leader>er", goto_error_line, { desc = "goto [ER]ror line" })

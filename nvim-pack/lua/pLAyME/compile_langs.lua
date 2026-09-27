local function compile()
    _G.compile_timings = {}

    vim.cmd("wall")

    local ft = vim.bo.filetype
    local file = vim.fn.expand("%:p")
    local filename = vim.fn.expand("%:t")
    local target = vim.fn.expand("%:p:r")
    local dir = vim.fn.expand("%:p:h")
    local exec_name = vim.fn.expand("%:t:r")

    local s_file = vim.fn.shellescape(file)
    local s_filename = vim.fn.shellescape(filename)
    local s_target = vim.fn.shellescape(target)
    local s_dir = vim.fn.shellescape(dir)
    local s_class = vim.fn.shellescape(exec_name)

    local perf_script = string.format("/tmp/%s", exec_name)

    vim.fn.writefile({
        '_perf() {',
        '    local _n=$(date +%s%N)',
        '    printf "[%sms] %s\\n" "$(( (_n - _t) / 1000000 ))" "$*" >> '.. perf_script ..'.perf',
        '    _t=$_n',
        '}',
        '_t=$(date +%s%N)',
    }, perf_script)

    local perf_fn = string.format(". %s && rm %s && ", perf_script, perf_script)
    local cmd = ""
    local cwd = dir

    local bts = {
        "Makefile",
        "CMakeLists.txt",
        "build.sh",
        "nob.c",
        "Cargo.toml"
    } -- build_tools

    local function find_project_root(start, depth_max)
        local d = start
        if not d or d == "" then return nil, nil end

        local outermost_root = nil
        local outermost_marker = nil

        while true do
            -- 1. Check for build tool files
            for _, m in ipairs(bts) do
                if vim.fn.filereadable(d .. "/" .. m) == 1 then
                    outermost_root = d
                    outermost_marker = m
                    break -- Move up to see if an even higher parent has a build tool
                end
            end

            -- 2. Check for .csproj files
            if vim.fn.glob(d .. "/*.csproj") ~= "" then
                outermost_root = d
                outermost_marker = "*.csproj"
            end

            -- Move to parent directory
            local parent = vim.fn.fnamemodify(d, ":h")
            if parent == d then break end -- Reached '/'
            d = parent
        end

        return outermost_root, outermost_marker
    end

    local root, marker = find_project_root(dir)

    if root and marker then
        cwd = root -- The top-level folder (e.g. prog/) is always the working directory
        local s_root = vim.fn.shellescape(root)

        if marker == "build.sh" then
            cmd = perf_fn .. "_perf 'compilation' && ./build.sh"
        elseif marker == "Makefile" then
            cmd = perf_fn .. "_perf 'compilation' && make -B"
        elseif marker == "CMakeLists.txt" then
            cmd = perf_fn .. "_perf 'compilation' && mkdir -p build && cd build && cmake .. && cmake --build . -j $(nproc)"
        elseif marker == "nob.c" then
            local nob_src = vim.fn.shellescape(root .. "/nob.c")
            local nob_bin = vim.fn.shellescape(root .. "/nob")
            cmd = perf_fn .. string.format(
                "_perf 'compilation' && cc -Wall -Wextra -o %s %s && _perf 'run' && %s",
                nob_bin, nob_src, nob_bin
            )
        elseif marker == "Cargo.toml" then
            cmd = "cargo run --color=always"
        elseif marker == "*.csproj" then
            cmd = "dotnet run"
        end
    elseif ft == "cs" then   elseif ft == "cs" then    elseif ft == "cs" then    elseif ft == "cs" then
        cmd = perf_fn .. string.format("_perf 'compilation' && dotnet run --project %s || (csc %s && _perf 'run' && mono %s.exe)",
        s_dir, s_file, s_target)
    elseif ft == "python" then
        cmd = perf_fn .. string.format("_perf 'run' && python3 %s", s_file)
    elseif ft == "php" then
        cmd = perf_fn .. string.format("_perf 'run' && php %s", s_file)
    elseif ft == "cpp" or ft == "cc" then
        cmd = perf_fn .. string.format("_perf 'compilation' && cd %s && mkdir -p ./bin && g++ -Wall -Wextra -ggdb -fdiagnostics-color=always -o ./bin/%s %s && _perf 'run' && ./bin/%s",
        s_dir, s_class, s_filename, s_class)
    elseif ft == "c" then
        cmd = perf_fn .. string.format("_perf 'compilation' && cd %s && mkdir -p ./bin && cc -Wall -Wextra -ggdb -fdiagnostics-color=always -o ./bin/%s %s && _perf 'run' && ./bin/%s",
        s_dir, s_class, s_filename, s_class)
    elseif ft == "lua" then
        cmd = perf_fn .. string.format("_perf 'run' && lua %s", s_filename)
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
        cmd = perf_fn .. string.format("cd %s && rm -f ./bin/%s.class && _perf 'compilation' && javac -d ./bin %s 2>&1 | %s ; if [ -f ./bin/%s.class ]; then _perf 'run' && java -cp ./bin %s; fi",
        s_dir, s_class, s_filename, awk_colors, s_class, s_class)
    elseif ft == "rust" then
        cmd = perf_fn .. string.format("_perf 'compilation' && rustc --color=always %s -o %s && _perf 'run' && %s/%s",
        s_file, s_target, s_dir, s_class)
    elseif ft == "cabal.haskell" then
        cmd = "cabal run"
    elseif ft == "haskell" then
        cmd = perf_fn .. string.format("_perf 'compilation' && mkdir -p %s/bin/%s && ghc -dynamic -outputdir %s/bin/%s -o %s/bin/%s/%s %s && _perf 'run' && %s/bin/%s/%s",
        s_dir, s_class, s_dir, s_class, s_dir, s_class, s_class, s_filename, s_dir, s_class, s_class)
        -- cmd = string.format("runghc %s", s_filename)
    elseif ft == "sh" then
        cmd = perf_fn .. string.format("_perf 'run' && ./%s", s_filename)
    else
        print("No runner for: " .. ft)
        return
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.b[buf].is_compile_output then
            vim.api.nvim_win_close(win, true)
        end
    end

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.b[buf].is_compile_output and vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end

    vim.cmd("botright 10new")
    local new_buf = vim.api.nvim_get_current_buf()
    vim.b[new_buf].is_compile_output = true
    vim.b[new_buf].compile_dir = dir

    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = new_buf,
        callback = function()
            _G.compile_timings = {}
        end,
    })

    _G.compile_timings = {}
    vim.fn.delete(perf_script .. ".perf")

    vim.fn.jobstart(cmd, {
        cwd = cwd,
        term = true,
        env = {
            FORCE_COLOR = "1",
            CLICOLOR_FORCE = "1",
            PYTHONUNBUFFERED = "1"
        },
        on_exit = function(_, _, _)
            local ok, lines = pcall(vim.fn.readfile, perf_script .. ".perf")
            if ok then
                for _, line in ipairs(lines) do
                    local ms, label = line:match("%[(%d+)ms%]%s+(.+)")
                    if ms and label then
                        _G.compile_timings[label] = ms .. "ms"
                    end
                end
            end
            vim.fn.delete(perf_script .. ".perf")
        end
    })

    vim.cmd("startinsert")

    vim.keymap.set("t", "jk", "<C-\\><C-n>", { buffer = new_buf, noremap = true, silent = true })
    vim.keymap.set("n", "q", ":bd!<CR>",     { buffer = new_buf, noremap = true, silent = true })
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

    if not file then
        return
    end

    local stat = (vim.uv or vim.loop).fs_stat
    local buf = vim.api.nvim_get_current_buf()
    local dir = vim.b[buf].compile_dir

    if dir and file:sub(1, 1) ~= "/" and not stat(file) then
        file = dir .. "/" .. file
    end

    vim.cmd("wincmd p")
    vim.cmd("e " .. vim.fn.fnameescape(file))
    pcall(vim.api.nvim_win_set_cursor, 0, { tonumber(err_line), 0 })
end

vim.keymap.set("n", "<leader>er", goto_error_line, { desc = "goto [ER]ror line" })

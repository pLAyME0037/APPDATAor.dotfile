local function compile()
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
        '    printf "[%sms] %s\\n" "$(( (_n - _t) / 1000000 ))" "$*"',
        '    _t=$_n',
        '}',
        '_t=$(date +%s%N)',
    }, perf_script)

    local perf_fn = string.format(". %s && rm %s && ", perf_script, perf_script)
    local cmd = ""
    local cwd = dir

    if vim.fn.filereadable(dir .. "/Makefile") == 1 then
        cmd = "make"
    elseif vim.fn.filereadable(dir .. "/CMakeLists.txt") == 1 then
        cmd = "mkdir -p build && cd build && cmake .. && cmake --build . -j $(nproc)"
    elseif vim.fn.filereadable(dir .. "/build.sh") == 1 then
        cmd = "./build.sh"
    elseif vim.fn.filereadable(dir .. "/nob.c") == 1 then
        local nob_bin = dir .. "/bin/nob"
        local nob_src = dir .. "/nob.c"
-- do not use nob_cmd_run_async_and_reset, their not output
        if vim.fn.filereadable(nob_bin) ~= 1
        or vim.fn.getftime(nob_src) < vim.fn.getftime(nob_bin) then
            cmd = string.format("%s/bin/nob", s_dir)
        else
            cmd = string.format("mkdir -p %s/bin && cc -o %s/bin/nob %s/nob.c && %s/bin/nob",
                                s_dir, s_dir, s_dir, s_dir)
        end
    elseif vim.fn.filereadable(dir .. "/Cargo.toml") == 1 then
        cmd = "cargo run --color=always"
        cwd = dir
    elseif vim.fn.glob(dir .. "/*.csproj") ~= "" then
        cmd = "dotnet run"
        cwd = dir
    elseif ft == "cs" then
        cmd = perf_fn .. string.format("_perf 'compilation' && dotnet run --project %s || (csc %s && _perf 'run time' && mono %s.exe)",
                                       s_dir, s_file, s_target)
    elseif ft == "python" then
        cmd = perf_fn .. string.format("_perf 'run time' && python3 %s", s_file)
    elseif ft == "php" then
        cmd = perf_fn .. string.format("_perf 'run time' && php %s", s_file)
    elseif ft == "cpp" or ft == "cc" then
        cmd = perf_fn .. string.format("_perf 'compilation' && cd %s && mkdir -p ./bin && g++ -Wall -Wextra -ggdb -fdiagnostics-color=always -o ./bin/%s %s && _perf 'run time' && ./bin/%s",
                                       s_dir, s_class, s_filename, s_class)
    elseif ft == "c" then
        cmd = perf_fn .. string.format("_perf 'compilation' && cd %s && mkdir -p ./bin && cc -Wall -Wextra -ggdb -fdiagnostics-color=always -o ./bin/%s %s && _perf 'run time' && ./bin/%s",
                                       s_dir, s_class, s_filename, s_class)
    elseif ft == "lua" then
        cmd = perf_fn .. string.format("_perf 'run time' && lua %s", s_filename)
    elseif ft == "java" then
        local awk_colors = [[awk '{
            gsub(/[^ \t:]+\.java/, "\033[1;33m&\033[0m");
            gsub(/errors|error:/, "\033[1;31m&\033[0m");
            gsub(/warning:/, "\033[1;33mwarning:\033[0m");
            gsub(/symbol/, "\033[1;34msymbol\033[0m");
            gsub(/location/, "\033[1;35mlocation\033[0m");
            gsub(/:/, "\033[1;36m:\033[0m");
            gsub(/\^/, "\033[1;32m^\033[0m"); print
        }']]
        cmd = perf_fn .. string.format("cd %s && rm -f ./bin/%s.class && _perf 'compilation' && javac -d ./bin %s 2>&1 | %s ; if [ -f ./bin/%s.class ]; then _perf 'run time' && java -cp ./bin %s; fi",
                                       s_dir, s_class, s_filename, awk_colors, s_class, s_class)
    elseif ft == "rust" then
        cmd = perf_fn .. string.format("_perf 'compilation' && rustc --color=always %s -o %s && _perf 'run time' && %s/%s",
                                       s_file, s_target, s_dir, s_class)
    elseif ft == "cabal.haskell" then
        cmd = "cabal run"
    elseif ft == "haskell" then
        cmd = perf_fn .. string.format("_perf 'compilation' && mkdir -p %s/bin/%s && ghc -dynamic -outputdir %s/bin/%s -o %s/bin/%s/%s %s && _perf 'run time' && %s/bin/%s/%s",
            s_dir, s_class, s_dir, s_class, s_dir, s_class, s_class, s_filename, s_dir, s_class, s_class)
        -- cmd = string.format("runghc %s", s_filename)
    elseif ft == "sh" then
        cmd = perf_fn .. string.format("_perf 'run time' && ./%s", s_filename)
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

    vim.fn.jobstart(cmd, {
        cwd = cwd,
        term = true,
        env = {
            FORCE_COLOR = "1",
            CLICOLOR_FORCE = "1",
            PYTHONUNBUFFERED = "1"
        }
    })

    vim.cmd("startinsert")

    vim.keymap.set("t", "jk", "<C-\\><C-n>", { buffer = new_buf, noremap = true, silent = true })
    vim.keymap.set("n", "q", ":bd!<CR>",     { buffer = new_buf, noremap = true, silent = true })
end

vim.keymap.set("n", "<leader>r", compile, { desc = "Clean Build and run time" })

local function goto_error_line()
    local raw = vim.api.nvim_get_current_line()
    local err = raw:gsub("\x1b%[%d;]*m", "")
    local file, err_line = err:match("^lua: ([^:]+):(%d+):")

    if not file then
        -- try C/GCC format: hash_table.c:86:1:
        file, err_line = err:match("^([^:]+):(%d+):%d+:")
    end
    if not file then
        -- try Java format: iostream.java:41: error:
        file, err_line = err:match("^([^:]+):(%d+): error:")
    end
    if not file then
        -- try Python format: File "/home/user/py_generator/main.py", line 16
        file, err_line = err:match('^%s*File "([^"]+)"/", line (%d+)')
    end

    if not file then
        -- ./2_functor.sh: line 3: local: can only be used in a function
        file, err_line = err:match("^./([^:]+): line (%d+):")
    end

    local buf = vim.api.nvim_get_current_buf()
    local dir = vim.b[buf].compile_dir

    if dir and file:sub(1, 1) ~= "/" then
        file = dir .. "/" .. file
    end

    if file then
        vim.cmd("wincmd p")
        vim.cmd("e " .. file)
        vim.cmd(":" .. err_line)
    end
end

vim.keymap.set("n", "<leader>er", goto_error_line, { desc = "goto [ER]ror line" })


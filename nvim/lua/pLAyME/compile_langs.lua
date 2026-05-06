local function compile()
    vim.cmd("wall")

    local ft = vim.bo.filetype
    local file = vim.fn.expand("%:p")
    local filename = vim.fn.expand("%:t")
    local target = vim.fn.expand("%:p:r")
    local dir = vim.fn.expand("%:p:h")
    local class_name = vim.fn.expand("%:t:r")

    local s_file = vim.fn.shellescape(file)
    local s_filename = vim.fn.shellescape(filename)
    local s_target = vim.fn.shellescape(target)
    local s_dir = vim.fn.shellescape(dir)
    local s_class = vim.fn.shellescape(class_name)

    local cmd = ""
    local cwd = dir

    if vim.fn.filereadable(dir .. "/Makefile") == 1 then
        cmd = "make"
    elseif vim.fn.filereadable(dir .. "/CMakeLists.txt") == 1 then
        cmd = "mkdir -p build && cd build && cmake .. && cmake --build . -j $(nproc)"
    elseif vim.fn.filereadable(dir .. "/build.sh") == 1 then
        cmd = "./build.sh"
    elseif vim.fn.filereadable(dir .. "/Cargo.toml") == 1 then
        cmd = "cargo run --color=always"
        cwd = dir
    elseif vim.fn.glob(dir .. "/*.csproj") ~= "" then
        cmd = "dotnet run"
        cwd = dir
    elseif ft == "cs" then
        cmd = string.format("dotnet run --project %s || (csc %s && mono %s.exe)",
                            s_dir, s_file, s_target)
    elseif ft == "python" then
        cmd = string.format("python3 %s", s_file)
    elseif ft == "php" then
        cmd = string.format("php %s", s_file)
    elseif ft == "cpp" then
        cmd = string.format("cd %s && mkdir -p ./bin && g++ -Wall -Wextra -ggdb -fdiagnostics-color=always -o ./bin/%s %s && ./bin/%s",
                            s_dir, s_class, s_filename, s_class)
    elseif ft == "c" then
        cmd = string.format("cd %s && mkdir -p ./bin && gcc -Wall -Wextra -ggdb -fdiagnostics-color=always -o ./bin/%s %s && ./bin/%s",
                            s_dir, s_class, s_filename, s_class)
    elseif ft == "java" then
        local awk_colors = [[awk '{
            gsub(/error:/, "\033[1;31merror:\033[0m");
            gsub(/warning:/, "\033[1;33mwarning:\033[0m");
            gsub(/\^/, "\033[1;32m^\033[0m"); print
        }']]
        cmd = string.format("cd %s && rm -f ./bin/%s.class && javac -d ./bin %s 2>&1 | %s ; if [ -f ./bin/%s.class ]; then java -cp ./bin %s; fi",
                            s_dir, s_class, s_filename, awk_colors, s_class, s_class)
    elseif ft == "rust" then
        cmd = string.format("rustc --color=always %s -o %s && %s/%s",
                            s_file, s_target, s_dir, s_class)
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
    vim.keymap.set("n", "q", ":bd!<CR>", { buffer = new_buf, noremap = true, silent = true })
end

vim.keymap.set("n", "<leader>r", compile, { desc = "Clean Build and Run" })

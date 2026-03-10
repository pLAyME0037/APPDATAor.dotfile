local function compile()
    vim.cmd("write")

    local ft = vim.bo.filetype
    local file = vim.fn.expand("%:p")
    local filename = vim.fn.expand("%:t")
    local target = vim.fn.expand("%:p:r")
    local dir = vim.fn.expand("%:p:h")
    local class_name = vim.fn.expand("%:t:r")

    -- Shellescape everything for safety
    local s_file = vim.fn.shellescape(file)
    local s_filename = vim.fn.shellescape(filename)
    local s_target = vim.fn.shellescape(target)
    local s_dir = vim.fn.shellescape(dir)

    local cmd = ""

    -- 1. PROJECT DETECTION
    if vim.fn.filereadable("Makefile") == 1 then
        cmd = string.format("make && %s", s_target)
    elseif vim.fn.filereadable("build.sh") == 1 then
        cmd = string.format("./build.sh && %s", s_target)
    elseif vim.fn.filereadable("Cargo.toml") == 1 then
        cmd = "cargo run --color=always"
    elseif vim.fn.glob("*.csproj") ~= "" then
        cmd = "dotnet run"
    -- 2. SINGLE FILE RUNNERS
    elseif ft == "cs" then
        cmd = string.format("dotnet run --project %s || (csc %s && mono %s.exe)", s_dir, s_file, s_target)
    elseif ft == "python" then
        cmd = string.format("python3 %s", s_file)
    elseif ft == "php" then
        cmd = string.format("php %s", s_file)
    elseif ft == "cpp" then
        cmd = string.format("g++ -Wall -Wextra -ggdb -fdiagnostics-color=always %s -o %s && %s", s_file, s_target, s_target)
    elseif ft == "c" then
        cmd = string.format("gcc -Wall -Wextra -ggdb -fdiagnostics-color=always %s -o %s && %s", s_file, s_target, s_target)
    elseif ft == "java" then
        local awk_colors = [[awk '{ gsub(/error:/, "\033[1;31merror:\033[0m"); gsub(/warning:/, "\033[1;33mwarning:\033[0m"); gsub(/\^/, "\033[1;32m^\033[0m"); print }']]
        cmd = string.format("cd %s && rm -f %s.class && javac %s 2>&1 | %s ; if [ -f %s.class ]; then java %s; fi",
            s_dir, class_name, s_filename, awk_colors, class_name, class_name)
        -- cmd = string.format("cd %s && javac %s && java %s", s_dir, s_filename, class_name)
    elseif ft == "rust" then
        cmd = string.format("rustc --color=always %s -o %s && %s", s_file, s_target, s_target)
    else
        print("No runner for: " .. ft)
        return
    end

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
            local ok, is_compile = pcall(vim.api.nvim_buf_get_var, buf, "is_compile_output")
            if ok and is_compile then
                vim.api.nvim_buf_delete(buf, { force = true })
            end
        end
    end

    vim.cmd("botright split")
    vim.cmd("enew")
    local new_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_var(new_buf, "is_compile_output", true)
    vim.fn.termopen(cmd, {
        env = {
            FORCE_COLOR = "1",
            CLICOLOR_FORCE = "1",
            PYTHONUNBUFFERE = "1"
        }
    })
    pcall(vim.api.nvim_buf_set_name, new_buf, "CompileOutput")
    vim.cmd("resize 10")
    vim.cmd("startinsert")

    vim.api.nvim_buf_set_keymap(new_buf, "t", "jk", [[<C-\><C-n>]], {
        noremap = true, silent = true
    })
    vim.api.nvim_buf_set_keymap(new_buf, "n", "q", ":bd!<CR>", {
        noremap = true, silent = true
    })
end

vim.keymap.set('n', '<leader>r', compile, { desc = "Clean Build and Run" })

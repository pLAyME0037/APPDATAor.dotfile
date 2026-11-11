local opts = { noremap = true, silent = true }

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.api.nvim_set_keymap("n", "<leader>tf", "<Plug>PlenaryTestFile",
                        { noremap = false, silent = false })

vim.keymap.set("i", "jk", "<Esc>")
vim.keymap.set("n", "J", "mzJ`z")

local tmux_dirs = {
    h = "L",
    j = "D",
    k = "U",
    l = "R",
}

local function try_tmux(dir)
    local orig = vim.fn.winnr()
    vim.cmd("wincmd " .. dir)
    if vim.fn.winnr() == orig then
        local tmux_flag = tmux_dirs[dir]
        if tmux_flag ~= nil then
            vim.fn.system("tmux select-pane -" .. tmux_flag)
        end
    end
end

local function try_quickfix_or_tmux(dir)
    local qf = vim.fn.getqflist({ size = 0 })
    local qfsize = 0
    if type(qf) == "table" and type(qf.size) == "number" then
        qfsize = qf.size
    end

    if qfsize > 0 then
        local cmd = "cnext"
        if dir == "j" then
            cmd = "cprev"
        end
        local ok = pcall(vim.cmd, cmd .. " | zz")
        if not ok then
            try_tmux(dir)
        end
    else
        try_tmux(dir)
    end
end

-- Window navigation & Tmux integration
vim.keymap.set("n", "<C-h>", function() try_tmux("h") end, { desc = "Window left / Tmux left" })
vim.keymap.set("n", "<C-l>", function() try_tmux("l") end, { desc = "Window right / Tmux right" })
vim.keymap.set("n", "<C-j>", function() try_quickfix_or_tmux("j") end, { desc = "QF prev / Window down / Tmux down" })
vim.keymap.set("n", "<C-k>", function() try_quickfix_or_tmux("k") end, { desc = "QF next / Window up / Tmux up" })

vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "<C-c>", ":nohl<CR>", { desc = "Clear search hl", silent = true })
vim.keymap.set("n", "<C-s>", ":wa<CR>")

vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

vim.keymap.set("v", "<", "<gv", opts)
vim.keymap.set("v", ">", ">gv", opts)

vim.keymap.set("n", "=ap", "ma=ap'a")

vim.keymap.set("n", "gd", "<C-]>", { desc = "Tags: Jump to Definition" })
vim.keymap.set("n", "gD", "g<C-]>", { desc = "Tags: Select Definition" })
vim.keymap.set("n", "<leader>b", "<C-t>", { desc = "Tags: Jump Back" })

vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)
vim.keymap.set("n", "<leader>lt", function()
    vim.cmd([[ PlenaryBustedFile % ]])
end)

vim.keymap.set("n", "<leader>a", "mzggVG")

vim.keymap.set("x", "<leader>p", [["_dP]])
vim.keymap.set("v", "p", '"_dP', opts)

vim.keymap.set("n", "tuc", "gUw")
vim.keymap.set("n", "tlc", "guw")

vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

vim.keymap.set({ "n", "v" }, "<leader>d", '"_d')

vim.keymap.set("n", "Q", "<nop>")

vim.keymap.set("n", "<M-w>", "<C-w>w", { desc = "Cycle Split Windows" })

vim.keymap.set("n", "<leader>pb", "<C-^>", { desc = "Switch to Previous Buffer" })

vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>")
vim.keymap.set("n", "<M-h>", "<cmd>silent !tmux-sessionizer -s 0 --vsplit<CR>")
vim.keymap.set("n", "<M-H>", "<cmd>silent !tmux neww tmux-sessionizer -s 0<CR>")

vim.keymap.set("n", "<leader>k", "<cmd>lNext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>lprevious<CR>zz")

vim.keymap.set("n", "<leader>ls", "<cmd>!pwd && ls -laFh --group-directories-first<CR>", { silent = true })
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })
vim.keymap.set("n", "<leader>nl", "082lF i<CR><Esc>")

vim.keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically." })
vim.keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally." })
vim.keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make split equal size." })

vim.keymap.set("n", "<leader>fp", function()
    local filePath = vim.fn.expand("%:~")
    vim.fn.setreg("+", filePath)
    print("File path copied to clipboard: " .. filePath)
end, { desc = "Copy file path to clipboard." })

vim.keymap.set("n", "<leader>u", function()
    vim.cmd.packadd("nvim.undotree")
    require("undotree").open()
end, { desc = "Toggle builtin undo tree." })

vim.keymap.set("n", "<leader>ee", "oif err != nil {<CR>}<Esc>Oreturn err<Esc>")
vim.keymap.set("n", "<leader>ea", 'oassert.NoError(err, "")<Esc>F";a')
vim.keymap.set("n", "<leader>ef", 'oif err != nil {<CR>}<Esc>Olog.Fatalf("error: %s\\n", err.Error())<Esc>jj')
vim.keymap.set("n", "<leader>el", 'oif err != nil {<CR>}<Esc>O.logger.Error("error", "error", err)<Esc>F.;i')

-- ============================================================================
-- Spilt Window Buffer & Resize
-- ============================================================================
local zoomed = false
local prev_winwidth = nil
local prev_winheight = nil

vim.keymap.set("n", "<leader>sm", function()
    if zoomed then
        if prev_winwidth then vim.api.nvim_win_set_width(0, prev_winwidth) end
        if prev_winheight then vim.api.nvim_win_set_height(0, prev_winheight) end
        zoomed = false
    else
        prev_winwidth = vim.api.nvim_win_get_width(0)
        prev_winheight = vim.api.nvim_win_get_height(0)
        vim.cmd("wincmd |")
        vim.cmd("wincmd _")
        zoomed = true
    end
end, { desc = "Toggle split zoom." })

local function resize_split(count, op)
    local times = 5
    if count > 0 then
        times = count
    end
    for _ = 1, times do
        if op == "inc_h" then
            vim.cmd("wincmd +")
        elseif op == "dec_h" then
            vim.cmd("wincmd -")
        elseif op == "inc_w" then
            vim.cmd("wincmd >")
        elseif op == "dec_w" then
            vim.cmd("wincmd <")
        end
    end
end

vim.keymap.set("n", "<leader>s]", function() resize_split(vim.v.count, "inc_h") end, { desc = "Increase split height." })
vim.keymap.set("n", "<leader>s[", function() resize_split(vim.v.count, "dec_h") end, { desc = "Decrease split height." })
vim.keymap.set("n", "<leader><", function() resize_split(vim.v.count, "inc_w") end, { desc = "Increase split width." })
vim.keymap.set("n", "<leader>>", function() resize_split(vim.v.count, "dec_w") end, { desc = "Decrease split width." })
vim.keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split." })

-- ============================================================================
-- Align Pattern
-- ============================================================================
local function align_to_char()
    local char = vim.fn.input("Align to character: ")
    if char == "" then return end

    local start_line = vim.fn.line("'<")
    local end_line = vim.fn.line("'>")
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

    local max_pos = 0
    for _, line in ipairs(lines) do
        local pos = line:find(char, 1, true)
        if pos and pos > max_pos then max_pos = pos end
    end

    local new_lines = {}
    for _, line in ipairs(lines) do
        local pos = line:find(char, 1, true)
        if pos then
            local before = line:sub(1, pos - 1):gsub("%s+$", "")
            local after = line:sub(pos)
            local padding = string.rep(" ", max_pos - #before - 1)
            table.insert(new_lines, before .. padding .. after)
        else
            table.insert(new_lines, line)
        end
    end

    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, new_lines)
end

vim.keymap.set("v", "<leader>a=", align_to_char, { desc = "Align selection to char" })

-- ============================================================================
-- Show Definition without LSP
-- ============================================================================
local function extract_tag_snippet(tag, max_lines)
    local target_path = vim.fs.normalize(tag.filename)
    if vim.fn.filereadable(target_path) ~= 1 then
        return nil
    end

    local file_lines = vim.fn.readfile(target_path)
    if #file_lines == 0 then
        return nil
    end

    local target_line = nil

    if tag.cmd ~= nil then
        local raw_cmd = tag.cmd
        if raw_cmd:match("^%d+$") then
            target_line = tonumber(raw_cmd)
        else
            local pat = raw_cmd:gsub("^/%^?", ""):gsub("%$?/$", "")
            for idx, line in ipairs(file_lines) do
                if line:find(pat, 1, true) then
                    target_line = idx
                    break
                end
            end
        end
    end

    if target_line == nil then
        return nil
    end

    -- 1. Scan backward for doc comments (up to 6 lines)
    local doc_start = target_line
    for i = target_line - 1, math.max(1, target_line - 6), -1 do
        local trimmed = vim.trim(file_lines[i])
        local is_comment = false
        if trimmed:match("^//") then is_comment = true end
        if trimmed:match("^/%*") then is_comment = true end
        if trimmed:match("^%*") then is_comment = true end
        if trimmed:match("^#") then is_comment = true end
        if trimmed:match('^"""') then is_comment = true end
        if trimmed:match("^'''") then is_comment = true end
        if trimmed:match("^%-%-") then is_comment = true end

        if is_comment then
            doc_start = i
        else
            break
        end
    end

    -- 2. Scan forward for full signature ending at { or ; or : (up to max_lines)
    local code_end = target_line
    local limit = math.min(#file_lines, target_line + max_lines)
    for j = target_line, limit do
        code_end = j
        local line = file_lines[j]
        if line:find("{", 1, true) then break end
        if line:find(";", 1, true) then break end
        if line:find(":", 1, true) and not line:find("::", 1, true) then break end
    end

    local snippet = {}
    for k = doc_start, code_end do
        table.insert(snippet, file_lines[k])
    end
    return snippet
end

local function rank_tag(tag, cur_file, cur_ext)
    local score = 0
    local tag_norm = vim.fs.normalize(tag.filename)

    -- Highest priority: defined in this very file
    if tag_norm == cur_file then
        score = score + 100
    end

    -- High priority: same file extension
    local tag_ext = vim.fn.fnamemodify(tag_norm, ":e")
    if tag_ext ~= "" and tag_ext == cur_ext then
        score = score + 40
    end

    -- Penalize test files, vendor, node_modules
    if tag_norm:find("/test") or tag_norm:find("_test") then
        score = score - 20
    end
    if tag_norm:find("node_modules") or tag_norm:find("vendor") then
        score = score - 50
    end

    return score
end

local function show_hover_or_tag()
    -- 1. Try active LSP hover
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    local has_hover = false
    for _, client in ipairs(clients) do
        if client.server_capabilities.hoverProvider then
            has_hover = true
            break
        end
    end

    if has_hover then
        vim.lsp.buf.hover()
        return
    end

    -- 2. Try ctags lookup
    local cword = vim.fn.expand("<cword>")
    if cword == "" then
        return
    end

    local raw_tags = vim.fn.taglist("^" .. cword .. "$")
    if #raw_tags == 0 then
        pcall(vim.cmd, "normal! K")
        return
    end

    local cur_file = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
    local cur_ext = vim.fn.expand("%:e")
    local cur_ft = vim.bo.filetype
    if cur_ft == "" then
        cur_ft = "text"
    end

    -- Rank tags by relevance
    for _, tag in ipairs(raw_tags) do
        tag.score = rank_tag(tag, cur_file, cur_ext)
    end

    table.sort(raw_tags, function(a, b)
        return a.score > b.score
    end)

    local lines = {}
    local seen_locations = {}
    local shown_count = 0

    for _, tag in ipairs(raw_tags) do
        local loc_key = tag.filename .. ":" .. tostring(tag.cmd)
        if not seen_locations[loc_key] then
            seen_locations[loc_key] = true

            local snippet = extract_tag_snippet(tag, 8)
            local kind = tag.kind
            if kind == nil then
                kind = "definition"
            end

            local rel_path = vim.fn.fnamemodify(tag.filename, ":~:.")
            table.insert(lines, "#### [" .. kind .. "] `" .. rel_path .. "`")

            if snippet ~= nil and #snippet > 0 then
                table.insert(lines, "```" .. cur_ft)
                for _, s_line in ipairs(snippet) do
                    table.insert(lines, s_line)
                end
                table.insert(lines, "```")
            elseif tag.cmd ~= nil then
                local clean_cmd = tag.cmd:gsub("^/%^?", ""):gsub("%$?/$", "")
                clean_cmd = vim.trim(clean_cmd)
                table.insert(lines, "```" .. cur_ft)
                table.insert(lines, clean_cmd)
                table.insert(lines, "```")
            end
            table.insert(lines, "")

            shown_count = shown_count + 1
            if shown_count >= 3 then
                break
            end
        end
    end

    if #lines == 0 then
        pcall(vim.cmd, "normal! K")
        return
    end

    vim.lsp.util.open_floating_preview(lines, "markdown", {
        border = "rounded",
        focus = false,
        max_width = 80,
    })
end

vim.keymap.set("n", "K", show_hover_or_tag, { desc = "Hover doc (LSP or accurate ctags preview)" })


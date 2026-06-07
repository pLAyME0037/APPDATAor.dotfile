local opts = { noremap = true, silent = true }

vim.g.mapleader = " "
-- vim.g.maplocalleader = " "

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.api.nvim_set_keymap("n", "<leader>tf", "<Plug>PlenaryTestFile", { noremap = false, silent = false })

vim.keymap.set("i", "jk", "<Esc>")
vim.keymap.set("n", "J", "mzJ`z")

-- neo-tree
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window" })

vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "<C-c>", ":nohl<CR>", { desc = "Clear search hl", silent = true })
vim.keymap.set("n", "<C-s>", ":wa<CR>")

vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

vim.keymap.set("v", "<", "<gv", opts)
vim.keymap.set("v", ">", ">gv", opts)

vim.keymap.set("n", "=ap", "ma=ap'a")

vim.keymap.set("n", "<leader>fm", vim.lsp.buf.format)
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)
vim.keymap.set("n", "<leader>lt", function()
    vim.cmd [[ PlenaryBustedFile % ]]
end)

vim.keymap.set("n", "<leader>a", "mzggVG")

vim.keymap.set("x", "<leader>p", [["_dP]])
vim.keymap.set("v", "p", '"_dP', opts)

vim.keymap.set('n', 'tuc', 'gUw')
vim.keymap.set('n', 'tlc', 'guw')

vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

vim.keymap.set({ "n", "v" }, "<leader>d", "\"_d")

vim.keymap.set("n", "Q", "<nop>")

vim.keymap.set("n", "<M-w>", "<C-w>w", { desc = "Cycle Split Windows" })

vim.keymap.set("n", "<leader>pb", "<C-^>", { desc = "Switch to Previous Buffer" })

vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>")
vim.keymap.set("n", "<M-h>", "<cmd>silent !tmux-sessionizer -s 0 --vsplit<CR>")
vim.keymap.set("n", "<M-H>", "<cmd>silent !tmux neww tmux-sessionizer -s 0<CR>")

vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")

vim.keymap.set(
    "n", "<leader>grn",
    [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
    { desc = "Replace word cursor is on globally"}
)
vim.keymap.set(
    "n", "<leader>lrn",
    [[:s/\<<C-r><C-w>\>/<C-r>//g<Left><Left>]],
    { desc = "Substitute word on line" }
)
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

vim.keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically." })
vim.keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally." })
vim.keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make split equal size." })

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
    local times = count > 0 and count or 5
    for _ = 1, times do
        if op == "inc_h" then vim.cmd("wincmd +")
        elseif op == "dec_h" then vim.cmd("wincmd -")
        elseif op == "inc_w" then vim.cmd("wincmd >")
        elseif op == "dec_w" then vim.cmd("wincmd <")
        end
    end
end

vim.keymap.set("n", "<leader>s]", function() resize_split(vim.v.count, "inc_h") end, { desc = "Increase split height." })
vim.keymap.set("n", "<leader>s[", function() resize_split(vim.v.count, "dec_h") end, { desc = "Decrease split height." })
vim.keymap.set("n", "<leader>s>", function() resize_split(vim.v.count, "inc_w") end, { desc = "Increase split width." })
vim.keymap.set("n", "<leader>s<", function() resize_split(vim.v.count, "dec_w") end, { desc = "Decrease split width." })
vim.keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split." })

vim.keymap.set("n", "<leader>fp", function ()
    local filePath = vim.fn.expand("%:~")
    vim.fn.setreg("+", filePath)
    print("File path copied to clipboard: " .. filePath)
end, { desc = "Copy file path to cilpboard."})

vim.keymap.set("n", "<leader>u", function ()
    vim.cmd.packadd("nvim.undotree")
    require("undotree").open()
end, { desc = "toggle buildin undo tree."})

vim.keymap.set( "n", "<leader>nl", "082lF i<CR><Esc>")

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
            local before = line:sub(1, pos - 1):gsub("%s+$", "") -- strip trailing spaces
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

vim.keymap.set("n", "<leader>ee", "oif err != nil {<CR>}<Esc>Oreturn err<Esc>")
vim.keymap.set("n", "<leader>ea", "oassert.NoError(err, \"\")<Esc>F\";a")
vim.keymap.set("n", "<leader>ef", "oif err != nil {<CR>}<Esc>Olog.Fatalf(\"error: %s\\n\", err.Error())<Esc>jj")
vim.keymap.set("n", "<leader>el", "oif err != nil {<CR>}<Esc>O.logger.Error(\"error\", \"error\", err)<Esc>F.;i")

vim.keymap.set("n", "<leader><leader>", function()
    require("telescope.builtin").find_files()
end)


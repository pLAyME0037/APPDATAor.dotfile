vim.g.db_ui_use_nerd_fonts = 1
vim.g.db_ui_show_database_icon = 1
vim.g.db_ui_execute_on_save = 0

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("data-viewer", { clear = true }),
    pattern = { "sql", "sqlite", "mysql", "plsql", "dbui", "dbout" },
    callback = function(args)
        vim.keymap.set("n", "L", function()
            local win_width = vim.api.nvim_win_get_width(0)
            local half_width = math.floor(win_width / 2)
            vim.cmd("normal! " .. half_width .. "l")
        end, { buffer = args.buf, desc = "Jump Right Half Screen" })

        vim.keymap.set("n", "H", function()
            local win_width = vim.api.nvim_win_get_width(0)
            local half_width = math.floor(win_width / 2)
            vim.cmd("normal! " .. half_width .. "h")
        end, { buffer = args.buf, desc = "Jump Left Half Screen" })

        vim.keymap.set("n", "<leader>r", "<Plug>(DBUI_ExecuteQuery)", { buffer = args.buf, desc = "Execute SQL" })
        vim.keymap.set("v", "<leader>r", "<Plug>(DBUI_ExecuteQuery)", { buffer = args.buf, desc = "Execute SQL" })
    end,
})

return {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
        { "tpope/vim-dadbod", lazy = true },
        {
            "kristijanhusak/vim-dadbod-completion",
            ft = {
                "sql",
                "sqlite",
                "mysql",
                "plsql"
            },
            lazy = true
        },
    },
    cmd = {
        "DBUI",
        "DBUIToggle",
        "DBUIAddConnection",
        "DBUIFindBuffer",
    },
    init = function()
        -- Settings
        vim.g.db_ui_use_nerd_fonts = 1
        vim.g.db_ui_show_database_icon = 1

        -- Optional: Auto-execute query on save
        vim.g.db_ui_execute_on_save = 0
    end,

    config = function()
        -- Create an Autocommand for SQL files
        vim.api.nvim_create_autocmd("FileType", {
        pattern = { "sql", "sqlite", "mysql", "plsql", "dbui", "dbout" },
        callback = function()

            -- Move RIGHT by half the screen width (Shift + L)
            vim.keymap.set("n", "L", function()
                local win_width = vim.api.nvim_win_get_width(0)
                local half_width = math.floor(win_width / 2)
                -- 'zl' scrolls the view, 'l' moves the cursor.
                -- usually just moving the cursor '50l' is what people want:
                vim.cmd("normal! " .. half_width .. "l")
            end, { desc = "Jump Right Half Screen" })

            -- Move LEFT by half the screen width (Shift + H)
            vim.keymap.set("n", "H", function()
                local win_width = vim.api.nvim_win_get_width(0)
                local half_width = math.floor(win_width / 2)
                vim.cmd("normal! " .. half_width .. "h")
            end, { desc = "Jump Left Half Screen" })

            -- vim.keymap.set("n", "H", "5h", { buffer = true, desc = "Move Left 5" })
            -- vim.keymap.set("n", "L", "5l", { buffer = true, desc = "Move Right 5" })

            -- Map <leader>r to Run Query
            vim.keymap.set("n", "<leader>r", "<Plug>(DBUI_ExecuteQuery)", { buffer = true, desc = "Execute SQL" })
            vim.keymap.set("v", "<leader>r", "<Plug>(DBUI_ExecuteQuery)", { buffer = true, desc = "Execute SQL" })
        end,
        })
    end,
}

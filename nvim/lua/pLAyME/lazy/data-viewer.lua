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
        pattern = { "sql", "sqlite", "mysql", "plsql" },
        callback = function()
            -- OPTION 1: Map <leader>r to Run Query
            vim.keymap.set("n", "<leader>r", "<Plug>(DBUI_ExecuteQuery)", { buffer = true, desc = "Execute SQL" })
            vim.keymap.set("v", "<leader>r", "<Plug>(DBUI_ExecuteQuery)", { buffer = true, desc = "Execute SQL" })
       
            -- OPTION 2: Map <Ctrl-Enter> to Run Query (Standard DB tool behavior)
            -- Note: <C-CR> might not work in all terminals, but usually works in WezTerm/Alacritty/Windows Terminal
            vim.keymap.set("n", "<C-CR>", "<Plug>(DBUI_ExecuteQuery)", { buffer = true, desc = "Execute SQL" })
        end,
        })
    end,
}

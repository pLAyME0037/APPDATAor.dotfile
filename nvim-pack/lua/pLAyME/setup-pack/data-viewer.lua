return {
    { src = "https://github.com/kristijanhusak/vim-dadbod-ui" },
    { src = "https://github.com/tpope/vim-dadbod", lazy = true },
    {
        src = "https://github.com/kristijanhusak/vim-dadbod-completion",
        ft = {
            "sql",
            "sqlite",
            "mysql",
            "plsql"
        },
        lazy = true
    },

    cmd = {
        "DBUI",
        "DBUIToggle",
        "DBUIAddConnection",
        "DBUIFindBuffer",
    },
    init = function()
        vim.g.db_ui_use_nerd_fonts = 1
        vim.g.db_ui_show_database_icon = 1
        vim.g.db_ui_execute_on_save = 0
    end,
    config = function()
        vim.api.nvim_create_autocmd("FileType", {
            group = vim.api.nvim_create_augroup("data-viewer", { clear = true }),
            pattern = { "sql", "sqlite", "mysql", "plsql", "dbui", "dbout" },
            callback = function()
                vim.keymap.set("n", "L", function()
                    local win_width = vim.api.nvim_win_get_width(0)
                    local half_width = math.floor(win_width / 2)
                    vim.cmd("normal! " .. half_width .. "l")
                end, { desc = "Jump Right Half Screen" })

                vim.keymap.set("n", "H", function()
                    local win_width = vim.api.nvim_win_get_width(0)
                    local half_width = math.floor(win_width / 2)
                    vim.cmd("normal! " .. half_width .. "h")
                end, { desc = "Jump Left Half Screen" })

                vim.keymap.set("n", "<leader>r", "<Plug>(DBUI_ExecuteQuery)", { buffer = true, desc = "Execute SQL" })
                vim.keymap.set("v", "<leader>r", "<Plug>(DBUI_ExecuteQuery)", { buffer = true, desc = "Execute SQL" })
            end,
        })
    end,
}

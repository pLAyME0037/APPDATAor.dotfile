return {
    {
        'nvim-flutter/flutter-tools.nvim',
        lazy = false,
        dependencies = {
            'nvim-lua/plenary.nvim',
            'stevearc/dressing.nvim',
        },
        config = function()
            vim.env.CHROME_EXECUTABLE = "/usr/bin/brave"
            require("flutter-tools").setup({
                ui = {
                    border = "rounded",
                },
                decorations = {
                    statusline = {
                        app_version = true,
                        device = true,
                    },
                },
                lsp = {
                    capabilities = require("cmp_nvim_lsp").default_capabilities(),
                }
            })

            vim.keymap.set("n", "<leader>fe", ":FlutterRun<CR>", { desc = "Flutter Run" })
            vim.keymap.set("n", "<leader>fq", ":FlutterQuit<CR>", { desc = "Flutter Quit" })
            vim.keymap.set("n", "<leader>fr", ":FlutterRestart<CR>", { desc = "Flutter Hot Restart" })
            vim.keymap.set("n", "<leader>fl", ":FlutterReload<CR>", { desc = "Flutter Hot Reload" })
            vim.api.nvim_create_autocmd("BufWritePost", {
                pattern = "*.dart",
                callback = function()
                    vim.cmd("FlutterReload")
                end,
            })
        end
    },
}

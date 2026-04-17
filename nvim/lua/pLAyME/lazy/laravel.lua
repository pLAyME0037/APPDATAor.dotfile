return {
    {
        "adalessa/laravel.nvim",
        enable = true,
        dependencies = {
            "MunifTanjim/nui.nvim",
            "nvim-lua/plenary.nvim",
            "nvim-neotest/nvim-nio",
        },
        ft = { "php", "blade" },
        event = { "BufEnter composer.json" },
        cmd = { "Laravel" },
        keys = {
            { "<leader>ll", function() require("laravel").pickers.laravel() end, desc = "Laravel Picker" },
            { "<c-g>", function() require("laravel").commands.run("view:finder") end, desc = "View Finder" },
            { "<leader>la", function() require("laravel").pickers.artisan() end, desc = "Artisan Picker" },
            { "<leader>lr", function() require("laravel").pickers.routes() end, desc = "Routes Picker" },
            { "<leader>lm", function() require("laravel").pickers.make() end, desc = "Make Picker" },
        },
        opts = {
            lsp_server = "intelephense",
            features = {
                pickers = { provider = "snacks" },
                route_info = { enable = true },
                diagnostics = false,
            },
        },
        config = function(_, opts)
            require("laravel").setup(opts)
        end,
    },
    { "jwalton512/vim-blade" },
}

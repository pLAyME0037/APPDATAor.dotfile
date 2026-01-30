return {
    {
        "adalessa/laravel.nvim",
        enable = false,
        dependencies = {
            "MunifTanjim/nui.nvim",
            "nvim-lua/plenary.nvim",
            "nvim-neotest/nvim-nio",
        },
        ft = { "php", "blade" },
        event = { "BufEnter composer.json" },
        cmd = { "Laravel" },
        keys = {
            {
                "<leader>ll",
                function() Laravel.pickers.laravel() end,
                desc = "Laravel: Open Laravel Picker"
            },
            {
                "<c-g>",
                function() Laravel.commands.run("view:finder") end,
                desc = "Laravel: Open View Finder"
            },
            {
                "<leader>la",
                function() Laravel.pickers.artisan() end,
                desc = "Laravel: Open Artisan Picker"
            },
            {
                "<leader>lt",
                function() Laravel.commands.run("actions") end,
                desc = "Laravel: Open Actions Picker"
            },
            {
                "<leader>lr",
                function() Laravel.pickers.routes() end,
                desc = "Laravel: Open Routes Picker"
            },
            {
                "<leader>lh",
                function() Laravel.run("artisan docs") end,
                desc = "Laravel: Open Documentation"
            },
            {
                "<leader>lm",
                function() Laravel.pickers.make() end,
                desc = "Laravel: Open Make Picker"
            },
            {
                "<leader>lc",
                function() Laravel.pickers.commands() end,
                desc = "Laravel: Open Commands Picker"
            },
            {
                "<leader>lo",
                function() Laravel.pickers.resources() end,
                desc = "Laravel: Open Resources Picker"
            },
            {
                "<leader>lp",
                function() Laravel.commands.run("command_center") end,
                desc = "Laravel: Open Command Center"
            },

        },
        opts = {
            lsp_server = "intelephense",
            environment = {
                environments =  { "local" },
            },
            commands_options = {
                ["artisan"] = { timeout = 10000 },
            },
            features = {
                pickers = {
                    provider = "telescope", -- "snacks | telescope | fzf-lua | ui-select"
                },
                route_info = { enable = true },
                model_info = { enable = false },
                diagnostics = false,
            },
        },
        config = function(_, opts)
            require("laravel").setup(opts)
            local ok, _ = pcall(require("telescope").load_extension, "laravel")

            if not ok then
                vim.notify("Laravel telescope extension could not load.", vim.log.levels.WARN)
            end
        end,
    },

    -- Blade filetype detection
    {
        "nathom/filetype.nvim",
        opts = {
            overrides = {
                complex = {
                    [".*%.blade%.php"] = "blade",
                },
            },
        },
    },

    -- Syntax Highlighting for Blade (No compile needed)
    { "jwalton512/vim-blade" },

    -- Add Laravel to nvim-cmp sources safely
    {
        "hrsh7th/nvim-cmp",
        dependencies = { "adalessa/laravel.nvim" },
        opts = function(_, opts)
            opts.sources = opts.sources or {}
            table.insert(opts.sources, { name = "laravel" })
        end,
    },
}

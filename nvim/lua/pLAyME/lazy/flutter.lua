return {
    -- 1. Flutter Tools
    {
        'nvim-flutter/flutter-tools.nvim',
        lazy = false,
        dependencies = {
            'nvim-lua/plenary.nvim',
            'stevearc/dressing.nvim', -- optional for vim.ui.select
        },
        config = function()
            vim.env.CHROME_EXECUTABLE = "/usr/bin/brave"
            require('flutter-tools').setup_project({
                {
                    name = 'Development', -- an arbitrary name that you provide so you can recognise this config
                    flavor = 'DevFlavor', -- your flavour
                    target = 'lib/main_dev.dart', -- your target
                    cwd = 'example',      -- the working directory for the project. Optional, defaults to the LSP root directory.
                    device = 'pixel6pro', -- the device ID, which you can get by running `flutter devices`
                    dart_define = {
                        API_URL = 'https://dev.example.com/api',
                        IS_DEV = true,
                    },
                    pre_run_callback = nil, -- optional callback to run before the configuration
                    -- exposes a table containing name, target, flavor and device in the arguments
                    dart_define_from_file = 'config.json' -- the path to a JSON configuration file
                },
                {
                    name = 'Web',
                    device = 'chrome',
                    flavor = 'WebApp',
                    web_port = "4000",
                    additional_args = { "--wasm" }
                },
                {
                    name = 'Profile',
                    flutter_mode = 'profile', -- possible values: `debug`, `profile` or `release`, defaults to `debug`
                }
            })
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
                project_config = {
                    {
                        name = 'Brave Browser',
                        device = 'chrome', -- Flutter treats Brave as 'chrome'
                        flutter_mode = 'debug', -- This enables the debugger/hot systems
                    },
                    {
                        name = 'Development (Mobile)',
                        target = 'lib/main_dev.dart',
                        device = 'pixel6pro',
                    },
                },
                lsp = {
                    on_attach = function(client, bufnr)
                        local opts = { buffer = bufnr }
                        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
                        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
                        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
                        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
                    end,
                    capabilities = require('cmp_nvim_lsp').default_capabilities(),
                }
            })

            -- Keybinds moved INSIDE the config function so they run
            vim.keymap.set('n', '<leader>fe', ':FlutterRun<CR>', { desc = 'Flutter Run' })
            vim.keymap.set('n', '<leader>fq', ':FlutterQuit<CR>', { desc = 'Flutter Quit' })
            vim.keymap.set('n', '<leader>fr', ':FlutterRestart<CR>', { desc = 'Flutter Hot Restart' })
            vim.keymap.set('n', '<leader>fl', ':FlutterReload<CR>', { desc = 'Flutter Hot Reload' })
            -- This makes it feel like "Real Time" recompiling
            vim.api.nvim_create_autocmd("BufWritePost", {
                pattern = "*.dart",
                callback = function()
                    vim.cmd("FlutterReload")
                end,
            })
        end
    },
}

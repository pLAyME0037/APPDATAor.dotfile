return {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
        "stevearc/conform.nvim",
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-cmdline",
        "hrsh7th/nvim-cmp",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
        "j-hui/fidget.nvim",
    },

    config = function()
        require("conform").setup({
            formatters_by_ft = {},
        })
        local cmp = require("cmp")
        local cmp_lsp = require("cmp_nvim_lsp")
        local capabilities = vim.tbl_deep_extend(
            "force",
            {},
            vim.lsp.protocol.make_client_capabilities(),
            cmp_lsp.default_capabilities()
        )

        require("fidget").setup({})
        require("mason").setup()

        require("mason-lspconfig").setup({
            automatic_installation = true,
            ensure_installed = {
                "intelephense",
                "lua_ls",
                "gopls",
                "vtsls",
                "tailwindcss",
                "html",
            },
            handlers = {
                function(server_name) -- default handler
                    require("lspconfig")[server_name].setup({
                        capabilities = capabilities,
                    })
                end,

                -- Fix "Undefined global vim" warnings in your config
                ["lua_ls"] = function()
                    local lspconfig = require("lspconfig")
                    lspconfig.lua_ls.setup({
                        capabilities = capabilities,
                        settings = {
                            Lua = {
                                diagnostics = {
                                    globals = { "vim" },
                                },
                                format = {
                                    enable = true,
                                    defaultConfig = {
                                        indent_style = "space",
                                        indent_size = "2",
                                    },
                                },
                            },
                        },
                    })
                end,

                -- PHP / Laravel Setup
                ["intelephense"] = function()
                    local lspconfig = require("lspconfig")
                    lspconfig.intelephense.setup({
                        capabilities = vim.tbl_deep_extend(
                            "force",
                            {},
                            vim.lsp.protocol.make_client_capabilities(),
                            require("cmp_nvim_lsp").default_capabilities()
                        ),
                        settings = {
                            intelephense = {
                                files = { maxSize = 5000000; },
                            },
                        },
                    })
                end,

                ["tailwindcss"] = function()
                    local lspconfig = require("lspconfig")
                    lspconfig.tailwindcss.setup({
                        capabilities = capabilities,
                        filetypes = {
                                "html", "css", "scss",
                                "javascript", "typescript",
                                -- "vue", "angular", "react"
                                "php", "blade",
                        },
                    })
                end,
            },
        })

        local cmp_select = { behavior = cmp.SelectBehavior.Select }

        cmp.setup({
            snippet = {
                expand = function(args)
                    require("luasnip").lsp_expand(args.body)
                end,
            },
            -- Keymaps for Autocomplete
            mapping = cmp.mapping.preset.insert({
                ["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
                ["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
                -- IMPORTANT: Enter key confirms selection
                ["<CR>"] = cmp.mapping.confirm({ select = true }),
                ["<C-y>"] = cmp.mapping.confirm({ select = true }),
                ["<C-Space>"] = cmp.mapping.complete(),
            }),

            -- Sources with Priorities (Fixes "Random" suggestions)
            sources = cmp.config.sources({
                { name = "nvim_lsp", priority = 1000 }, -- Intelligent code (Highest)
                { name = "luasnip", priority = 750 },   -- Snippets
                { name = "path", priority = 500 },      -- File paths
                { name = "buffer", priority = 250 },    -- Random text (Lowest)
            }),
        })

        -- Fix Diagnostics and Signs (The part that was crashing)
        local signs = { Error = "✘", Warn = "▲", Hint = "⚑", Info = "»" }
        for type, icon in pairs(signs) do
            local hl = "DiagnosticSign" .. type
            vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
        end

        vim.diagnostic.config({
            float = {
                focusable = false,
                style = "minimal",
                border = "rounded",
                source = "always",
                header = "",
                prefix = "",
            },
            signs = true, 
            virtual_text = true,
            underline = true,
            update_in_insert = false,
        })
    end,
}

return {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "j-hui/fidget.nvim",
    },

    config = function()
        require("fidget").setup({})
        require("mason").setup()

        local capabilities = require("cmp_nvim_lsp").default_capabilities()

        require("mason-lspconfig").setup({
            automatic_installation = true,
            ensure_installed = {
                "intelephense",
                "lua_ls",
                "gopls",
                "tailwindcss",
                "html",
                "cssls",
                "ts_ls",
                "emmet_ls",
                "marksman",
                "jdtls",
            },
            handlers = {
                function(server_name)
                    require("lspconfig")[server_name].setup({
                        capabilities = capabilities,
                        autostart = true,
                    })
                end,

                ["lua_ls"] = function()
                    local lspconfig = require("lspconfig")
                    lspconfig.lua_ls.setup({
                        capabilities = capabilities,
                        autostart = true,
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

                ["intelephense"] = function()
                    local lspconfig = require("lspconfig")
                    lspconfig.intelephense.setup({
                        capabilities = capabilities,
                        autostart = true,
                        settings = {
                            intelephense = {
                                files = { maxSize = 5000000 },
                            },
                        },
                    })
                end,

                ["tailwindcss"] = function()
                    local lspconfig = require("lspconfig")
                    lspconfig.tailwindcss.setup({
                        capabilities = capabilities,
                        autostart = true,
                        filetypes = {
                            "html", "css", "scss",
                            "javascript", "typescript",
                            "php", "blade",
                        },
                    })
                end,

                ["jdtls"] = function()
                    local lspconfig = require("lspconfig")
                    lspconfig.jdtls.setup({
                        capabilities = capabilities,
                        autostart = true,
                    })
                end,
            },
        })

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

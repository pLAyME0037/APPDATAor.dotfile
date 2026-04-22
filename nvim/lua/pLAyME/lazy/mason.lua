return {
    "williamboman/mason.nvim",
    lazy = false,
    dependencies = {
        "williamboman/mason-lspconfig.nvim",
        "WhoIsSethDaniel/mason-tool-installer.nvim",
    },
    config = function()
        local mason = require("mason")
        local mason_lspconfig = require("mason-lspconfig")
        local mason_tool_installer = require("mason-tool-installer")

        mason.setup({
            ui = {
                icons = {
                    package_installed = "✓",
                    package_pending = "➜",
                    package_uninstalled = "✗",
                },
            },
        })

        mason_lspconfig.setup({
            automatic_enable = true,
            ensure_installed = {
                "lua_ls",
                "intelephense",
                "ts_ls",
                "html",
                "cssls",
                "tailwindcss",
                "gopls",
                "emmet_ls",
                "marksman",
                "jdtls",
            },
        })

        mason_tool_installer.setup({
            ensure_installed = {
                "clangd",
                "denols",
                "biome",
                "phpstan",
                "pylint",
            },
        })
    end,
}

local mason = require("mason")
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

mason_tool_installer.setup({
    ensure_installed = {
        "clangd",
        "biome",
    },
})

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_deep_extend("force", capabilities, require("mini.completion").get_lsp_capabilities())

-- vim.lsp.config("*", { capabilities = capabilities })

local lspconfig = require("lspconfig")

require("mason-lspconfig").setup({
    ensure_installed = { "clangd", "biome" },
    handlers = {
        function(server_name)
            lspconfig[server_name].setup({ capabilities = capabilities })
        end,
    },
})

vim.lsp.config("lua_ls", {
    settings = {
        Lua = {
            diagnostics = { globals = { "vim" }},
        }
    }
})

vim.lsp.enable({ "lua_ls" })


local capabilities = vim.lsp.protocol.make_client_capabilities()
local ok_cmp_lsp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if ok_cmp_lsp then
    capabilities = cmp_nvim_lsp.default_capabilities()
end

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
        capabilities = capabilities,
    },
})

vim.keymap.set("n", "<leader>fe", ":FlutterRun<CR>", { desc = "Flutter Run" })
vim.keymap.set("n", "<leader>fq", ":FlutterQuit<CR>", { desc = "Flutter Quit" })
vim.keymap.set("n", "<leader>fr", ":FlutterRestart<CR>", { desc = "Flutter Hot Restart" })
vim.keymap.set("n", "<leader>fl", ":FlutterReload<CR>", { desc = "Flutter Hot Reload" })

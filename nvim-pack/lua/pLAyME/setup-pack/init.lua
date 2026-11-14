local modules = {
    "pLAyME.setup-pack.colorscheme",
    "pLAyME.setup-pack.treesitter",
    "pLAyME.setup-pack.autopairs",
    "pLAyME.setup-pack.mini",
    "pLAyME.setup-pack.render-markdown",
    "pLAyME.setup-pack.snacks",
    "pLAyME.setup-pack.oil",
    "pLAyME.setup-pack.telescope",
    "pLAyME.setup-pack.dotnet",
    "pLAyME.setup-pack.lualine",
    "pLAyME.setup-pack.data-viewer",
    "pLAyME.setup-pack.lsp",
    "pLAyME.setup-pack.nvim-cmp",
    "pLAyME.setup-pack.nvim-lint",
    "pLAyME.setup-pack.nvim-dap",
    "pLAyME.setup-pack.flutter",
}

for _, mod in ipairs(modules) do
    local ok, err = pcall(require, mod)
    if not ok then
        vim.notify("Error loading " .. mod .. ": " .. tostring(err), vim.log.levels.WARN)
    end
end

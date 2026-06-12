local ok, ts = pcall(require, "nvim-treesitter.configs")
if not ok then return end
ts.setup({
    ensure_installed = {
        "graphql", "bash", "lua", "vim",
        "vimdoc", "query", "yaml", "json",
        "php", "php_only", "php_doc", "blade",
        "javascript", "typescript", "tsx", "html", "css", "http",
        "c", "java", "rust", "ron", "svelte", "python", "prisma", "go",
    },
    auto_install = true,
    highlight = { enable = true },
    indent = { enable = true },
})

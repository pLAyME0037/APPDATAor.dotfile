return {
    {
        src = "https://github.com/nvim-treesitter/nvim-treesitter",
        config = function()
            local ok, ts = pcall(require, "nvim-treesitter.configs")
            if not ok then return end
            ts.setup({
                ensure_installed = {
                    "php", "php_only", "php_doc", "blade",
                    "json", "javascript", "typescript", "tsx",
                    "go", "yaml", "html", "css", "python", "http",
                    "prisma", "markdown", "markdown_inline", "svelte",
                    "graphql", "bash", "lua", "vim", "vimdoc", "query",
                    "c", "java", "rust", "ron",
                },
                auto_install = true,
                highlight = { enable = true },
                indent = { enable = true },
            })
        end,
    },
}

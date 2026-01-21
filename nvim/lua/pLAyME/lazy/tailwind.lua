return {
    "roobert/tailwindcss-colorizer-cmp.nvim",
    {
        "NvChad/nvim-colorizer.lua",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        opts = {},
        config = function()
            local nvchadcolorizer = require("colorizer")
            local tailwindcolorizer = require("tailwindcss-colorizer-cmp")

            nvchadcolorizer.setup({
                user_default_options = {
                    tailwind = true,
                },
                filetypes = {
                    "html",
                    "php",
                    "blade",
                    "css",
                    "javascript",
                    "typescript",
                    "javascriptreact",
                    "typescriptreact",
                    "vue",
                    "svelte",
                    "astro"
                },
            })

            tailwindcolorizer.setup({
                color_square_width = 2,
            })

        end,
    },
}

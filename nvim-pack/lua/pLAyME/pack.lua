vim.pack.add({
-- dependencies:
    { src = 'https://github.com/nvim-tree/nvim-web-devicons' },
    { src = 'https://github.com/kevinhwang91/promise-async' },
    { src = 'https://github.com/NvChad/nvim-colorizer.lua' },
    -- { src = 'https://github.com/' },
-- end dependencies:

-- color scheme:
    -- { src = 'https://github.com/rose-pine/neovim' },
    -- { src = 'https://github.com/ellisonleao/gruvbox.nvim' },
    -- { src = 'https://github.com/rebelot/kanagawa.nvim' },
    -- { src = 'https://github.com/craftzdog/solarized-osaka.nvim' },
    -- { src = 'https://github.com/folke/tokyonight.nvim' },
    { src = 'https://github.com/catppuccin/nvim' },
    -- { src = 'https://github.com/olimorris/onedarkpro.nvim' },
-- end color scheme:

    {
        src = 'https://github.com/windwp/nvim-autopairs',
        -- version = vim.version.range('1.0'),
    },
    { src = 'https://github.com/olrtg/nvim-emmet' },
    -- { src = 'https://github.com/adalessa/laravel.nvim' },
    { src = 'https://github.com/jwalton512/vim-blade' },
    { src = 'https://github.com/kevinhwang91/nvim-ufo' },
    { src = 'https://github.com/roobert/tailwindcss-colorizer-cmp.nvim' },
    { src = 'https://github.com/theprimeagen/vim-be-good' },
    -- { src = 'https://github.com/' },
})

require("nvim-autopairs").setup({})

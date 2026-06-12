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

-- lsp
    { src = "https://github.com/neovim/nvim-lspconfig" },

-- mason + dep
    { src = "https://github.com/williamboman/mason.nvim" },
    { src = 'https://github.com/williamboman/mason-lspconfig.nvim' },
    { src = 'https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim' },

-- telescope + deps:
    { src = "https://github.com/nvim-telescope/telescope.nvim" },
    { src = "https://github.com/nvim-lua/plenary.nvim" },
    { src = "https://github.com/nvim-telescope/telescope-fzf-native.nvim" },
    { src = "https://github.com/andrew-george/telescope-themes" },

-- dadbod + deps:
    { src = "https://github.com/kristijanhusak/vim-dadbod-ui" },
    { src = "https://github.com/tpope/vim-dadbod" },
    { src = "https://github.com/kristijanhusak/vim-dadbod-completion" },

-- flutter:
    { src = "https://github.com/nvim-flutter/flutter-tools.nvim" },
    { src = "https://github.com/stevearc/dressing.nvim" },

-- lualine:
    { src = "https://github.com/nvim-lualine/lualine.nvim" },

-- mini:
    { src = "https://github.com/echasnovski/mini.nvim" },
    { src = "https://github.com/JoosepAlviste/nvim-ts-context-commentstring" },

-- nvim-cmp + deps:
    { src = "https://github.com/hrsh7th/nvim-cmp" },
    { src = "https://github.com/hrsh7th/cmp-buffer" },
    { src = "https://github.com/hrsh7th/cmp-path" },
    { src = "https://github.com/f3fora/cmp-spell" },
    { src = "https://github.com/hrsh7th/cmp-nvim-lsp" },
    {
        src = "https://github.com/L3MON4D3/LuaSnip",
        build = "make install_jsregexp",
    },
    { src = "https://github.com/saadparwaiz1/cmp_luasnip" },
    { src = "https://github.com/rafamadriz/friendly-snippets" },
    { src = "https://github.com/onsails/lspkind.nvim" },

-- dap + deps:
    { src = "https://github.com/mfussenegger/nvim-dap" },
    { src = "https://github.com/rcarriga/nvim-dap-ui" },
    { src = "https://github.com/theHamsta/nvim-dap-virtual-text" },
    { src = "https://github.com/nvim-neotest/nvim-nio" },
    { src = "https://github.com/jay-babu/mason-nvim-dap.nvim" },
    { src = "https://github.com/leoluz/nvim-dap-go" },

-- lint:
    { src = "https://github.com/mfussenegger/nvim-lint" },

-- render-markdown:
    { src = "https://github.com/MeanderingProgrammer/render-markdown.nvim" },

-- snacks:
    { src = "https://github.com/folke/snacks.nvim" },

-- treesitter:
    {
        src = "https://github.com/nvim-treesitter/nvim-treesitter",
        version = "main"
    },

-- oil:
    { src = "https://github.com/stevearc/oil.nvim" },

-- ufo
    { src = 'https://github.com/kevinhwang91/nvim-ufo' },

-- autopairs
    { src = 'https://github.com/windwp/nvim-autopairs' }, 

-- vim be good
    { src = 'https://github.com/theprimeagen/vim-be-good' },

-- lang
    { src = 'https://github.com/roobert/tailwindcss-colorizer-cmp.nvim' },

    { src = 'https://github.com/olrtg/nvim-emmet' }, 
    -- { src = 'https://github.com/adalessa/laravel.nvim' }, 
    { src = 'https://github.com/jwalton512/vim-blade' },
    -- { src = 'https://github.com/' },
})

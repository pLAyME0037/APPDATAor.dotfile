--return {}
return {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
        "s1n7ax/nvim-window-picker", -- Add window picker
        "antosha417/nvim-lsp-file-operations", -- Add lsp file operations
    },
    -- These are the keys to activate the plugin globally
    keys = {
        { "<leader>e", "<cmd>Neotree toggle position=left<cr>", desc = "Explorer NeoTree" },
    },
    config = function()
        -- 1. Setup lsp-file-operations first
        require("lsp-file-operations").setup()

        -- 2. Setup Neo-tree
        require("neo-tree").setup({
            close_if_last_window = true,
            popup_border_style = "rounded",
            enable_git_status = true,
            enable_diagnostics = true,
            -- UI: Mimic LazyVim
            default_component_configs = {
                indent = {
                    indent_size = 2,
                    padding = 1,
                    with_markers = true,
                    indent_marker = "│",
                    last_indent_marker = "└",
                    highlight = "NeoTreeIndentMarker",
                },
                icon = {
                    folder_closed = "",
                    folder_open = "",
                    folder_empty = "",
                    default = "*",
                    highlight = "NeoTreeFileIcon",
                },
                modified = { symbol = "[+]", highlight = "NeoTreeModified" },
                git_status = {
                    symbols = {
                        -- Change type
                        added     = "✚",
                        modified  = "",
                        deleted   = "✖",
                        renamed   = "󰁕",
                        -- Status type
                        untracked = "",
                        ignored   = "",
                        unstaged  = "󰄱",
                        staged    = "",
                        conflict  = "",
                    },
                },
            },
            window = {
                position = "left",
                width = 30,
                mapping_options = {
                    noremap = true,
                    nowait = true,
                },
                mappings = {
                    -- UX: <C-l> inside Neo-tree to jump to the code (window right)
                    ["<C-l>"] = "open", 
                    ["l"] = "open",
                    ["h"] = "close_node",
                    ["<space>"] = "none",
                    ["Y"] = {
                        function(state)
                            local node = state.tree:get_node()
                            local path = node:get_id()
                            vim.fn.setreg("+", path, "c")
                        end,
                        desc = "Copy Path to Clipboard",
                    },
                },
            },
            filesystem = {
                follow_current_file = {
                    enabled = true,
                    leave_dirs_open = false, 
                },
                hijack_netrw_behavior = "open_default",
                use_libuv_file_watcher = true,
            },
        })
    end,
}

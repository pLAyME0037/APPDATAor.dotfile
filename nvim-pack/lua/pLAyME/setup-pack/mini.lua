do
    require('ts_context_commentstring').setup {
        enable_autocmd = false,
    }

    require("mini.comment").setup {
        options = {
            custom_commentstring = function()
                return require('ts_context_commentstring.internal').calculate_commentstring({ key = 'commentstring' })
                or vim.bo.commentstring
            end,
        },
    }
end

do
    require("mini.surround").setup({
        custom_surroundings = nil,
        highlight_duration = 300,
        mappings = {
            add = 'sa',
            delete = 'ds',
            find = 'sf',
            find_left = 'sF',
            highlight = 'sh',
            replace = 'sr',
            update_n_lines = 'sn',
            suffix_last = 'l',
            suffix_next = 'n',
        },
        n_lines = 20,
        respect_selection_type = false,
        search_method = 'cover',
        silent = false,
    })
end

do
    local miniTrailspace = require("mini.trailspace")

    miniTrailspace.setup({
        only_in_normal_buffers = true,
    })
    vim.keymap.set("n", "<leader>cw", function() miniTrailspace.trim() end, { desc = "Erase Whitespace" })

    vim.api.nvim_create_autocmd("CursorMoved", {
        pattern = "*",
        callback = function()
            require("mini.trailspace").unhighlight()
        end,
    })
end

do
    local miniSplitJoin = require("mini.splitjoin")
    miniSplitJoin.setup({
        mappings = { toggle = "" },
    })
    vim.keymap.set({ "n", "x" }, "sj", function() miniSplitJoin.join() end, { desc = "Join arguments" })
    vim.keymap.set({ "n", "x" }, "sk", function() miniSplitJoin.split() end, { desc = "Split arguments" })
end

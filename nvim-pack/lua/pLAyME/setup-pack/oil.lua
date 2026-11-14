vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })

require("oil").setup({
    default_file_explorer = true,
    columns = { "icon" },
    buf_options = { buflisted = false, bufhidden = "hide" },
    win_options = {
        wrap = false,
        signcolumn = "no",
        cursorcolumn = false,
        foldcolumn = "0",
        spell = false,
        list = false,
        conceallevel = 3,
        concealcursor = "nvic",
    },
    delete_to_trash = false,
    skip_confirm_for_simple_edits = false,
    prompt_save_on_select_new_entry = true,
    cleanup_delay_ms = 2000,
    constrain_cursor = "editable",
    watch_for_changes = false,
    keymaps = {
        ["g?"] = { "actions.show_help", mode = "n" },
        -- ["<CR>"] = "actions.select",
        ["<C-s>"] = { "actions.select", opts = { vertical = true }, desc = "Open in vertical split" },
        ["<C-h>"] = { "actions.select", opts = { horizontal = true }, desc = "Open in horizontal split" },
        ["<C-t>"] = { "actions.select", opts = { tab = true }, desc = "Open in new tab" },
        ["<C-p>"] = "actions.preview",
        ["<C-c>"] = { "actions.close", mode = "n" },
        ["<C-l>"] = "actions.refresh",
        ["-"] = { "actions.parent", mode = "n" },
        ["_"] = { "actions.open_cwd", mode = "n" },
        ["`"] = { "actions.cd", mode = "n" },
        ["g~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
        ["gs"] = { "actions.change_sort", mode = "n" },
        ["gx"] = "actions.open_external",
        ["g."] = { "actions.toggle_hidden", mode = "n" },
        ["g\\"] = { "actions.toggle_trash", mode = "n" },
    },
    use_default_keymaps = true,
    view_options = {
        show_hidden = false,
        is_hidden_file = function(name, bufnr)
            return name:match("^%.") ~= nil
        end,
        is_always_hidden = function(name, bufnr) return false end,
        natural_order = "fast",
        case_insensitive = false,
        sort = { { "type", "asc" }, { "name", "asc" } },
        highlight_filename = function(entry, is_hidden, is_link_target, is_link_orphan)
            return nil
        end,
    },
})

local oil_session_group = vim.api.nvim_create_augroup("OilSessionRestart", { clear = true })

vim.api.nvim_create_autocmd("SessionLoadPre", {
    group = oil_session_group,
    desc = "Wipe loaded oil:// buffers before session load to prevent E95 on :file",
    callback = function()
        local scratch
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) then
                local name = vim.api.nvim_buf_get_name(buf)
                if vim.startswith(name, "oil://") then
                    -- Move windows off the buffer first: deleting a buffer that is
                    -- displayed in the last remaining window fails with E444.
                    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
                        if vim.api.nvim_win_is_valid(win) then
                            if scratch == nil or not vim.api.nvim_buf_is_valid(scratch) then
                                scratch = vim.api.nvim_create_buf(true, false)
                            end
                            pcall(vim.api.nvim_win_set_buf, win, scratch)
                        end
                    end
                    pcall(vim.api.nvim_buf_delete, buf, { force = true })
                end
            end
        end
    end,
})

vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = oil_session_group,
    desc = "Reload empty oil:// buffers restored via enew + :file",
    callback = function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
                local name = vim.api.nvim_buf_get_name(buf)
                if vim.startswith(name, "oil://") then
                    local line_count = vim.api.nvim_buf_line_count(buf)
                    if line_count == 1 then
                        local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
                        if first_line == "" then
                            vim.api.nvim_buf_call(buf, function()
                                pcall(vim.cmd, "edit")
                            end)
                        end
                    end
                end
            end
        end
    end,
})

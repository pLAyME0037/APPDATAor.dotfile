vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })

require("oil").setup({
    default_file_explorer = true,
    columns = { "icon" },
    buf_options = { buflisted = false, bufhidden = "hide" },
    win_options = {
        wrap = false, signcolumn = "no", cursorcolumn = false,
        foldcolumn = "0", spell = false, list = false,
        conceallevel = 3, concealcursor = "nvic",
    },
    delete_to_trash = false,
    skip_confirm_for_simple_edits = false,
    prompt_save_on_select_new_entry = true,
    cleanup_delay_ms = 2000,
    constrain_cursor = "editable",
    watch_for_changes = false,
    keymaps = {
        ["g?"] = { "actions.show_help", mode = "n" },
        ["<CR>"] = function()
            local oil = require("oil")
            if oil.get_cursor_entry then
                local entry = oil.get_cursor_entry()
                if entry and entry.type ~= "directory" then
                    local dir = oil.get_current_dir()
                    if dir then
                        vim.cmd("wincmd l | edit " .. vim.fn.fnameescape(dir .. entry.name) .. " | wincmd h")
                        return
                    end
                end
            end
            require("oil.actions").select.callback()
        end,
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

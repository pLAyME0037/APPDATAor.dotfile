local cmp = require("cmp")
local has_luasnip, luasnip = pcall(require, "luasnip")
local lspkind = require("lspkind")
local colorizer = require("tailwindcss-colorizer-cmp").formatter

local rhs = function(keys)
    return vim.keycode(keys)
end

local lsp_kinds = {
    Class         = " ",
    Color         = " ",
    Constant      = " ",
    Constructor   = " ",
    Enum          = " ",
    EnumMember    = " ",
    Event         = " ",
    Field         = " ",
    File          = " ",
    Folder        = " ",
    Function      = " ",
    Interface     = " ",
    Keyword       = " ",
    Method        = " ",
    Module        = " ",
    Operator      = " ",
    Property      = " ",
    Reference     = " ",
    Snippet       = " ",
    Struct        = " ",
    Text          = " ",
    TypeParameter = " ",
    Unit          = " ",
    Value         = " ",
    Variable      = " ",
}

local column = function()
    local _line, col = unpack(vim.api.nvim_win_get_cursor(0))
    return col
end

local in_snippet = function()
    local session = require("luasnip.session")
    local node = session.current_nodes[vim.api.nvim_get_current_buf()]
    if not node then
        return false
    end
    local snippet = node.parent.snippet
    local snip_begin_pos, snip_end_pos = snippet.mark:pos_begin_end()
    local pos = vim.api.nvim_win_get_cursor(0)
    if pos[1] - 1 >= snip_begin_pos[1] and pos[1] - 1 <= snip_end_pos[1] then
        return true
    end
end

local in_whitespace = function()
    local col = column()
    return col == 0 or vim.api.nvim_get_current_line():sub(col, col):match("%s")
end

local in_leading_indent = function()
    local col = column()
    local line = vim.api.nvim_get_current_line()
    local prefix = line:sub(1, col)
    return prefix:find("^%s*$")
end

local shift_width = function()
    if vim.o.softtabstop <= 0 then
        return vim.fn.shiftwidth()
    else
        return vim.o.softtabstop
    end
end

local smart_bs = function(dedent)
    local keys = nil
    if vim.o.expandtab then
        if dedent then
            keys = rhs("<C-D>")
        else
            keys = rhs("<BS>")
        end
    else
        local col = column()
        local line = vim.api.nvim_get_current_line()
        local prefix = line:sub(1, col)
        if in_leading_indent() then
            keys = rhs("<BS>")
        else
            local previous_char = prefix:sub(#prefix, #prefix)
            if previous_char ~= " " then
                keys = rhs("<BS>")
            else
                keys = rhs("<C-\\><C-o>:set expandtab<CR><BS><C-\\><C-o>:set noexpandtab<CR>")
            end
        end
    end
    vim.api.nvim_feedkeys(keys, "nt", true)
end

local smart_tab = function(opts)
    local keys = nil
    if vim.o.expandtab then
        keys = "<Tab>"
    else
        local col = column()
        local line = vim.api.nvim_get_current_line()
        local prefix = line:sub(1, col)
        local in_leading_indent = prefix:find("^%s*$")
        if in_leading_indent then
            keys = "<Tab>"
        else
            local sw = shift_width()
            local previous_char = prefix:sub(#prefix, #prefix)
            local previous_column = #prefix - #previous_char + 1
            local current_column = vim.fn.virtcol({ vim.fn.line("."), previous_column }) + 1
            local remainder = (current_column - 1) % sw
            local move = remainder == 0 and sw or sw - remainder
            keys = (" "):rep(move)
        end
    end
    vim.api.nvim_feedkeys(rhs(keys), "nt", true)
end

local select_next_item = function(fallback)
    if cmp.visible() then
        cmp.select_next_item()
    else
        fallback()
    end
end

local select_prev_item = function(fallback)
    if cmp.visible() then
        cmp.select_prev_item()
    else
        fallback()
    end
end

local confirm = function(entry)
    local behavior = cmp.ConfirmBehavior.Replace
    if entry then
        local completion_item = entry.completion_item
        local newText = ""
        if completion_item.textEdit then
            newText = completion_item.textEdit.newText
        elseif type(completion_item.insertText) == "string" and completion_item.insertText ~= "" then
            newText = completion_item.insertText
        else
            newText = completion_item.word or completion_item.label or ""
        end
        local diff_after = math.max(0, entry.replace_range["end"].character + 1) - entry.context.cursor.col
        if entry.context.cursor_after_line:sub(1, diff_after) ~= newText:sub(-diff_after) then
            behavior = cmp.ConfirmBehavior.Insert
        end
    end
    cmp.confirm({ select = true, behavior = behavior })
end

local ok, loader = pcall(require, "luasnip.loaders.from_vscode")
if ok then loader.lazy_load() end

cmp.setup({
    experimental = {
        ghost_text = false,
    },
    completion = {
        completeopt = "menu,menuone,noinsert",
    },
    window = {
        documentation = {
            border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
        },
        completion = {
            border = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
        },
    },
    snippet = {
        expand = function(args)
            if has_luasnip then
                luasnip.lsp_expand(args.body)
            end
        end,
    },
    sources = cmp.config.sources({
        { name = "nvim_lsp", priority = 1000 },
        { name = "luasnip", priority = 750 },
        { name = "tailwindcss-colorizer-cmp", priority = 700 },
        { name = "lazydev", priority = 650 },
        { name = "path", priority = 500 },
        { name = "buffer", priority = 250 },
        {
            name = "spell",
            priority = 250,
            option = {
                enable_in_context = function()
                    local ft = vim.bo.filetype
                    return ft == "markdown" or ft == "text"
                end,
            },
        },
    }),
    mapping = cmp.mapping.preset.insert({
        ["<C-e>"] = cmp.mapping.abort(),
        ["<C-d>"] = cmp.mapping(function()
            cmp.close_docs()
        end, { "i", "s" }),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-j>"] = cmp.mapping(select_next_item),
        ["<C-k>"] = cmp.mapping(select_prev_item),
        ["<C-n>"] = cmp.mapping(select_next_item),
        ["<C-p>"] = cmp.mapping(select_prev_item),
        ["<Down>"] = cmp.mapping(select_next_item),
        ["<Up>"] = cmp.mapping(select_prev_item),
        ["<C-y>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
                local entry = cmp.get_selected_entry()
                confirm(entry)
            else
                fallback()
            end
        end, { "i", "s" }),
        ["<CR>"] = cmp.mapping(function(fallback) fallback() end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback) fallback() end, { "i", "s" }),
        ["<Tab>"] = cmp.mapping(function(fallback) fallback() end, { "i", "s" }),
    }),
    formatting = {
        format = function(entry, vim_item)
            vim_item.kind = string.format("%s %s", lsp_kinds[vim_item.kind] or "", vim_item.kind)
            vim_item.menu = ({
                buffer = "[Buffer]",
                nvim_lsp = "[LSP]",
                luasnip = "[LuaSnip]",
                nvim_lua = "[Lua]",
                latex_symbols = "[LaTeX]",
            })[entry.source.name]
            vim_item = lspkind.cmp_format({
                maxwidth = 25,
                ellipsis_char = "...",
            })(entry, vim_item)
            if entry.source.name == "nvim_lsp" then
                vim_item = colorizer(entry, vim_item)
            end
            return vim_item
        end,
    },
})

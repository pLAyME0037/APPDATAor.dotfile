local ok_cs = pcall(require, "colorscheme")
if not ok_cs then
    vim.cmd("colorscheme clear-as-night")
end

local ok_ui2, ui2 = pcall(require, "vim._core.ui2")
if ok_ui2 and type(ui2) == "table" and type(ui2.enable) == "function" then
    ui2.enable({
        enable = true,
        msg = {
            targets = {
                [""]         = "msg",
                empty        = "cmd",
                bufwrite     = "msg",
                confirm      = "cmd",
                emsg         = "pager",
                echo         = "msg",
                echomsg      = "msg",
                echoerr      = "pager",
                completion   = "cmd",
                list_cmd     = "pager",
                lua_error    = "pager",
                lua_print    = "msg",
                progress     = "pager",
                rpc_error    = "pager",
                quickfix     = "msg",
                search_cmd   = "cmd",
                search_count = "cmd",
                shell_cmd    = "pager",
                shell_err    = "pager",
                shell_out    = "pager",
                shell_ret    = "msg",
                undo         = "msg",
                verbose      = "pager",
                wildlist     = "cmd",
                wmsg         = "msg",
                typed_cmd    = "cmd",
            },
            cmd    = { height = 0.5 },
            dialog = { height = 0.5 },
            msg    = { height = 0.3, timeout = 4000 },
            pager  = { height = 0.5 },
        },
    })
end

require("pLAyME")

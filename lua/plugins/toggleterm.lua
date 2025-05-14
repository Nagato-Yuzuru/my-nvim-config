local term = require("toggleterm")

term.setup({
	open_mapping = [[<C-x>`]],
	size = 17,
	start_in_insert = true,
	shell = vim.o.shell, -- 使用默认 shell
    hide_numbers = true,  -- 不显示行号          
})

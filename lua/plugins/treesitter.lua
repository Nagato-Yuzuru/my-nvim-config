require("nvim-treesitter.configs").setup {
  ensure_installed = { "python", "go", "html", "json", "yaml", "bash", "sql", "c", "cpp", "lua" },
  highlight = { enable = true },
  indent = { enable = true },
}


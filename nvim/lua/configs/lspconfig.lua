local util = require("lspconfig.util")

require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "clangd", "basedpyright", "gopls", "ts_ls", "rust_analyzer", "neocmake", "zls", "lua_ls",
  "nim_langserver", "rust_analyzer", "docker_language_server", "powershell_es", "bashls" }

vim.lsp.config("basedpyright", {
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local root = util.root_pattern(
      ".git",
      "pyproject.toml",
      "setup.py",
      "setup.cfg",
      "requirements.txt",
      ".venv",
      "Pipfile"
    )(fname)
    on_dir(root or vim.fn.fnamemodify(fname, ":h"))
  end,

  settings = {
    basedpyright = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
        extraPaths = { vim.fn.getcwd() },
        inlayHints = {
          variableTypes = true,
          functionReturnTypes = true,
          callArgumentNames = true,
          genericTypes = true,
        },
      },
    },
    python = {
      venvPath = ".",
      venv = ".venv",
    },
  },
})

vim.lsp.enable(servers)

vim.lsp.config.bashls = {
  cmd = { "bash-language-server", "start" }
}

vim.lsp.config.nim_langserver = {
  cmd = { "nimlangserver" },
  filetypes = { "nim" },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    on_dir(
      util.root_pattern '*.nimble' (fname) or vim.fs.dirname(vim.fs.find('.git', { path = fname, upward = true })[1])
    )
  end
}

vim.lsp.config.clangd = {
  filetypes = {
    "c",
    "cpp",
    "objc",
    "objcpp",
    "cuda",
    "cppm",
  },

  before_initroot_dir = util.root_pattern(
    ".clang-format",
    "compile_commands.json",
    ".git",
    "CMakeLists.txt"
  ),

  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
  },

  init_options = {
    fallbackFlags = {
      -- "-std=c++20",
      "-Iinclude",
    },
  },
}

-- read :h vim.lsp.config for changing options of lsp servers

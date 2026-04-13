return {
  "loctvl842/monokai-pro.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    -- Basic setup for monokai-pro. Customize options as you like.
    local ok, monokai = pcall(require, "monokai-pro")
    if ok and monokai.setup then
      monokai.setup({
        -- sample options (you can change style to "pro", "monokai", "ristretto", "spectrum", ...)
        -- style = "spectrum",
      })
    end

    -- Set the colorscheme
    vim.cmd("colorscheme monokai-pro")
  end,
}

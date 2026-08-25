return {
  {
    "nvim-treesitter/nvim-treesitter",
    init = function(plugin)
      local runtime = plugin.dir .. "/runtime"
      if vim.uv.fs_stat(runtime) then
        vim.opt.rtp:prepend(runtime)
      end
    end,
  },
}

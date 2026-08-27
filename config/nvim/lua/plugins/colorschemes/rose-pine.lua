local variant = os.getenv("COLORSCHEME_VARIANT") or "main"
local transparent = os.getenv("COLORSCHEME_TRANSPARENT") == "true"

return {
  {
    "rose-pine/neovim",
    name = "rose-pine",
    opts = {
      variant = variant,
      dark_variant = variant,
      styles = {
        transparency = transparent,
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "rose-pine",
    },
  },
}

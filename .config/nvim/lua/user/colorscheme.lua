local ok, monokai = pcall(require, "monokai-pro")

if ok and monokai.setup then
  monokai.setup({
    override = function(scheme)
      return {
        OilDir = { fg = scheme.base.blue, bold = true },
        OilDirIcon = { fg = scheme.base.blue },
        OilFile = { fg = scheme.editor.foreground },
        OilHidden = { fg = scheme.base.dimmed2, italic = true },
        OilSocket = { fg = scheme.base.magenta },
        OilLink = { fg = scheme.base.cyan },
        OilOrphanLink = { fg = scheme.base.red },
        OilLinkTarget = { fg = scheme.base.dimmed2 },
        OilOrphanLinkTarget = { fg = scheme.base.red },
        OilCreate = { fg = scheme.base.green },
        OilDelete = { fg = scheme.base.red },
        OilMove = { fg = scheme.base.yellow },
        OilCopy = { fg = scheme.base.cyan },
        OilChange = { fg = scheme.base.magenta },
        OilTrashSourcePath = { fg = scheme.base.dimmed2, italic = true },
        OilFloat = { bg = scheme.sideBar.background },
        OilFloatBorder = { fg = scheme.editorHoverWidget.border, bg = scheme.sideBar.background },
        OilFloatTitle = { fg = scheme.sideBarTitle.foreground, bg = scheme.sideBar.background, bold = true },
      }
    end,
  })
end

vim.cmd("colorscheme monokai-pro")

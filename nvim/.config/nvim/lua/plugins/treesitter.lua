local parsers = {
	"bash",
	"c",
	"css",
	"diff",
	"dockerfile",
	"go",
	"html",
	"javascript",
	"json",
	"lua",
	"luadoc",
	"markdown",
	"markdown_inline",
	"python",
	"rust",
	"sql",
	"terraform",
	"toml",
	"tsx",
	"typescript",
	"vim",
	"vimdoc",
	"yaml",
}

return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = function()
			require("nvim-treesitter").install(parsers):wait(300000)
		end,
		config = function()
			local treesitter = require("nvim-treesitter")
			treesitter.setup({
				-- Passing this explicitly also prepends it to runtimepath.
				install_dir = vim.fn.stdpath("data") .. "/site",
			})
			-- Complete first-run installs before filetype plugins try to use them.
			treesitter.install(parsers):wait(300000)

			vim.api.nvim_create_autocmd("FileType", {
				callback = function(event)
					local filetype = vim.bo[event.buf].filetype
					local language = vim.treesitter.language.get_lang(filetype) or filetype

					if vim.tbl_contains(parsers, language)
						and pcall(vim.treesitter.language.add, language)
					then
						pcall(vim.treesitter.start, event.buf, language)
						vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
						vim.wo.foldmethod = "expr"
						vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
					end
				end,
			})
		end,
	},
}

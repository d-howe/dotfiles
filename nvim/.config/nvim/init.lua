-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end
-- Use Ubuntu's Python provider. The previous virtualenv path did not exist,
-- and Neovim does not expand "~" in this setting.
vim.g.python3_host_prog = vim.fn.exepath("python3")
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim
require("vim-opts")
require("lazy").setup("plugins")

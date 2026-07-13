return {
	{
		-- NOTE: Yes, you can install new plugins here!
		"mfussenegger/nvim-dap",
		-- NOTE: And you can specify dependencies as well
		dependencies = {
			-- Creates a beautiful debugger UI
			"rcarriga/nvim-dap-ui",

			-- Required dependency for nvim-dap-ui
			"nvim-neotest/nvim-nio",

			-- Add your own debuggers here
			"leoluz/nvim-dap-go",
			"mfussenegger/nvim-dap-python",
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			-- Nix provides debugpy and delve on PATH.
			require("dap-python").setup(vim.fn.exepath("python3"))
			require("dap-go").setup()

			-- ==========================================
			-- Extensible Test & Environment Runner Setup
			-- ==========================================

			-- Load environment variables from a given file into the global Neovim environment
			local function load_env(file)
				local env_file = vim.fn.getcwd() .. "/" .. file
				if vim.fn.filereadable(env_file) == 1 then
					local lines = vim.fn.readfile(env_file)
					for _, line in ipairs(lines) do
						-- Ignore comments and look for KEY=VALUE pairs
						if not line:match("^%s*#") and line:match("=") then
							local k, v = line:match("([^=]+)=?(.*)")
							if k and v then
								-- Strip quotes if present
								v = v:gsub("^[\"']", ""):gsub("[\"']$", "")
								vim.fn.setenv(k, v)
							end
						end
					end
				end
			end

			-- A master function to prepare environment variables (generic)
			local function prepare_debug_env()
				-- 1. Load common project environment files (silently ignored if they don't exist)
				local env_files = {
					".env",
					".env.local",
					".env.test",
					"envs/local.env",
					"envs/pytest.env",
				}
				for _, file in ipairs(env_files) do
					load_env(file)
				end

				-- 2. Hardcode any fallback/override global variables here
				local global_overrides = {
					DB_HOSTNAME = "localhost",
					REDIS_HOST = "localhost",
				}
				for k, v in pairs(global_overrides) do
					vim.fn.setenv(k, v)
				end
			end

			-- The main routing function for debugging tests based on filetype
			local function run_debug_test(target)
				-- Auto-save before debugging to prevent "Cursor position outside buffer" errors
				-- which happen when the file on disk doesn't match the Neovim buffer in memory.
				vim.cmd("silent! wa")

				prepare_debug_env()

				local filetype = vim.bo.filetype

				if filetype == "python" then
					if target == "method" then
						require("dap-python").test_method()
					elseif target == "class" then
						require("dap-python").test_class()
					end
				elseif filetype == "go" then
					-- Requires 'leoluz/nvim-dap-go' installed
					if target == "method" then
						require("dap-go").debug_test()
					else
						vim.notify(
							"Go adapter currently only supports 'method' scope test running natively",
							vim.log.levels.INFO
						)
						require("dap-go").debug_test()
					end
				else
					vim.notify("No debug test configured for filetype: " .. filetype, vim.log.levels.WARN)
				end
			end

			vim.keymap.set("n", "<leader>dt", function()
				run_debug_test("method")
			end, { desc = "Debug: Local Test Method" })
			vim.keymap.set("n", "<leader>dc", function()
				run_debug_test("class")
			end, { desc = "Debug: Local Test Class" })

			-- Basic debugging keymaps, feel free to change to your liking!
			vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug: Start/Continue" })
			vim.keymap.set("n", "<F1>", dap.step_into, { desc = "Debug: Step Into" })
			vim.keymap.set("n", "<F2>", dap.step_over, { desc = "Debug: Step Over" })
			vim.keymap.set("n", "<F3>", dap.step_out, { desc = "Debug: Step Out" })
			vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
			vim.keymap.set("n", "<leader>B", function()
				dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
			end, { desc = "Debug: Set Breakpoint" })

			-- Dap UI setup
			-- For more information, see |:help nvim-dap-ui|
			dapui.setup({
				-- Set icons to characters that are more likely to work in every terminal.
				icons = { expanded = "▾", collapsed = "▸", current_frame = "*" },
				controls = {
					icons = {
						pause = "⏸",
						play = "▶",
						step_into = "⏎",
						step_over = "⏭",
						step_out = "⏮",
						step_back = "b",
						run_last = "▶▶",
						terminate = "⏹",
						disconnect = "⏏",
					},
				},
				-- You can tweak these sizes permanently here.
				-- By default nvim-dap-ui resets window sizes when it opens.
				layouts = {
					{
						elements = {
							{ id = "scopes", size = 0.25 },
							{ id = "breakpoints", size = 0.25 },
							{ id = "stacks", size = 0.25 },
							{ id = "watches", size = 0.25 },
						},
						size = 80, -- Increased from 40 to 80
						position = "left",
					},
					{
						elements = {
							{ id = "repl", size = 0.5 },
							{ id = "console", size = 0.5 },
						},
						size = 20, -- Increased from 10 to 20
						position = "bottom",
					},
				},
			})

			-- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
			vim.keymap.set("n", "<F7>", dapui.toggle, { desc = "Debug: See last session result." })

			dap.listeners.after.event_initialized["dapui_config"] = dapui.open
			dap.listeners.before.event_terminated["dapui_config"] = dapui.close
			dap.listeners.before.event_exited["dapui_config"] = dapui.close
		end,
	},

	{
		"theHamsta/nvim-dap-virtual-text",
		config = function()
			require("nvim-dap-virtual-text").setup({})
		end,
	},
}

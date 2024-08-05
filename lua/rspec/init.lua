local config = require('rspec.config')
local runner = require('rspec.runner')

local M = {}

function M.run_current_file()
  local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())

  if not config.allowed_file_format(bufname) then
    vim.notify('[rspec.nvim] Invalid filename', vim.log.levels.WARN)
    return
  end

  runner.run_rspec()
end

function M.abort()
  runner.abort()
end

--- @param user_config table
function M.setup(user_config)
  config.setup(user_config)

  vim.api.nvim_set_hl(0, 'rspec_passed', { fg = '#40a02b' })
  vim.api.nvim_set_hl(0, 'rspec_failed', { fg = '#d20f39' })
  vim.api.nvim_set_hl(0, 'rspec_aborted', { fg = '#d20f39' })

  vim.cmd("command! RSpec lua require('rspec').run_current_file()<CR>")
  vim.cmd("command! RSpecAbort lua require('rspec').abort()<CR>")
end

return M

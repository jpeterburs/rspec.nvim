local config = {}
local default_config = {
  -- File name pattern that can run rspec
  allowed_file_format = function(filename)
    return vim.endswith(filename, '_spec.rb')
  end,

  -- File path to save the last result
  last_result_path = vim.fn.stdpath('data') .. 'rspec/last_result.json',
}

local Config = {}

--- @param user_config table
function Config.setup(user_config)
  config = vim.tbl_deep_extend('force', default_config, user_config or {})
end

setmetatable(Config, {
  __index = function(_, key)
    return config[key]
  end
})

return Config

local config = require('rspec.config')

local job_id = nil
local running = false
local namespace = vim.api.nvim_create_namespace('rspec')

--- last rspec execution result
--- @return table
local function last_result()
  local last_result = {}
  if vim.fn.getfsize(config.last_result_path) > 0 then
    local last_result_json = vim.fn.readfile(config.last_result_path)[1]
    last_result = vim.json.decode(last_result_json)
  end

  return last_result
end

--- Build a summary of RSpec execution results.
--- @param exit_code integer
--- @return string[] # { message, hl_group}
local function build_summary_chunk(exit_code)
  local messages = {
    [0] = {
      label = 'PASSED',
      hl_group = 'rspec_passed',
      text = last_result().summary_line
    },
    [1] = {
      label = 'FAILED',
      hl_group = 'rspec_failed',
      text = last_result().summary_line
    },
    default = {
      label = 'ERROR',
      hl_group = 'rspec_aborted',
      text = 'exit_code=' .. exit_code
    },
  }

  local message = messages[exit_code] or messages['default']

  return { string.format("[rspec.nvim] %s : %s", message.label, message.text), message.hl_group}
end

--- Returns list of ancestor paths from current working dir.
--- The return value does not include the root path ('/')
--- Each path does not have a trailing slash
--- @return string[] # { '/foo/bar/baz', '/foo/bar', '/foo' }
local function get_ancestor_paths()
  local ancestor_paths = {}
  local current_path = vim.fn.getcwd()

  repeat
    table.insert(ancestor_paths, current_path)
    current_path = vim.fn.fnamemodify(current_path, ':h')
  until current_path == '/'

  return ancestor_paths
end

--- Returns wheter of nor 'filename' exists in 'path'
--- @param path string # '/path/to/app'
--- @param filename string # 'Gemfile'
--- @return boolean
local function has_file(path, filename)
  return vim.fn.filereadable(path .. '/' .. filename) == 1
end

--- Determines rspec binary and appends args
--- @return string
local function command()
  local args = {
    vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()),
    '--format',
    'json',
    '--out',
    config.last_result_path
  }
  local bin = { 'rspec' }

  for _, path in pairs(get_ancestor_paths()) do
    if has_file(path, 'bin/rspec') then
      bin = { 'bin/rspec' }
    elseif has_file(path, 'Gemfile') then
      bin = { 'bundle', 'exec', 'rspec' }
    end
  end

  return vim.list_extend(bin, args)
end

--- Notify a summery of RSpec execution
--- @params exit_code integer
local function notify_summary(exit_code)
  local summary_chunks = build_summary_chunk(exit_code)

  vim.api.nvim_echo({ summary_chunks }, true, {})
end

--- Add failed examples tzo diagnostics
--- @return nil
local function add_failed_examples_to_diagnostics()
  local diagnostics = {}

  if last_result().examples then
    local failed_examples = vim.tbl_filter(function(examples)
    return examples.status == 'failed'
    end, last_result().examples)

    for _, example in ipairs(failed_examples) do
      table.insert(diagnostics, {
        bufnr = vim.fn.bufnr(example.file_path),
        lnum = example.line_number - 1,
        col = 0,
        severity = vim.diagnostics.severity.ERROR,
        source = 'rspec.nvim',
        message = example.execution.message
      })
    end

    vim.diagnostics.set(namespace, 0, diagnostics)
  end
end

local M = {}

function M.run_rspec()
  if running then
    vim.notify('[rspec.nvim] RSpec is already running', vim.log.levels.ERROR)
    return
  end

  running = true
  vim.diagnostic.reset(namespace, 0)
  job_id = vim.fn.jobstart(command(), {
    cwd = vim.fn.getcwd(),
    on_exit = function (_, exit_code, _)
      notify_summary(exit_code)

      if exit_code == 1 then
        add_failed_examples_to_diagnostics()
      end

      running = false
    end
  })
end

function M.abort()
  if not running then
    vim.notify('[rspec.nvim] RSpec is not running', vim.log.levels.WARN)
    return
  end

  local res = vim.fn.jobstop(job_id)
  if res ~= 1 then
    vim.notify('[rspec.nvim] failed to abort RSpec', vim.log.levels.ERROR)
  end
end

return M

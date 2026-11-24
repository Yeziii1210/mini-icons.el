-- Generate Emacs Lisp data for mini-icons from mini.icons and Neovim.
--
-- Usage (from the repository root):
--
--   nvim --headless -u NONE -l scripts/generate.lua [PATH-TO-MINI.ICONS-OR-MINI.NVIM]
--
-- Without an argument, the script tries `packadd mini.icons` and
-- `packadd mini.nvim`.  It writes:
--
-- - mini-icons-data.el      icon tables and Neovim filetype detection data
-- - test/expected.eld       reference results of `MiniIcons.get()` for tests

local root = vim.fn.getcwd()

-- Locate mini.icons ----------------------------------------------------------
local function load_mini_icons()
  if arg[1] and arg[1] ~= '' then vim.opt.rtp:prepend(vim.fn.fnamemodify(arg[1], ':p')) end
  local ok = pcall(require, 'mini.icons')
  if not ok then
    pcall(vim.cmd.packadd, 'mini.icons')
    pcall(vim.cmd.packadd, 'mini.nvim')
    ok = pcall(require, 'mini.icons')
  end
  if not ok then error('Could not find mini.icons; pass its path as the first argument') end
  require('mini.icons').setup()
  return vim.api.nvim_get_runtime_file('lua/mini/icons.lua', false)[1]
end

local icons_file = load_mini_icons()
local icons_dir = vim.fn.fnamemodify(icons_file, ':h:h:h')
local mini_rev = vim.trim(vim.fn.system({ 'git', '-C', icons_dir, 'rev-parse', '--short', 'HEAD' }))
if vim.v.shell_error ~= 0 then mini_rev = 'unknown' end
local nvim_version = tostring(vim.version())

-- Resolve relative names against "/" so results do not depend on the cwd.
vim.fn.chdir('/')

-- Access internal tables of mini.icons through its upvalue `H` ---------------
local function get_upvalue(fn, name)
  local i = 1
  while true do
    local n, v = debug.getupvalue(fn, i)
    if n == nil then return nil end
    if n == name then return v end
    i = i + 1
  end
end

local H = get_upvalue(MiniIcons.get, 'H')
assert(H and H.filetype_icons, 'Could not access mini.icons internals')

-- Elisp printing ---------------------------------------------------------------
local function el_str(s)
  return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

local function color_of(hl) return (hl:gsub('^MiniIcons', '')):lower() end

local function sorted_keys(t)
  local keys = vim.tbl_keys(t)
  table.sort(keys)
  return keys
end

-- Icon tables: (NAME GLYPH . COLOR) or (NAME . "FILETYPE")
local function icon_table(t)
  local lines = {}
  for _, name in ipairs(sorted_keys(t)) do
    local v = t[name]
    if type(v) == 'string' then
      table.insert(lines, string.format('(%s . %s)', el_str(name), el_str(v)))
    else
      table.insert(lines, string.format('(%s %s . %s)', el_str(name), el_str(v.glyph), color_of(v.hl)))
    end
  end
  return lines
end

-- Neovim filetype data ----------------------------------------------------------
local scratch = vim.api.nvim_create_buf(false, true)

-- Evaluate a filetype rule the way `vim.filetype.match()` does with the empty
-- scratch buffer mini.icons uses.  Content-based rules thus resolve to the
-- result they give for an empty file.
local function eval_rule(rule, path)
  if type(rule) == 'table' then rule = rule[1] end
  if type(rule) == 'string' then return rule end
  if type(rule) ~= 'function' then return nil end
  local ok, ft = pcall(rule, path, scratch)
  if ok and type(ft) == 'string' and ft ~= '' then return ft end
  return nil
end

local ft = vim.filetype.inspect()

local ft_extension = {}
for ext, rule in pairs(ft.extension) do
  ft_extension[ext] = eval_rule(rule, '/aaa.' .. ext)
end

local ft_filename = {}
for name, rule in pairs(ft.filename) do
  local path = name:sub(1, 1) == '/' and name or ('/' .. name)
  ft_filename[name] = eval_rule(rule, path)
end

-- Convert a Lua pattern to an Emacs regexp.  `${VAR}` references are kept as
-- is and expanded at match time.  Returns nil for unsupported constructs.
local lua_classes = {
  a = '[:alpha:]', c = '[:cntrl:]', d = '0-9', g = '[:graph:]', l = '[:lower:]',
  p = '[:punct:]', s = '[:space:]', u = '[:upper:]', w = '[:alnum:]', x = '[:xdigit:]',
}
local emacs_special = { ['.'] = true, ['*'] = true, ['+'] = true, ['?'] = true,
                        ['['] = true, ['^'] = true, ['$'] = true, ['\\'] = true }

local function literal(ch) return emacs_special[ch] and ('\\' .. ch) or ch end

local function convert_pattern(pat)
  local out, i, n, quantifiable = {}, 1, #pat, false
  local function push(s, q) table.insert(out, s); quantifiable = q end
  if pat:sub(1, 1) == '^' then push('\\`', false); i = 2 end
  while i <= n do
    local c = pat:sub(i, i)
    if c == '$' and i == n then
      push("\\'", false); i = i + 1
    elseif c == '$' and pat:sub(i + 1, i + 1) == '{' then
      local j = pat:find('}', i, true)
      if not j then return nil end
      push(pat:sub(i, j), false); i = j + 1
    elseif c == '%' then
      local d = pat:sub(i + 1, i + 1)
      local class = lua_classes[d:lower()]
      if class then
        push((d:match('%u') and '[^' or '[') .. class .. ']', true)
      elseif d == '' or d == 'b' or d == 'f' or d:match('%d') then
        return nil
      else
        push(literal(d), true)
      end
      i = i + 2
    elseif c == '[' then
      local j, negate, first = i + 1, false, true
      if pat:sub(j, j) == '^' then negate = true; j = j + 1 end
      local items, rbracket, dash, caret = {}, false, false, false
      while true do
        local ch = pat:sub(j, j)
        if ch == '' then return nil end
        if ch == ']' and not first then break end
        if ch == '%' then
          local d = pat:sub(j + 1, j + 1)
          local class = lua_classes[d:lower()]
          if class then
            if d:match('%u') then return nil end
            table.insert(items, class)
          elseif d == ']' then rbracket = true
          elseif d == '-' then dash = true
          elseif d == '^' then caret = true
          else table.insert(items, d) end
          j = j + 2
        elseif pat:sub(j + 1, j + 1) == '-' and pat:sub(j + 2, j + 2) ~= ']' and pat:sub(j + 2, j + 2) ~= '' then
          table.insert(items, ch .. '-' .. pat:sub(j + 2, j + 2)); j = j + 3
        else
          if ch == ']' then rbracket = true
          elseif ch == '-' then dash = true
          elseif ch == '^' then caret = true
          else table.insert(items, ch) end
          j = j + 1
        end
        first = false
      end
      local body = (rbracket and ']' or '') .. table.concat(items) .. (caret and '^' or '') .. (dash and '-' or '')
      if body == '^' and not negate then
        push('\\^', true)
      else
        push('[' .. (negate and '^' or '') .. body .. ']', true)
      end
      i = j + 1
    elseif c == '(' then
      push('\\(', false); i = i + 1
    elseif c == ')' then
      push('\\)', false); i = i + 1
    elseif (c == '*' or c == '+' or c == '?') and quantifiable then
      push(c, false); i = i + 1
    elseif c == '-' and quantifiable then
      push('*?', false); i = i + 1
    elseif c == '.' then
      push('.', true); i = i + 1
    else
      push(literal(c), true); i = i + 1
    end
  end
  return table.concat(out)
end

-- Patterns sorted like `vim.filetype` does: non-negative priorities first,
-- each group by descending priority.  Ties are ordered by text for stable
-- output; Neovim leaves their order unspecified.
local patterns_pos, patterns_neg, skipped = {}, {}, 0
for parent, map in pairs(ft.pattern) do
  for pat, rule in pairs(map) do
    local opts = (type(rule) == 'table' and type(rule[2]) == 'table') and rule[2] or {}
    local priority = opts.priority or 0
    local value = eval_rule(rule, '/aaa')
    local parent_re, pat_re = convert_pattern(parent), convert_pattern(pat)
    if value and parent_re and pat_re then
      local entry = { parent_re, pat_re, value, pat:find('/') ~= nil, priority, parent .. '\0' .. pat }
      table.insert(priority >= 0 and patterns_pos or patterns_neg, entry)
    else
      skipped = skipped + 1
    end
  end
end
local function by_priority(a, b)
  if a[5] ~= b[5] then return a[5] > b[5] end
  return a[6] < b[6]
end
table.sort(patterns_pos, by_priority)
table.sort(patterns_neg, by_priority)

local function pattern_lines(list)
  local lines = {}
  for _, e in ipairs(list) do
    table.insert(lines, string.format('(%s %s %s %s)', el_str(e[1]), el_str(e[2]), el_str(e[3]), e[4] and 't' or 'nil'))
  end
  return lines
end

local function string_map_lines(t)
  local lines = {}
  for _, k in ipairs(sorted_keys(t)) do
    table.insert(lines, string.format('(%s . %s)', el_str(k), el_str(t[k])))
  end
  return lines
end

-- Write mini-icons-data.el ---------------------------------------------------------
local function defconst(name, doc, lines)
  return string.format("(defconst %s\n  '(%s)\n  %s)\n", name, table.concat(lines, '\n    '), el_str(doc))
end

local default_lines = {}
for _, cat in ipairs(sorted_keys(H.default_icons)) do
  local v = H.default_icons[cat]
  table.insert(default_lines, string.format('(%s %s . %s)', cat, el_str(v.glyph), color_of(v.hl)))
end

local data = {
  ';;; mini-icons-data.el --- Generated data for mini-icons  -*- lexical-binding: t; coding: utf-8 -*-',
  '',
  ';; This file is generated by scripts/generate.lua.  Do not edit it by hand.',
  ';;',
  string.format(';; Icon data comes from mini.icons (revision %s),', mini_rev),
  ';; Copyright (c) 2021 Evgeni Chasnovski, released under the MIT License.',
  string.format(';; Filetype detection data comes from Neovim %s,', nvim_version),
  ';; released under the Apache License 2.0.',
  '',
  ';;; Code:',
  '',
  string.format("(defconst mini-icons-data-source '(:mini-icons %s :neovim %s)\n  %s)\n",
    el_str(mini_rev), el_str(nvim_version), el_str('Versions of mini.icons and Neovim the data was generated from.')),
  defconst('mini-icons-data-default', 'Fallback icons per category: (CATEGORY GLYPH . COLOR).', default_lines),
}
for _, cat in ipairs({ 'directory', 'extension', 'file', 'filetype', 'lsp', 'os' }) do
  table.insert(data, defconst('mini-icons-data-' .. cat,
    string.format('Built-in %s icons.\nEach element is (NAME GLYPH . COLOR) or (NAME . FILETYPE).', cat),
    icon_table(H[cat .. '_icons'])))
end
table.insert(data, defconst('mini-icons-data-ft-extension',
  'Neovim filetype per file extension: (EXTENSION . FILETYPE).', string_map_lines(ft_extension)))
table.insert(data, defconst('mini-icons-data-ft-filename',
  'Neovim filetype per file name or full path: (NAME . FILETYPE).', string_map_lines(ft_filename)))
table.insert(data, defconst('mini-icons-data-ft-patterns-pos',
  'Neovim filetype patterns with non-negative priority.\nEach element is (PARENT REGEXP FILETYPE HAS-SLASH).',
  pattern_lines(patterns_pos)))
table.insert(data, defconst('mini-icons-data-ft-patterns-neg',
  'Neovim filetype patterns with negative priority.\nEach element is (PARENT REGEXP FILETYPE HAS-SLASH).',
  pattern_lines(patterns_neg)))
table.insert(data, "(provide 'mini-icons-data)\n;;; mini-icons-data.el ends here")

vim.fn.writefile(vim.split(table.concat(data, '\n'), '\n'), root .. '/mini-icons-data.el')

-- Write test/expected.eld ------------------------------------------------------------
local samples = {
  directory = vim.list_extend(sorted_keys(H.directory_icons), { 'unknown-dir', 'foo/bar/.git', 'foo/src/' }),
  filetype = vim.list_extend(sorted_keys(H.filetype_icons), { 'unknown-filetype' }),
  lsp = vim.list_extend(sorted_keys(H.lsp_icons), { 'unknown-kind' }),
  os = vim.list_extend(sorted_keys(H.os_icons), { 'unknown-os' }),
  extension = vim.list_extend(sorted_keys(H.extension_icons), { 'tar.gz', 'd.ts', 'test.js', 'min.js', 'unknownext' }),
  file = vim.list_extend(sorted_keys(H.file_icons), {
    '/etc/hosts', '/etc/systemd/system/foo.service', '/etc/nginx/nginx.conf', '.git/config', 'repo/.git/config',
    'Dockerfile.dev', 'Containerfile', '.env.local', 'docker-compose.yml', 'compose.yaml',
    '.github/workflows/ci.yml', 'CMakeLists.txt', 'foo.tar.gz', 'archive.tar.xz', 'x.d.ts', 'x.test.ts',
    'README', 'README.md', 'LICENSE', 'noext', 'UPPER.PY', 'foo.PDF', 'dir/sub/file.py', 'a.b.c.json',
    'init.el', 'early-init.el', '.emacs', 'foo.org', 'foo.elc', 'requirements.txt', 'uv.lock',
    '.python-version', '.gitignore', 'COMMIT_EDITMSG', 'foo.h', 'foo.m', 'foo.pl', 'Justfile', 'justfile',
  }),
}
for ext, _ in pairs(ft.extension) do
  table.insert(samples.extension, ext:lower())
  table.insert(samples.file, 'aaa.' .. ext)
end
for name, _ in pairs(ft.filename) do
  table.insert(samples.file, name)
end

local expected = { ';; -*- coding: utf-8 -*-', ';; Generated by scripts/generate.lua: (CATEGORY NAME GLYPH COLOR DEFAULTP)', '(' }
for _, cat in ipairs({ 'directory', 'extension', 'file', 'filetype', 'lsp', 'os' }) do
  local seen = {}
  for _, name in ipairs(samples[cat]) do
    if not seen[name] then
      seen[name] = true
      local icon, hl, is_default = MiniIcons.get(cat, name)
      table.insert(expected, string.format(' (%s %s %s %s %s)', cat, el_str(name), el_str(icon), color_of(hl), is_default and 't' or 'nil'))
    end
  end
end
for _, cat in ipairs(sorted_keys(H.default_icons)) do
  local icon, hl = MiniIcons.get('default', cat)
  table.insert(expected, string.format(' (default %s %s %s nil)', el_str(cat), el_str(icon), color_of(hl)))
end
table.insert(expected, ')')
vim.fn.writefile(expected, root .. '/test/expected.eld')

print(string.format('mini.icons %s, Neovim %s: %d extensions, %d file names, %d+%d patterns (%d skipped), %d expected results',
  mini_rev, nvim_version, vim.tbl_count(ft_extension), vim.tbl_count(ft_filename),
  #patterns_pos, #patterns_neg, skipped, #expected - 4))

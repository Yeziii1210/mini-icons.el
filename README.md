# mini-icons for Emacs

An Emacs port of [mini.icons](https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-icons.md),
the icon provider of mini.nvim.

It resolves icons for files, directories, extensions, filetypes, LSP kinds and
operating systems the same way mini.icons does, including its fallback to
Neovim's filetype detection. The same file gets the same glyph and the same
color in Emacs and in Neovim.

- **Faithful.** The resolution order and data come straight from mini.icons and
  Neovim. The test suite checks 4,200+ results recorded from Neovim, and every
  one of them matches.
- **Self-contained.** No dependency on nerd-icons or all-the-icons. Neovim is
  only needed to regenerate the data.
- **Integrated.** Comes with integrations for minibuffer completion (Vertico,
  Marginalia, …), Corfu, Dirvish, Treemacs and Magit.

## Requirements

- Emacs 29.1 or later.
- A [Nerd Font](https://www.nerdfonts.com/), for example *Symbols Nerd Font Mono*.

## Installation

With `use-package` on Emacs 30 or later:

```elisp
(use-package mini-icons
  :vc (:url "https://github.com/Yeziii1210/mini-icons.el" :rev :newest))
```

On Emacs 29, run `M-x package-vc-install` and enter
`https://github.com/Yeziii1210/mini-icons.el`.

### Font

Icons are Nerd Font glyphs. Either tell mini-icons which font to use:

```elisp
(setopt mini-icons-font-family "Symbols Nerd Font Mono")
```

or map the Nerd Font ranges for all text, which also covers icons inserted by
other packages:

```elisp
(set-fontset-font t '(#xe000 . #xf8ff) "Symbols Nerd Font Mono" nil 'prepend)
(set-fontset-font t '(#xf0000 . #xffffd) "Symbols Nerd Font Mono" nil 'prepend)
```

## Usage

`mini-icons-get` mirrors `MiniIcons.get()` and returns `(ICON FACE DEFAULTP)`:

```elisp
(mini-icons-get 'file "init.lua")      ;=> ("" mini-icons-green nil)
(mini-icons-get 'extension "py")       ;=> ("󰌠" mini-icons-yellow nil)
(mini-icons-get 'directory ".git")     ;=> ("" mini-icons-orange nil)
(mini-icons-get 'lsp "function")       ;=> ("" mini-icons-azure nil)
(mini-icons-get 'file "unknown")       ;=> ("󰈔" mini-icons-grey t)
```

Categories are `default`, `directory`, `extension`, `file`, `filetype`, `lsp`
and `os`, as in mini.icons.

Propertized strings for direct use:

| Function | Returns the icon of |
| --- | --- |
| `(mini-icons-icon CATEGORY NAME &key face height)` | any name in any category |
| `(mini-icons-icon-for-file FILE)` | a file, or a directory when FILE ends in `/` |
| `(mini-icons-icon-for-dir DIR)` | a directory |
| `(mini-icons-icon-for-mode &optional MODE)` | a major mode |
| `(mini-icons-icon-for-buffer &optional BUFFER)` | a buffer: by file name, Dired directory or major mode |

`mini-icons-filetype-match` exposes the port of `vim.filetype.match()`:

```elisp
(mini-icons-filetype-match "Dockerfile.dev")  ;=> "dockerfile"
```

## Integrations

### Minibuffer completion

Adds icons to files, buffers, bookmarks, commands, variables, faces and more.
It works with the default UI, Vertico and Marginalia:

```elisp
(use-package mini-icons-completion
  :ensure nil
  :hook (marginalia-mode . mini-icons-completion-marginalia-setup))
```

Without Marginalia, enable `mini-icons-completion-mode` instead.

### Corfu

```elisp
(with-eval-after-load 'corfu
  (require 'mini-icons-corfu)
  (add-to-list 'corfu-margin-formatters #'mini-icons-corfu-formatter))
```

### Dirvish

```elisp
(with-eval-after-load 'dirvish
  (require 'mini-icons-dirvish)
  (mini-icons-dirvish-mode 1))   ; icons in parent windows too
(setopt dirvish-attributes '(mini-icons file-size))
```

### Treemacs

```elisp
(with-eval-after-load 'treemacs
  (require 'mini-icons-treemacs)
  (treemacs-load-theme "mini-icons"))
```

Set `mini-icons-treemacs-chevrons` to nil to hide the directory chevrons.

### Magit

```elisp
(setopt magit-format-file-function #'mini-icons-magit-format-file)
```

### Mode line and other places

Use the string functions directly, for example:

```elisp
(setq-default mode-line-format
              (cons '(:eval (concat (mini-icons-icon-for-buffer) " "))
                    mode-line-format))
```

## Customization

The options mirror the mini.icons configuration:

| Option | Meaning |
| --- | --- |
| `mini-icons-style` | `glyph` or `ascii` (first letter of the name, no special font needed) |
| `mini-icons-default`, `mini-icons-directory`, `mini-icons-extension`, `mini-icons-file`, `mini-icons-filetype`, `mini-icons-lsp`, `mini-icons-os` | Custom icons per category |
| `mini-icons-use-file-extension` | Predicate deciding whether an extension is used for file icons |
| `mini-icons-mode-alist` | Icons for major modes |
| `mini-icons-font-family` | Font family for icons |

A custom icon is `(NAME . (GLYPH . COLOR))`. COLOR is one of `azure`, `blue`,
`cyan`, `green`, `grey`, `orange`, `purple`, `red` and `yellow`, or any face.
Either part may be nil to keep the built-in value:

```elisp
(setopt mini-icons-file '(("init.lua" . ("󰢱" . green))
                          ("README.md" . (nil . red))))
```

The nine colors are the faces `mini-icons-azure` … `mini-icons-yellow`. Their
defaults follow the Kanagawa palette that kanagawa.nvim uses for mini.icons.
Customize them to match your theme.

Major modes not listed in `mini-icons-mode-alist` use the filetype named after
the mode without its `-ts-mode` or `-mode` suffix (`python-ts-mode` →
`python`), then fall back to their parent modes.

## Differences from mini.icons

- Neovim filetype rules that compute the filetype with Lua code are evaluated
  once, for an empty file, when the data is generated. This matches how
  mini.icons calls `vim.filetype.match()`. A few path pattern rules whose result
  depends on the matched text cannot be precomputed and are left out.
- `mini-icons-mode-alist` and the buffer and mode helpers are Emacs additions.
- `MiniIcons.mock_nvim_web_devicons()` and `MiniIcons.tweak_lsp_kind()` have
  no equivalent. The integrations above cover their use in Emacs.

## Regenerating the data

`mini-icons-data.el` and `test/expected.eld` are generated from mini.icons and
Neovim:

```sh
make generate MINI_ICONS=/path/to/mini.icons
make test
```

`MINI_ICONS` may point to mini.icons or mini.nvim. Without it, the script tries
`:packadd mini.icons` and `:packadd mini.nvim`.

## License

MIT. `mini-icons-data.el` contains data derived from
[mini.icons](https://github.com/nvim-mini/mini.nvim) (MIT, © Evgeni
Chasnovski) and from Neovim's filetype detection (Apache License 2.0). See
[LICENSE](LICENSE).

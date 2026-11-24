;;; mini-icons.el --- Icon provider ported from mini.icons  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Yeziii1210

;; Author: Yeziii1210
;; URL: https://github.com/Yeziii1210/mini-icons.el
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, files, faces
;; SPDX-License-Identifier: MIT

;; This file is not part of GNU Emacs.

;;; Commentary:

;; An Emacs port of mini.icons, the icon provider of mini.nvim
;; <https://github.com/nvim-mini/mini.nvim>.  It resolves icons for
;; files, directories, extensions, filetypes, LSP kinds and operating
;; systems exactly like mini.icons does, including the fallback to
;; Neovim's filetype detection, so Emacs and Neovim show the same icon
;; with the same color for the same file.
;;
;; Icons are Nerd Font glyphs.  Install a Nerd Font (for example
;; "Symbols Nerd Font Mono") and either set `mini-icons-font-family' or
;; map the Nerd Font ranges with `set-fontset-font'.
;;
;; Main entry points:
;;
;; - `mini-icons-get' returns (ICON FACE DEFAULTP), like `MiniIcons.get()'.
;; - `mini-icons-icon' returns a propertized icon string.
;; - `mini-icons-icon-for-file', `mini-icons-icon-for-dir',
;;   `mini-icons-icon-for-mode' and `mini-icons-icon-for-buffer' are
;;   convenience wrappers for common Emacs objects.
;;
;; Integrations with completion, Corfu, Dirvish, Treemacs and Magit live
;; in the mini-icons-*.el files of this package.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'mini-icons-data)

(defvar dired-directory)

(defgroup mini-icons nil
  "Icon provider ported from mini.icons."
  :group 'convenience
  :prefix "mini-icons-"
  :link '(url-link "https://github.com/Yeziii1210/mini-icons.el"))

(defgroup mini-icons-faces nil
  "Faces used by mini-icons."
  :group 'mini-icons
  :group 'faces)

;;;; Faces

;; Defaults follow the Kanagawa palette used by kanagawa.nvim for the
;; MiniIcons* highlight groups: "wave" on dark and "lotus" on light
;; backgrounds.

(defface mini-icons-azure
  '((((background light)) :foreground "#6693bf")
    (t :foreground "#7FB4CA"))
  "Azure icon color."
  :group 'mini-icons-faces)

(defface mini-icons-blue
  '((((background light)) :foreground "#4d699b")
    (t :foreground "#7E9CD8"))
  "Blue icon color."
  :group 'mini-icons-faces)

(defface mini-icons-cyan
  '((((background light)) :foreground "#597b75")
    (t :foreground "#7AA89F"))
  "Cyan icon color."
  :group 'mini-icons-faces)

(defface mini-icons-green
  '((((background light)) :foreground "#6f894e")
    (t :foreground "#98BB6C"))
  "Green icon color."
  :group 'mini-icons-faces)

(defface mini-icons-grey
  '((((background light)) :foreground "#545464")
    (t :foreground "#DCD7BA"))
  "Grey icon color."
  :group 'mini-icons-faces)

(defface mini-icons-orange
  '((((background light)) :foreground "#cc6d00")
    (t :foreground "#FFA066"))
  "Orange icon color."
  :group 'mini-icons-faces)

(defface mini-icons-purple
  '((((background light)) :foreground "#624c83")
    (t :foreground "#957FB8"))
  "Purple icon color."
  :group 'mini-icons-faces)

(defface mini-icons-red
  '((((background light)) :foreground "#c84053")
    (t :foreground "#FF5D62"))
  "Red icon color."
  :group 'mini-icons-faces)

(defface mini-icons-yellow
  '((((background light)) :foreground "#77713f")
    (t :foreground "#E6C384"))
  "Yellow icon color."
  :group 'mini-icons-faces)

(defconst mini-icons-colors
  '(azure blue cyan green grey orange purple red yellow)
  "Color names of mini.icons, each with a `mini-icons-COLOR' face.")

;;;; Options

(defvar mini-icons--cache nil
  "Hash table mapping a category to its hash table of resolved icons.")

(defun mini-icons--set-and-reset (symbol value)
  "Set SYMBOL to VALUE and clear the icon cache."
  (set-default-toplevel-value symbol value)
  (setq mini-icons--cache nil))

(define-widget 'mini-icons-icon-spec 'lazy
  "An icon specification: a glyph and a color, either may be omitted."
  :type '(cons (choice :tag "Glyph" (const :tag "Built-in" nil) string)
               (choice :tag "Color" (const :tag "Built-in" nil)
                       (symbol :tag "Color name or face"))))

(defcustom mini-icons-style 'glyph
  "Icon style.
The value `glyph' uses Nerd Font glyphs.  The value `ascii' uses the
upper-cased first character of the name instead, which needs no
special font."
  :type '(choice (const glyph) (const ascii))
  :set #'mini-icons--set-and-reset)

(defcustom mini-icons-default nil
  "Custom fallback icons per category.
Each element is (CATEGORY . (GLYPH . COLOR)), where CATEGORY is one of
`default', `directory', `extension', `file', `filetype', `lsp' and
`os'.  GLYPH is a string and COLOR is a color name from
`mini-icons-colors' or a face.  Either may be nil to keep the built-in
value."
  :type '(alist :key-type symbol :value-type mini-icons-icon-spec)
  :set #'mini-icons--set-and-reset)

(defcustom mini-icons-directory nil
  "Custom directory icons: (NAME . (GLYPH . COLOR)).
See `mini-icons-default' for the meaning of GLYPH and COLOR."
  :type '(alist :key-type string :value-type mini-icons-icon-spec)
  :set #'mini-icons--set-and-reset)

(defcustom mini-icons-extension nil
  "Custom extension icons: (EXTENSION . (GLYPH . COLOR)).
EXTENSION is lower case and has no leading dot.  See
`mini-icons-default' for the meaning of GLYPH and COLOR."
  :type '(alist :key-type string :value-type mini-icons-icon-spec)
  :set #'mini-icons--set-and-reset)

(defcustom mini-icons-file nil
  "Custom file icons: (NAME . (GLYPH . COLOR)).
NAME is a file name without directory.  See `mini-icons-default' for
the meaning of GLYPH and COLOR."
  :type '(alist :key-type string :value-type mini-icons-icon-spec)
  :set #'mini-icons--set-and-reset)

(defcustom mini-icons-filetype nil
  "Custom filetype icons: (FILETYPE . (GLYPH . COLOR)).
FILETYPE is a Neovim filetype name.  See `mini-icons-default' for the
meaning of GLYPH and COLOR."
  :type '(alist :key-type string :value-type mini-icons-icon-spec)
  :set #'mini-icons--set-and-reset)

(defcustom mini-icons-lsp nil
  "Custom LSP kind icons: (KIND . (GLYPH . COLOR)).
KIND is a lower case LSP kind name such as \"function\".  See
`mini-icons-default' for the meaning of GLYPH and COLOR."
  :type '(alist :key-type string :value-type mini-icons-icon-spec)
  :set #'mini-icons--set-and-reset)

(defcustom mini-icons-os nil
  "Custom operating system icons: (NAME . (GLYPH . COLOR)).
See `mini-icons-default' for the meaning of GLYPH and COLOR."
  :type '(alist :key-type string :value-type mini-icons-icon-spec)
  :set #'mini-icons--set-and-reset)

(defcustom mini-icons-use-file-extension #'always
  "Predicate deciding whether an extension is used for a file icon.
It is called with the lower case extension and the file name, like
`use_file_extension' of mini.icons.  When it returns nil, file icon
resolution skips the extension and relies on filetype detection."
  :type 'function
  :set #'mini-icons--set-and-reset)

(defcustom mini-icons-font-family nil
  "Font family for icons, or nil to rely on the fontset.
Set it to a Nerd Font family such as \"Symbols Nerd Font Mono\" unless
the Nerd Font ranges are already mapped with `set-fontset-font'."
  :type '(choice (const :tag "Use fontset" nil) string))

(defcustom mini-icons-mode-alist
  '((emacs-lisp-mode . "lisp")
    (lisp-interaction-mode . "lisp")
    (lisp-data-mode . "lisp")
    (inferior-emacs-lisp-mode . "lisp")
    (js-mode . "javascript")
    (js-ts-mode . "javascript")
    (js-json-mode . "json")
    (tsx-ts-mode . "typescriptreact")
    (c++-mode . "cpp")
    (c++-ts-mode . "cpp")
    (objc-mode . "objc")
    (sh-mode . "sh")
    (latex-mode . "tex")
    (LaTeX-mode . "tex")
    (makefile-mode . "make")
    (conf-toml-mode . "toml")
    (mhtml-mode . "html")
    (nxml-mode . "xml")
    (gfm-mode . "markdown")
    (help-mode . "help")
    (helpful-mode . "help")
    (Info-mode . "info")
    (Man-mode . "man")
    (woman-mode . "man")
    (messages-buffer-mode . "messages")
    (calendar-mode . "calendar")
    (message-mode . "mail")
    (pdf-view-mode . "pdf")
    (doc-view-mode . "pdf")
    (dired-mode . (default "directory"))
    (git-commit-mode . "gitcommit")
    (git-rebase-mode . "neogitrebasetodo")
    (magit-status-mode . "neogitstatus")
    (magit-log-mode . "neogitlogview")
    (magit-diff-mode . "neogitdiffview")
    (magit-refs-mode . "neogitrefsview")
    (magit-reflog-mode . "neogitreflogview")
    (magit-mode . "git"))
  "Icons for major modes.
Each element is (MODE . VALUE).  VALUE is a Neovim filetype name, a
list (CATEGORY NAME) to use the icon of NAME in CATEGORY, or a cons
\(GLYPH . COLOR).  Modes not listed here map to the filetype named
after the mode without its \"-ts-mode\" or \"-mode\" suffix, and then
fall back to their parent modes."
  :type '(alist :key-type symbol
                :value-type (choice (string :tag "Filetype")
                                    (list :tag "Category and name" symbol string)
                                    (cons :tag "Glyph and color" string symbol))))

;;;; Data tables

(defun mini-icons--hash (alist)
  "Return an `equal' hash table built from ALIST."
  (let ((table (make-hash-table :test #'equal :size (length alist))))
    (dolist (entry alist table)
      (puthash (car entry) (cdr entry) table))))

(defconst mini-icons--builtin
  (list (cons 'directory (mini-icons--hash mini-icons-data-directory))
        (cons 'extension (mini-icons--hash mini-icons-data-extension))
        (cons 'file (mini-icons--hash mini-icons-data-file))
        (cons 'filetype (mini-icons--hash mini-icons-data-filetype))
        (cons 'lsp (mini-icons--hash mini-icons-data-lsp))
        (cons 'os (mini-icons--hash mini-icons-data-os)))
  "Built-in icon tables per category.")

(defconst mini-icons--ft-extension (mini-icons--hash mini-icons-data-ft-extension)
  "Neovim filetype per file extension.")

(defconst mini-icons--ft-filename (mini-icons--hash mini-icons-data-ft-filename)
  "Neovim filetype per file name or full path.")

(defconst mini-icons-categories
  '(default directory extension file filetype lsp os)
  "Categories supported by `mini-icons-get'.")

(defun mini-icons--custom-alist (category)
  "Return the user option holding custom icons of CATEGORY."
  (pcase category
    ('default mini-icons-default)
    ('directory mini-icons-directory)
    ('extension mini-icons-extension)
    ('file mini-icons-file)
    ('filetype mini-icons-filetype)
    ('lsp mini-icons-lsp)
    ('os mini-icons-os)))

(defun mini-icons--custom (category name)
  "Return the custom icon spec of NAME in CATEGORY, if any."
  (cdr (assoc name (mini-icons--custom-alist category))))

;;;; Resolution

(defun mini-icons--face (color)
  "Return the face for COLOR, a color name or a face."
  (if (memq color mini-icons-colors)
      (intern (format "mini-icons-%s" color))
    color))

(defun mini-icons--style (glyph name)
  "Return GLYPH or, in ascii style, the upper-cased first character of NAME."
  (if (or (not (eq mini-icons-style 'ascii)) (string-empty-p name))
      glyph
    (upcase (substring name 0 1))))

(defun mini-icons--basename (name)
  "Return the last component of NAME, ignoring one trailing slash."
  (file-name-nondirectory (string-remove-suffix "/" name)))

(defun mini-icons--table-icon (category name)
  "Return the built-in icon of NAME in CATEGORY as (GLYPH . FACE).
Entries referring to a filetype are resolved through it."
  (let ((value (gethash name (alist-get category mini-icons--builtin))))
    (cond ((stringp value) (mini-icons--pair 'filetype value))
          (value (cons (mini-icons--style (car value) name)
                       (mini-icons--face (cdr value)))))))

(defun mini-icons--pair (category name)
  "Return the icon of NAME in CATEGORY as (GLYPH . FACE)."
  (let ((icon (mini-icons-get category name)))
    (cons (nth 0 icon) (nth 1 icon))))

(defun mini-icons--dot-suffixes (name start)
  "Return suffixes of NAME after each dot at or after START.
A dot only counts when another character follows it, like the Lua
pattern \"%..\" used by mini.icons."
  (let (suffixes)
    (while (string-match "\\.." name start)
      (push (substring name (1+ (match-beginning 0))) suffixes)
      (setq start (1+ (match-beginning 0))))
    (nreverse suffixes)))

(defun mini-icons--get-directory (name)
  "Resolve the directory icon of NAME."
  (mini-icons--table-icon 'directory name))

(defun mini-icons--get-extension (name)
  "Resolve the extension icon of NAME."
  (or (mini-icons--table-icon 'extension name)
      ;; Parts of a complex extension, such as "gz" of "tar.gz".
      (seq-some (lambda (ext)
                  (when (or (gethash ext (alist-get 'extension mini-icons--builtin))
                            (mini-icons--custom 'extension ext))
                    (mini-icons--pair 'extension ext)))
                (mini-icons--dot-suffixes name 0))
      (when-let* ((ft (mini-icons-filetype-match (concat "aaa." name))))
        (mini-icons--pair 'filetype ft))))

(defun mini-icons--get-file (name)
  "Resolve the file icon of NAME, a file name or path."
  (let ((basename (mini-icons--basename name)))
    (or (and (mini-icons--custom 'file basename)
             (not (equal name basename))
             (mini-icons--pair 'file basename))
        (mini-icons--table-icon 'file basename)
        (when-let* ((ext (car (mini-icons--dot-suffixes basename 1)))
                    (ext (downcase ext))
                    ((funcall mini-icons-use-file-extension ext name))
                    (icon (mini-icons-get 'extension ext))
                    ((not (nth 2 icon))))
          (cons (nth 0 icon) (nth 1 icon)))
        (when-let* ((ft (mini-icons-filetype-match name)))
          (mini-icons--pair 'filetype ft)))))

(defun mini-icons--resolve (category name)
  "Resolve NAME in CATEGORY without custom icons as (GLYPH . FACE) or nil."
  (pcase category
    ('directory (mini-icons--get-directory name))
    ('extension (mini-icons--get-extension name))
    ('file (mini-icons--get-file name))
    (_ (mini-icons--table-icon category name))))

(defun mini-icons--fallback (category)
  "Return the fallback icon of CATEGORY as (GLYPH . FACE)."
  (let* ((builtin (alist-get category mini-icons-data-default))
         (custom (mini-icons--custom 'default category)))
    (cons (mini-icons--style (or (car custom) (car builtin)) (symbol-name category))
          (mini-icons--face (or (cdr custom) (cdr builtin))))))

(defun mini-icons--compute (category name)
  "Compute the (ICON FACE DEFAULTP) list of NAME in CATEGORY."
  (if (eq category 'default)
      (let ((icon (mini-icons--fallback (intern name))))
        (list (car icon) (cdr icon) nil))
    (let ((custom (mini-icons--custom category name)))
      (if-let* ((icon (if (and (car custom) (cdr custom))
                          (cons (mini-icons--style (car custom) name)
                                (mini-icons--face (cdr custom)))
                        (let ((builtin (or (mini-icons--resolve category name)
                                           (and custom (mini-icons--fallback category)))))
                          (and builtin
                               (cons (if (car custom)
                                         (mini-icons--style (car custom) name)
                                       (car builtin))
                                     (if (cdr custom)
                                         (mini-icons--face (cdr custom))
                                       (cdr builtin))))))))
          (list (car icon) (cdr icon) nil)
        (let ((fallback (mini-icons--fallback category)))
          (list (car fallback) (cdr fallback) t))))))

(defun mini-icons--category-cache (category)
  "Return the cache table of CATEGORY."
  (unless mini-icons--cache
    (setq mini-icons--cache (make-hash-table :test #'eq)))
  (or (gethash category mini-icons--cache)
      (puthash category (make-hash-table :test #'equal) mini-icons--cache)))

;;;###autoload
(defun mini-icons-get (category name)
  "Return the icon data of NAME in CATEGORY as (ICON FACE DEFAULTP).

CATEGORY is one of `mini-icons-categories'.  NAME is a string; for the
`default' category it names the category whose fallback is wanted.
ICON is a string, FACE a face and DEFAULTP is non-nil when the result
is the fallback icon of CATEGORY.  This mirrors `MiniIcons.get()'."
  (unless (memq category mini-icons-categories)
    (error "Unsupported mini-icons category: %S" category))
  (let* ((name (if (symbolp name) (symbol-name name) name))
         (key (pcase category
                ('file name)
                ('directory (mini-icons--basename name))
                (_ (downcase name))))
         (cache (mini-icons--category-cache category)))
    (or (gethash key cache)
        (puthash key (mini-icons--compute category key) cache))))

;;;###autoload
(defun mini-icons-list (category)
  "Return the sorted names with an explicit icon in CATEGORY."
  (let ((names (mapcar #'car (mini-icons--custom-alist category))))
    (if (eq category 'default)
        (setq names (append (mapcar #'symbol-name (mapcar #'car mini-icons-data-default))
                            (mapcar #'symbol-name names)))
      (maphash (lambda (name _) (push name names))
               (alist-get category mini-icons--builtin)))
    (sort (delete-dups names) #'string<)))

;;;###autoload
(defun mini-icons-reset ()
  "Clear the icon cache, for example after changing icon options."
  (interactive)
  (setq mini-icons--cache nil))

;;;; Neovim filetype detection

(defvar mini-icons--pattern-env-cache (make-hash-table :test #'equal)
  "Cache of environment variable expansion results for patterns.")

(defun mini-icons--expand-env (regexp)
  "Expand ${VAR} references in REGEXP, or return nil if a VAR is unset."
  (if (not (string-search "${" regexp))
      regexp
    (catch 'unset
      (replace-regexp-in-string
       "\\${\\([^}]+\\)}"
       (lambda (match)
         (let ((value (getenv (substring match 2 -1))))
           (unless value (throw 'unset nil))
           (regexp-quote value)))
       regexp t t))))

(defun mini-icons--pattern-match (regexp has-slash name path tail &optional all)
  "Return non-nil if REGEXP matches like a `vim.filetype' pattern.
HAS-SLASH selects matching against NAME and PATH instead of TAIL.  With
ALL, try PATH, NAME and TAIL, as done for parent patterns."
  (when-let* ((expanded (mini-icons--expand-env regexp)))
    (setq has-slash (or has-slash
                        (and (not (eq expanded regexp))
                             (string-search "/" expanded))))
    (cond (all (or (string-match-p expanded path)
                   (string-match-p expanded name)
                   (string-match-p expanded tail)))
          (has-slash (or (string-match-p expanded name)
                         (string-match-p expanded path)))
          (t (string-match-p expanded tail)))))

(defun mini-icons--match-patterns (patterns name path tail parents)
  "Return the filetype of the first of PATTERNS matching NAME.
PATH is the absolute file name and TAIL its last component.  PARENTS
caches parent pattern results."
  (seq-some
   (lambda (entry)
     (pcase-let ((`(,parent ,regexp ,filetype ,has-slash) entry))
       (and (let ((cached (gethash parent parents 'unknown)))
              (if (eq cached 'unknown)
                  (puthash parent
                           (and (mini-icons--pattern-match parent nil name path tail t) t)
                           parents)
                cached))
            (mini-icons--pattern-match regexp has-slash name path tail)
            filetype)))
   patterns))

;;;###autoload
(defun mini-icons-filetype-match (name)
  "Return the Neovim filetype of file NAME, or nil.
This reproduces `vim.filetype.match()' with an empty buffer, which is
how mini.icons detects filetypes.  Relative names are expanded against
`default-directory'.  Content-based rules give their result for an
empty file, and pattern rules computed by Lua functions are omitted."
  (let* ((case-fold-search nil)
         (name (string-replace "\\" "/" name))
         (name (if (string-prefix-p "~" name)
                   (concat (getenv "HOME") (substring name 1))
                 name))
         (path (expand-file-name name))
         (tail (mini-icons--basename name))
         (parents (make-hash-table :test #'equal)))
    (or (gethash path mini-icons--ft-filename)
        (gethash tail mini-icons--ft-filename)
        (mini-icons--match-patterns mini-icons-data-ft-patterns-pos name path tail parents)
        (gethash (if (string-match "\\.\\([^.]*\\)\\'" name) (match-string 1 name) "")
                 mini-icons--ft-extension)
        (mini-icons--match-patterns mini-icons-data-ft-patterns-neg name path tail parents)
        ;; Generic configuration file fallback (`detect.conf' on an empty buffer).
        (and (string-match-p "\\.conf\\'" name) "conf"))))

;;;; Strings for Emacs objects

(cl-defun mini-icons--propertize (icon icon-face &key face height)
  "Return ICON propertized with ICON-FACE, or FACE when non-nil.
HEIGHT scales the icon."
  (propertize icon 'face
              `(:inherit ,(or face icon-face)
                ,@(and mini-icons-font-family `(:family ,mini-icons-font-family))
                ,@(and height `(:height ,height)))))

;;;###autoload
(defun mini-icons-icon (category name &rest args)
  "Return the icon of NAME in CATEGORY as a propertized string.
ARGS are keyword arguments: `:face' replaces the icon color and
`:height' scales the icon.  See `mini-icons-get' for CATEGORY and NAME."
  (pcase-let ((`(,icon ,icon-face) (mini-icons-get category name)))
    (apply #'mini-icons--propertize icon icon-face args)))

;;;###autoload
(defun mini-icons-icon-for-file (file &rest args)
  "Return the icon string for FILE.
A FILE ending in a slash is treated as a directory.  ARGS are passed to
`mini-icons-icon'."
  (apply #'mini-icons-icon
         (if (string-suffix-p "/" file) 'directory 'file) file args))

;;;###autoload
(defun mini-icons-icon-for-dir (dir &rest args)
  "Return the icon string for directory DIR.
ARGS are passed to `mini-icons-icon'."
  (apply #'mini-icons-icon 'directory dir args))

(defun mini-icons--mode-spec (mode)
  "Return the `mini-icons-mode-alist' value for MODE or its parents."
  (let (spec)
    (while (and mode (not spec))
      (setq spec (or (alist-get mode mini-icons-mode-alist)
                     (let ((filetype (downcase (replace-regexp-in-string
                                                "\\(-ts\\)?-mode\\'" "" (symbol-name mode)))))
                       (and (or (gethash filetype (alist-get 'filetype mini-icons--builtin))
                                (mini-icons--custom 'filetype filetype))
                            filetype)))
            mode (get mode 'derived-mode-parent)))
    spec))

;;;###autoload
(defun mini-icons-icon-for-mode (&optional mode &rest args)
  "Return the icon string for major MODE, by default `major-mode'.
See `mini-icons-mode-alist'.  ARGS are passed to `mini-icons-icon'."
  (let ((spec (mini-icons--mode-spec (or mode major-mode))))
    (cond ((stringp spec) (apply #'mini-icons-icon 'filetype spec args))
          ((and (consp spec) (symbolp (car spec)))
           (apply #'mini-icons-icon (car spec) (cadr spec) args))
          ((consp spec)
           (apply #'mini-icons--propertize
                  (mini-icons--style (car spec) (symbol-name (or mode major-mode)))
                  (mini-icons--face (cdr spec))
                  args))
          (t (apply #'mini-icons-icon 'default "filetype" args)))))

;;;###autoload
(defun mini-icons-icon-for-buffer (&optional buffer &rest args)
  "Return the icon string for BUFFER, by default the current buffer.
File buffers use their file name, Dired buffers the directory icon and
other buffers their major mode.  ARGS are passed to `mini-icons-icon'."
  (with-current-buffer (or buffer (current-buffer))
    (cond ((and (derived-mode-p 'dired-mode) (stringp dired-directory))
           (apply #'mini-icons-icon-for-dir dired-directory args))
          (buffer-file-name
           (apply #'mini-icons-icon 'file (file-name-nondirectory buffer-file-name) args))
          (t (apply #'mini-icons-icon-for-mode major-mode args)))))

(provide 'mini-icons)
;;; mini-icons.el ends here

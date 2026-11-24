;;; mini-icons-test.el --- Tests for mini-icons  -*- lexical-binding: t; -*-

;;; Commentary:

;; `mini-icons-test-matches-mini-icons' compares every result recorded
;; from Neovim in test/expected.eld by scripts/generate.lua.

;;; Code:

(require 'ert)
(require 'mini-icons)

(defconst mini-icons-test--dir
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory of this test file.")

(defun mini-icons-test--expected ()
  "Read the expected results recorded from Neovim."
  (with-temp-buffer
    (insert-file-contents (expand-file-name "expected.eld" mini-icons-test--dir))
    (read (current-buffer))))

(defmacro mini-icons-test--with-defaults (&rest body)
  "Run BODY with default options and an empty cache."
  (declare (indent 0))
  `(let ((mini-icons-style 'glyph)
         (mini-icons-default nil)
         (mini-icons-directory nil)
         (mini-icons-extension nil)
         (mini-icons-file nil)
         (mini-icons-filetype nil)
         (mini-icons-lsp nil)
         (mini-icons-os nil)
         (mini-icons-use-file-extension #'always)
         (mini-icons--cache nil)
         (default-directory "/"))
     ,@body))

(ert-deftest mini-icons-test-matches-mini-icons ()
  "Every recorded `MiniIcons.get()' result is reproduced."
  (mini-icons-test--with-defaults
    (let ((failures nil) (total 0))
      (dolist (entry (mini-icons-test--expected))
        (pcase-let* ((`(,category ,name ,glyph ,color ,defaultp) entry)
                     (`(,icon ,face ,is-default) (mini-icons-get category name)))
          (setq total (1+ total))
          (unless (and (equal icon glyph)
                       (eq face (intern (format "mini-icons-%s" color)))
                       (eq (and is-default t) defaultp))
            (push (list category name :expected glyph color defaultp
                        :got icon face is-default)
                  failures))))
      (should (> total 4000))
      (should (equal (nreverse failures) nil)))))

(ert-deftest mini-icons-test-custom-icons ()
  "Custom icons override built-in ones and may set only one part."
  (mini-icons-test--with-defaults
    (let ((mini-icons-file '(("init.lua" . ("X" . red))
                             ("README.md" . (nil . green))))
          (mini-icons-extension '(("foo" . ("F" . blue))))
          (mini-icons-default '((file . ("D" . nil)))))
      (should (equal (mini-icons-get 'file "init.lua") '("X" mini-icons-red nil)))
      (should (equal (mini-icons-get 'file "dir/init.lua") '("X" mini-icons-red nil)))
      (should (equal (cdr (mini-icons-get 'file "README.md")) '(mini-icons-green nil)))
      (should (equal (mini-icons-get 'file "a.foo") '("F" mini-icons-blue nil)))
      (should (equal (mini-icons-get 'extension "bar.foo") '("F" mini-icons-blue nil)))
      (should (equal (mini-icons-get 'file "unknown") '("D" mini-icons-grey t))))))

(ert-deftest mini-icons-test-ascii-style ()
  "The ascii style uses the first character of the name."
  (mini-icons-test--with-defaults
    (let ((mini-icons-style 'ascii))
      (should (equal (car (mini-icons-get 'file "init.lua")) "I"))
      (should (equal (car (mini-icons-get 'extension "py")) "P"))
      (should (equal (car (mini-icons-get 'default "file")) "F")))))

(ert-deftest mini-icons-test-use-file-extension ()
  "Skipping an extension falls back to filetype detection."
  (mini-icons-test--with-defaults
    (let ((mini-icons-use-file-extension (lambda (ext _file) (not (equal ext "txt")))))
      (should (equal (mini-icons-get 'file "CMakeLists.txt")
                     (mini-icons-get 'filetype "cmake"))))))

(ert-deftest mini-icons-test-modes ()
  "Major modes map to filetype icons."
  (mini-icons-test--with-defaults
    (should (equal (substring-no-properties (mini-icons-icon-for-mode 'emacs-lisp-mode))
                   (car (mini-icons-get 'filetype "lisp"))))
    (should (equal (substring-no-properties (mini-icons-icon-for-mode 'python-ts-mode))
                   (car (mini-icons-get 'filetype "python"))))
    (should (equal (substring-no-properties (mini-icons-icon-for-mode 'fundamental-mode))
                   (car (mini-icons-get 'default "filetype"))))))

(ert-deftest mini-icons-test-icon-properties ()
  "Icon strings carry the color face and optional overrides."
  (mini-icons-test--with-defaults
    (let ((icon (mini-icons-icon 'file "init.lua" :height 0.8)))
      (should (equal (get-text-property 0 'face icon)
                     `(:inherit ,(nth 1 (mini-icons-get 'file "init.lua")) :height 0.8))))
    (let ((icon (mini-icons-icon-for-file "src/" :face 'bold)))
      (should (equal (get-text-property 0 'face icon) '(:inherit bold))))))

(ert-deftest mini-icons-test-list ()
  "Listing returns sorted names of explicit icons."
  (mini-icons-test--with-defaults
    (let ((names (mini-icons-list 'lsp)))
      (should (member "function" names))
      (should (equal names (sort (copy-sequence names) #'string<))))))

(provide 'mini-icons-test)
;;; mini-icons-test.el ends here

;;; mini-icons-corfu.el --- Icons for Corfu  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Yeziii1210
;; SPDX-License-Identifier: MIT

;; This file is not part of GNU Emacs.

;;; Commentary:

;; A Corfu margin formatter showing the LSP kind icons of mini.icons:
;;
;;   (add-to-list 'corfu-margin-formatters #'mini-icons-corfu-formatter)

;;; Code:

(require 'mini-icons)

(defgroup mini-icons-corfu nil
  "Icons for Corfu."
  :group 'mini-icons
  :prefix "mini-icons-corfu-")

(defcustom mini-icons-corfu-kind-alist
  '((enum-member . "enummember")
    (type-parameter . "typeparameter")
    (param . "variable")
    (numeric . "number")
    (macro . "keyword")
    (magic . "keyword")
    (command . "function"))
  "LSP kind names for completion kinds named differently.
Each element is (KIND . LSP-KIND), where KIND is a symbol returned by
the `:company-kind' function and LSP-KIND a lower case LSP kind name.
Other kinds are used by name; unknown ones get the LSP fallback icon."
  :type '(alist :key-type symbol :value-type string))

(defun mini-icons-corfu--space ()
  "Return a half-width space on graphical frames and a space otherwise."
  (if (display-graphic-p) (propertize " " 'display '(space :width 0.5)) " "))

(defun mini-icons-corfu--icon (kind cand)
  "Return the icon for completion KIND of candidate CAND."
  (pcase kind
    ('file (mini-icons-icon-for-file cand))
    ('folder (mini-icons-icon-for-dir cand))
    (_ (mini-icons-icon 'lsp (or (alist-get kind mini-icons-corfu-kind-alist)
                                 (if kind (symbol-name kind) ""))))))

;;;###autoload
(defun mini-icons-corfu-formatter (_metadata)
  "Corfu margin formatter adding mini-icons for completion kinds."
  (when-let* ((kind-function (plist-get completion-extra-properties :company-kind)))
    (let ((space (mini-icons-corfu--space)))
      (lambda (cand)
        (concat (and (display-graphic-p) space)
                (mini-icons-corfu--icon (funcall kind-function cand) cand)
                space)))))

(provide 'mini-icons-corfu)
;;; mini-icons-corfu.el ends here

;;; mini-icons-completion.el --- Icons for completion candidates  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Yeziii1210
;; SPDX-License-Identifier: MIT

;; This file is not part of GNU Emacs.

;;; Commentary:

;; `mini-icons-completion-mode' prefixes minibuffer completion candidates
;; with mini-icons.  Files, buffers and bookmarks get file icons, while
;; symbol-like categories use the LSP kind icons of mini.icons.  It works
;; with the default completion UI, Vertico, Marginalia and similar
;; packages, because it extends the `affixation-function' of the
;; completion metadata.

;;; Code:

(require 'mini-icons)

(declare-function bookmark-get-filename "bookmark")
(defvar bookmark-alist)
(defvar marginalia-mode)

(defgroup mini-icons-completion nil
  "Icons for completion candidates."
  :group 'mini-icons
  :prefix "mini-icons-completion-")

(defcustom mini-icons-completion-category-icons
  '((command lsp "function")
    (function lsp "function")
    (variable lsp "variable")
    (symbol lsp "constant")
    (symbol-help lsp "keyword")
    (face lsp "color")
    (theme lsp "color")
    (package lsp "package")
    (library lsp "module")
    (input-method lsp "keyword")
    (coding-system lsp "file")
    (kill-ring lsp "text")
    (imenu lsp "reference")
    (xref-location lsp "reference")
    (environment-variable lsp "variable")
    (unicode-name lsp "text")
    (org-roam-node filetype "org"))
  "Icons for completion categories without candidate-specific icons.
Each element is (CATEGORY ICON-CATEGORY NAME), passed as
\(mini-icons-icon ICON-CATEGORY NAME).  Categories not listed here, and
not handled specially, get no icon."
  :type '(alist :key-type symbol :value-type (list symbol string)))

(defcustom mini-icons-completion-icon-height nil
  "Height of completion icons, or nil for the default height."
  :type '(choice (const :tag "Default" nil) number))

(defconst mini-icons-completion-lsp-kinds
  ["" "text" "method" "function" "constructor" "field" "variable" "class"
   "interface" "module" "property" "unit" "value" "enum" "keyword" "snippet"
   "color" "file" "reference" "folder" "enummember" "constant" "struct"
   "event" "operator" "typeparameter"]
  "LSP CompletionItemKind names indexed by their numeric value.")

(defun mini-icons-completion--icon (category name)
  "Return the icon of NAME in CATEGORY followed by a space."
  (concat (mini-icons-icon category name :height mini-icons-completion-icon-height) " "))

(defun mini-icons-completion--file-icon (file)
  "Return the icon of FILE followed by a space."
  (concat (mini-icons-icon-for-file file :height mini-icons-completion-icon-height) " "))

(defun mini-icons-completion--lsp-kind-icon (kind)
  "Return the icon for numeric LSP KIND, or an empty string."
  (if (and (integerp kind) (< 0 kind (length mini-icons-completion-lsp-kinds)))
      (mini-icons-completion--icon 'lsp (aref mini-icons-completion-lsp-kinds kind))
    ""))

(defun mini-icons-completion-get-icon (cand category)
  "Return the icon prefix for candidate CAND of completion CATEGORY."
  (pcase category
    ((or 'file 'project-file) (mini-icons-completion--file-icon cand))
    ((or 'buffer 'project-buffer)
     (if-let* ((buffer (get-buffer cand)))
         (concat (mini-icons-icon-for-buffer buffer :height mini-icons-completion-icon-height) " ")
       ""))
    ('bookmark
     (if-let* (((assoc cand (bound-and-true-p bookmark-alist)))
               (file (bookmark-get-filename cand)))
         (mini-icons-completion--file-icon file)
       (mini-icons-completion--icon 'lsp "reference")))
    ((or 'eglot 'eglot-capf)
     (mini-icons-completion--lsp-kind-icon
      (plist-get (get-text-property 0 'eglot--lsp-item cand) :kind)))
    (_ (if-let* ((spec (alist-get category mini-icons-completion-category-icons)))
           (mini-icons-completion--icon (car spec) (cadr spec))
         ""))))

(defun mini-icons-completion--metadata-get (orig metadata prop)
  "Add icons to the `affixation-function' returned by ORIG.
ORIG is `completion-metadata-get', called with METADATA and PROP."
  (if (not (eq prop 'affixation-function))
      (funcall orig metadata prop)
    (let* ((category (funcall orig metadata 'category))
           (affix (or (funcall orig metadata 'affixation-function)
                      (when-let* ((annotate (funcall orig metadata 'annotation-function)))
                        (lambda (cands)
                          (mapcar (lambda (cand) (list cand "" (or (funcall annotate cand) "")))
                                  cands)))
                      (lambda (cands) (mapcar (lambda (cand) (list cand "" "")) cands))))
           (icon (if (eq category 'multi-category)
                     (lambda (cand)
                       (let ((orig-cand (get-text-property 0 'multi-category cand)))
                         (mini-icons-completion-get-icon (cdr orig-cand) (car orig-cand))))
                   (lambda (cand) (mini-icons-completion-get-icon cand category)))))
      (lambda (cands)
        (mapcar (pcase-lambda (`(,cand ,prefix ,suffix))
                  (list cand (concat (funcall icon cand) prefix) suffix))
                (funcall affix cands))))))

;;;###autoload
(define-minor-mode mini-icons-completion-mode
  "Prefix completion candidates with mini-icons."
  :global t
  :group 'mini-icons-completion
  (dolist (fn '(completion-metadata-get compat--completion-metadata-get))
    (when (fboundp fn)
      (if mini-icons-completion-mode
          (advice-add fn :around #'mini-icons-completion--metadata-get)
        (advice-remove fn #'mini-icons-completion--metadata-get)))))

;;;###autoload
(defun mini-icons-completion-marginalia-setup ()
  "Enable `mini-icons-completion-mode' together with `marginalia-mode'.
Add this function to `marginalia-mode-hook'."
  (mini-icons-completion-mode (if marginalia-mode 1 -1)))

(provide 'mini-icons-completion)
;;; mini-icons-completion.el ends here

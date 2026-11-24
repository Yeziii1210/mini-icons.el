;;; mini-icons-treemacs.el --- Treemacs theme using mini-icons  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Yeziii1210
;; SPDX-License-Identifier: MIT

;; This file is not part of GNU Emacs.

;;; Commentary:

;; A Treemacs theme named "mini-icons":
;;
;;   (with-eval-after-load 'treemacs
;;     (require 'mini-icons-treemacs)
;;     (treemacs-load-theme "mini-icons"))
;;
;; Treemacs looks icons up by lower case file name, then by extension,
;; and directories by name, so the theme registers every name and
;; extension known to mini-icons.

;;; Code:

(require 'mini-icons)
(require 'treemacs)

(defgroup mini-icons-treemacs nil
  "Treemacs theme using mini-icons."
  :group 'mini-icons
  :prefix "mini-icons-treemacs-")

(defcustom mini-icons-treemacs-chevrons t
  "Whether directory icons are preceded by an open or closed chevron."
  :type 'boolean)

(defface mini-icons-treemacs-chevron-face
  '((t :inherit mini-icons-grey))
  "Face for directory chevrons in the mini-icons Treemacs theme."
  :group 'mini-icons-treemacs)

(defun mini-icons-treemacs--icon (icon &optional chevron)
  "Return ICON with a separator for Treemacs.
CHEVRON is `open' or `closed' for directory icons."
  (let ((sep (propertize "\t" 'face 'default)))
    (concat (when (and chevron mini-icons-treemacs-chevrons)
              (concat (propertize (string (if (eq chevron 'open) #xf47c #xf460))
                                  'face 'mini-icons-treemacs-chevron-face)
                      sep))
            icon sep)))

(defun mini-icons-treemacs--file-keys ()
  "Return (KEY . FILE) pairs for Treemacs file icon lookup."
  (let (pairs)
    (dolist (ext (append (mapcar #'car mini-icons-data-ft-extension)
                         (mini-icons-list 'extension)))
      (push (cons (downcase ext) (concat "aaa." ext)) pairs))
    (dolist (name (append (mapcar #'car mini-icons-data-ft-filename)
                          (mini-icons-list 'file)))
      (unless (string-search "/" name)
        (push (cons (downcase name) name) pairs)))
    (nreverse pairs)))

(treemacs-create-theme "mini-icons"
  :config
  (let ((gui-icons (treemacs-theme->gui-icons treemacs--current-theme))
        (tui-icons (treemacs-theme->tui-icons treemacs--current-theme)))
    (pcase-dolist (`(,key . ,file) (mini-icons-treemacs--file-keys))
      (let ((icon (mini-icons-treemacs--icon (mini-icons-icon 'file file))))
        (ht-set! gui-icons key icon)
        (ht-set! tui-icons key icon)))
    (dolist (name (mini-icons-list 'directory))
      (let ((key (downcase (string-remove-prefix "." name))))
        (dolist (state '(open closed))
          (let ((icon (mini-icons-treemacs--icon (mini-icons-icon-for-dir name) state)))
            (ht-set! gui-icons (format "%s-%s" key state) icon)
            (ht-set! tui-icons (format "%s-%s" key state) icon)))))
    (treemacs-create-icon
     :icon (mini-icons-treemacs--icon (mini-icons-icon 'directory "Projects"))
     :extensions (root-open root-closed)
     :fallback 'same-as-icon)
    (treemacs-create-icon
     :icon (mini-icons-treemacs--icon (mini-icons-icon 'default "directory") 'open)
     :extensions (dir-open)
     :fallback 'same-as-icon)
    (treemacs-create-icon
     :icon (mini-icons-treemacs--icon (mini-icons-icon 'default "directory") 'closed)
     :extensions (dir-closed)
     :fallback 'same-as-icon)
    (treemacs-create-icon
     :icon (mini-icons-treemacs--icon (mini-icons-icon 'lsp "module"))
     :extensions (tag-open tag-closed)
     :fallback 'same-as-icon)
    (treemacs-create-icon
     :icon (mini-icons-treemacs--icon (mini-icons-icon 'lsp "struct"))
     :extensions (tag-leaf)
     :fallback 'same-as-icon)
    (treemacs-create-icon
     :icon (mini-icons-treemacs--icon (mini-icons-icon 'lsp "event"))
     :extensions (error)
     :fallback 'same-as-icon)
    (treemacs-create-icon
     :icon (mini-icons-treemacs--icon (mini-icons-icon 'lsp "reference"))
     :extensions (warning info)
     :fallback 'same-as-icon)
    (treemacs-create-icon
     :icon (mini-icons-treemacs--icon (mini-icons-icon 'default "file"))
     :extensions (fallback)
     :fallback 'same-as-icon)))

(provide 'mini-icons-treemacs)
;;; mini-icons-treemacs.el ends here

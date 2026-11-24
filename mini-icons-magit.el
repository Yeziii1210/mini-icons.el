;;; mini-icons-magit.el --- Icons for Magit file lists  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Yeziii1210
;; SPDX-License-Identifier: MIT

;; This file is not part of GNU Emacs.

;;; Commentary:

;; A `magit-format-file-function' showing mini-icons:
;;
;;   (setopt magit-format-file-function #'mini-icons-magit-format-file)

;;; Code:

(require 'mini-icons)

(declare-function magit--get-file-icon "magit-diff")

(defun mini-icons-magit--submodule-p (_dir)
  "Return nil; Magit rebinds this for submodule entries."
  nil)

(defun mini-icons-magit--icon-for-dir (dir)
  "Return the icon of DIR, using the Git icon for submodules."
  (if (mini-icons-magit--submodule-p dir)
      (mini-icons-icon 'filetype "git")
    (mini-icons-icon-for-dir dir)))

;;;###autoload
(defun mini-icons-magit-format-file (kind file face &optional status orig)
  "Format FILE for Magit with a mini-icons icon.
KIND, FACE, STATUS and ORIG are as for `magit-format-file-function'."
  (magit--get-file-icon kind file face status orig
                        #'mini-icons-icon-for-file
                        #'mini-icons-magit--icon-for-dir
                        'mini-icons-magit--submodule-p))

(provide 'mini-icons-magit)
;;; mini-icons-magit.el ends here

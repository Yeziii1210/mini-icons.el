;;; mini-icons-dirvish.el --- Icons for Dirvish  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Yeziii1210
;; SPDX-License-Identifier: MIT

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Defines the `mini-icons' Dirvish attribute.  Use it in place of
;; `nerd-icons' in `dirvish-attributes':
;;
;;   (with-eval-after-load 'dirvish (require 'mini-icons-dirvish))
;;   (setopt dirvish-attributes '(mini-icons file-size))
;;
;; Dirvish only knows its built-in icon backends for parent directory
;; windows, so `mini-icons-dirvish-mode' also adds the attribute there.

;;; Code:

(require 'mini-icons)
(require 'dirvish)

(defgroup mini-icons-dirvish nil
  "Icons for Dirvish."
  :group 'mini-icons
  :prefix "mini-icons-dirvish-")

(defcustom mini-icons-dirvish-delimiter " "
  "String inserted after each icon."
  :type 'string)

(defcustom mini-icons-dirvish-icon-height nil
  "Height of Dirvish icons, or nil for the default height."
  :type '(choice (const :tag "Default" nil) number))

(defcustom mini-icons-dirvish-icon-function nil
  "Function returning the icon of a file line, or nil for the default.
It is called with the absolute file name and its type, `dir' or
`file', and returns an icon string.  This allows, for example, showing
file icons for package directories such as \".app\" bundles."
  :type '(choice (const :tag "Default" nil) function))

(defun mini-icons-dirvish-icon (file type)
  "Return the icon string of FILE with TYPE, `dir' or `file'."
  (if (eq type 'dir)
      (mini-icons-icon-for-dir file :height mini-icons-dirvish-icon-height)
    (mini-icons-icon 'file file :height mini-icons-dirvish-icon-height)))

(dirvish-define-attribute mini-icons
  "File icons provided by `mini-icons'."
  :width (+ (length mini-icons-dirvish-delimiter) 2)
  (let* ((icon (copy-sequence
                (funcall (or mini-icons-dirvish-icon-function #'mini-icons-dirvish-icon)
                         f-name (car f-type))))
         (icon-str (concat icon (propertize mini-icons-dirvish-delimiter 'face hl-face)))
         (ov (make-overlay (1- f-beg) f-beg)))
    (when hl-face
      ;; Keep the icon color and take the background of the current line.
      (add-face-text-property 0 (length icon) hl-face t icon-str))
    (overlay-put ov 'after-string icon-str)
    `(ov . ,ov)))

(defun mini-icons-dirvish--parent-buffer (orig dv &rest args)
  "Call ORIG with DV and ARGS, then show icons in the parent buffer."
  (let ((buffer (apply orig dv args)))
    (when (memq 'mini-icons (mapcar #'car (dv-attributes dv)))
      (with-current-buffer buffer
        (dirvish-prop :attrs (dirvish--attrs-expand '(mini-icons)))))
    buffer))

;;;###autoload
(define-minor-mode mini-icons-dirvish-mode
  "Show the `mini-icons' attribute in Dirvish parent windows too."
  :global t
  :group 'mini-icons-dirvish
  (if mini-icons-dirvish-mode
      (advice-add 'dirvish--create-parent-buffer :around #'mini-icons-dirvish--parent-buffer)
    (advice-remove 'dirvish--create-parent-buffer #'mini-icons-dirvish--parent-buffer)))

(provide 'mini-icons-dirvish)
;;; mini-icons-dirvish.el ends here

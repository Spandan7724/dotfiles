;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)
;; The theme follows the desktop theme (~/.config/themes, Super+Shift+T): its
;; doom.el sets `doom-theme', and the switcher reloads it in a running Emacs.
(load (expand-file-name "~/.config/themes/current/doom.el") t t)
;; Specify both a dark and light theme, like so and Doom will choose which one
;; to load based on your system light/dark setting:
;;
;;   (setq doom-theme '(doom-one   . doom-one-light))   ; (DARK . LIGHT)
;;
;; If you want more pro-active theme switching based on OS light/dark mode, look
;; up the `auto-dark' package.

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; Tell Waybar's tray entry (waybar/scripts/emacs-tray.sh) when this Emacs
;; starts or stops, so the bar never has to poll for it. Signal 9 is that
;; module's refresh signal. On exit the signal goes out a second later, once
;; the server socket is gone.
(defun dotfiles/notify-waybar (&optional delay)
  (call-process "sh" nil 0 nil "-c"
                (format "sleep %s; pkill -RTMIN+9 -x waybar" (or delay 0))))
(add-hook 'emacs-startup-hook (lambda () (dotfiles/notify-waybar 1)))
(add-hook 'kill-emacs-hook (lambda () (dotfiles/notify-waybar 1)))

;; Autosave notes (~/notes, the Super+Shift+N launcher's folder, and
;; `org-directory') straight to their real files, so nothing typed is lost
;; to a crash, a power-off or a closed window. Other files keep Doom's usual
;; behaviour. Notes save after a few idle seconds, and also whenever a frame
;; closes, Emacs loses focus, or Emacs is killed (e.g. SIGTERM at shutdown).
(defun dotfiles/note-buffer-p ()
  (and buffer-file-name
       (seq-some (lambda (dir)
                   (file-in-directory-p buffer-file-name dir))
                 (list "~/notes/" org-directory))))

(defun dotfiles/save-notes (&rest _)
  (save-some-buffers t #'dotfiles/note-buffer-p))

(setq auto-save-visited-interval 1
      auto-save-visited-predicate #'dotfiles/note-buffer-p)
(auto-save-visited-mode 1)

(add-hook 'delete-frame-functions #'dotfiles/save-notes)
(add-hook 'kill-emacs-hook #'dotfiles/save-notes)
(add-function :after after-focus-change-function #'dotfiles/save-notes)

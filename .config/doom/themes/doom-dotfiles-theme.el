;;; doom-dotfiles-theme.el --- palette from the desktop theme -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; For desktop themes without a matching Doom theme. themes/generate.py writes
;; ~/.config/themes/<theme>/doom-palette.el from that theme's colors.toml; this
;; file is re-read every time the theme is loaded, so switching desktop themes
;; picks up the new palette.

(require 'doom-themes)

(defvar dotfiles-doom-dark t)
(defvar dotfiles-doom-bold-keywords nil)
(defvar dotfiles-doom-bold-functions nil)
(defvar dotfiles-doom-italic-comments nil)
(defvar dotfiles-doom-italic-strings nil)
(defvar dotfiles-doom-palette nil)
(load (expand-file-name "~/.config/themes/current/doom-palette.el") t t)

(defun dotfiles-doom--color (name)
  "Palette color NAME in doom-themes' (GUI 256 16) form."
  (let ((hex (or (alist-get name dotfiles-doom-palette) "#808080")))
    (list hex hex nil)))

(def-doom-theme doom-dotfiles
  "Generated from the current desktop theme's palette."
  :family 'doom-dotfiles
  :background-mode (if dotfiles-doom-dark 'dark 'light)

  ;; name        default
  ((bg         (dotfiles-doom--color 'bg))
   (bg-alt     (dotfiles-doom--color 'bg-alt))
   (base0      (dotfiles-doom--color 'base0))
   (base1      (dotfiles-doom--color 'base1))
   (base2      (dotfiles-doom--color 'base2))
   (base3      (dotfiles-doom--color 'base3))
   (base4      (dotfiles-doom--color 'base4))
   (base5      (dotfiles-doom--color 'base5))
   (base6      (dotfiles-doom--color 'base6))
   (base7      (dotfiles-doom--color 'base7))
   (base8      (dotfiles-doom--color 'base8))
   (fg         (dotfiles-doom--color 'fg))
   (fg-alt     (dotfiles-doom--color 'fg-alt))

   (grey       base4)
   (red        (dotfiles-doom--color 'red))
   (orange     (dotfiles-doom--color 'orange))
   (green      (dotfiles-doom--color 'green))
   (teal       (dotfiles-doom--color 'teal))
   (yellow     (dotfiles-doom--color 'yellow))
   (blue       (dotfiles-doom--color 'blue))
   (dark-blue  (dotfiles-doom--color 'dark-blue))
   (magenta    (dotfiles-doom--color 'magenta))
   (violet     (dotfiles-doom--color 'violet))
   (cyan       (dotfiles-doom--color 'cyan))
   (dark-cyan  (dotfiles-doom--color 'dark-cyan))
   (accent     (dotfiles-doom--color 'accent))

   ;; face categories -- required for all themes
   ;; Syntax colours come from the theme's [syntax] table (syn-*).
   (highlight      accent)
   (vertical-bar   base1)
   (selection      (dotfiles-doom--color 'selection))
   (builtin        (dotfiles-doom--color 'syn-builtin))
   (comments       (dotfiles-doom--color 'syn-comment))
   (doc-comments   (doom-lighten (dotfiles-doom--color 'syn-comment) 0.15))
   (constants      (dotfiles-doom--color 'syn-constant))
   (functions      (dotfiles-doom--color 'syn-function))
   (keywords       (dotfiles-doom--color 'syn-keyword))
   (methods        (dotfiles-doom--color 'syn-function))
   (operators      (dotfiles-doom--color 'syn-operator))
   (type           (dotfiles-doom--color 'syn-type))
   (strings        (dotfiles-doom--color 'syn-string))
   (variables      (dotfiles-doom--color 'syn-variable))
   (numbers        (dotfiles-doom--color 'syn-number))
   (punctuation    (dotfiles-doom--color 'syn-punctuation))
   (region         selection)
   (error          red)
   (warning        yellow)
   (success        green)
   (vc-modified    orange)
   (vc-added       green)
   (vc-deleted     red)

   ;; custom categories
   (modeline-fg          fg)
   (modeline-fg-alt      fg-alt)
   (modeline-bg          bg-alt)
   (modeline-bg-inactive bg))

  ;;;; Base theme face overrides
  (((line-number &override) :foreground base4)
   (font-lock-keyword-face :foreground keywords :weight (if dotfiles-doom-bold-keywords 'bold 'normal))
   (font-lock-function-name-face :foreground functions :weight (if dotfiles-doom-bold-functions 'bold 'normal))
   (font-lock-comment-face :foreground comments :slant (if dotfiles-doom-italic-comments 'italic 'normal))
   (font-lock-doc-face :inherit 'font-lock-comment-face :foreground doc-comments)
   (font-lock-string-face :foreground strings :slant (if dotfiles-doom-italic-strings 'italic 'normal))
   (font-lock-punctuation-face :foreground punctuation)
   (font-lock-bracket-face :foreground punctuation)
   (font-lock-delimiter-face :foreground punctuation)
   ((line-number-current-line &override) :foreground fg)
   (mode-line :background modeline-bg :foreground modeline-fg)
   (mode-line-inactive :background modeline-bg-inactive :foreground modeline-fg-alt)
   (doom-modeline-bar :background accent)
   (cursor :background accent)
   (solaire-default-face :inherit 'default :background bg-alt)
   (solaire-mode-line-face :inherit 'mode-line :background modeline-bg)
   (solaire-mode-line-inactive-face :inherit 'mode-line-inactive :background modeline-bg-inactive)))

;;; doom-dotfiles-theme.el ends here

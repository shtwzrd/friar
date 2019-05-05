;;; friar.el --- Fennel REPL In Awesome REPL  -*- lexical-binding: t -*-

;;; Commentary:

;; Provides a REPL for interacting with the Awesome window manager
;; using Fennel -- a zero-overhead Lisp implementation in Lua.
;; Input is handled by the comint package, and output is pretty-printed
;; via fennelview within Awesome's Lua context.

;; To start: M-x friar.  Type C-h m in the *friar* buffer for more info.

(require 'dbus)
(require 'comint)
(require 'pp)
(require 'fennel-mode)

;;; User variables

(defgroup friar nil
  "Fennel REPL In Awesome REPL."
  :group 'lisp)

(defvar friar-awesome-logo "
  ██████████
  ▀▀▀▀▀▀▀███
  ██████████
  ███▀▀▀▀███
  ██████ ███
  ▀▀▀▀▀▀ ▀▀▀")

(defcustom friar-fennel-file-path "/usr/bin/fennel"
  "Path to the `fennel` executable, which will be used for interacting with Awesome."
  :group 'friar)

(defcustom friar-mode-hook nil
  "Hooks to be run when friar (`friar-mode') is started."
  :options '(eldoc-mode)
  :type 'hook
  :group 'friar)

(defvar friar-header
  (concat ";; The friar welcomes you."
	  "\n\n"
	  friar-awesome-logo
	  "\n\n")
  "Message displayed on REPL-start.")

(defvar friar-prompt "> ")

(defconst friar-directory
  (if load-file-name
      (file-name-directory load-file-name)
    default-directory))

(defvar friar-fennelview
  (with-temp-buffer
    (insert-file-contents-literally (expand-file-name "./fennelview.lua" friar-directory))
    (buffer-substring-no-properties (point-min) (point-max))))

(defun friar-awesome-eval (lua-chunk)
  (dbus-call-method
   :session
   "org.awesomewm.awful"
   "/"
   "org.awesomewm.awful.Remote"
   "Eval"
   lua-chunk))

(defun friar-process nil
  (get-buffer-process (current-buffer)))

(defun friar-pm nil
  (process-mark (get-buffer-process (current-buffer))))

(defun friar-set-pm (pos)
  (set-marker (process-mark (get-buffer-process (current-buffer))) pos))

(defun friar-is-whitespace-or-comment (string)
  "Return non-nil if STRING is all whitespace or a comment."
  (or (string= string "")
      (string-match-p "\\`[ \t\n]*\\(?:;.*\\)*\\'" string)))

(defun friar-input-sender (_proc input)
  (setq friar-input input)
  (friar-send-input))

(defun friar-send-input (&optional for-effect)
  "Eval Fennel expression at prompt."
  (interactive)
  (friar-eval-input friar-input for-effect))

(defun friar-format-command (str)
  "Generate a shell command for invoking Fennel and compiling given string."
  (format "printf '%s' | %s --compile /dev/stdin" str friar-fennel-file-path))

(defun friar-compile-input (str)
  "Compile given string to Lua using Fennel."
  (let* ((command (friar-format-command str)))
    (with-temp-buffer 
      (shell-command command (current-buffer) "*friar-stderr*")
      (let* ((output (buffer-substring-no-properties (point-min) (point-max)))
	     (err (with-current-buffer "*friar-stderr*" (buffer-substring-no-properties (point-min) (point-max)))))
	(with-current-buffer "*friar-stderr*" (erase-buffer))
	(if (string= "" err)
	  `((:is-error nil) (:result ,output))
	  `((:is-error t) (:result ,err)))))))

(defun friar-eval-input (input-string &optional for-effect)
  "Evaluate the Fennel expression INPUT-STRING, and pretty-print the result."
  ;; This function compiles the input with Fennel and chucks it over to
  ;; Awesome over D-Bus.
  (let ((string input-string)
	(output "")
	(pmark (friar-pm)))
    (unless (friar-is-whitespace-or-comment string)
      (let* ((wrapped-expression (format "(fennelview %s)" input-string))
	     (compilation (friar-compile-input input-string))
	     (compile-output (car (alist-get :result compilation)))
	     (was-compilation-error (car (alist-get :is-error compilation))))
	(setq res (format "%s\n%s" "[Compilation error]:" compile-output))
	(unless was-compilation-error
	  (let* ((expr (car (alist-get :result (friar-compile-input wrapped-expression))))
		 (chunk (format "%s\n%s" friar-fennelview expr)))
	    (setq res (friar-awesome-eval chunk))))
	(goto-char pmark)
	(when (or (not for-effect) (not (equal res "")))
	  (setq output (format "%s\n" res)))
	(setq output (format "%s\n%s" output friar-prompt))
	(comint-output-filter (friar-process) output)
	(friar-set-pm (point-max))))))

(define-derived-mode friar-mode comint-mode "Friar"
  "Major mode for interacting with the Awesome window manager via Fennel.
Uses `comint-mode` as an interface.

\\<friar-mode-map>"
  nil "Friar"
  ;; this transpiles the input from the comint buffer from Fennel to Lua
  (setq comint-input-sender 'friar-input-sender)

  (setq comint-use-prompt-regexp t)

  (setq comint-input-sender-no-newline t)
  (setq comint-process-echoes nil)

  (setq comint-prompt-regexp (concat "^" (regexp-quote friar-prompt)))
  (setq comint-prompt-read-only t)
  (set (make-local-variable 'paragraph-separate) "\\'") ;; allows M-{ to work;
  (set (make-local-variable 'paragraph-start) comint-prompt-regexp)
  (set (make-local-variable 'fill-paragraph-function) 'lisp-fill-paragraph)
  (setq-local comment-start ";")
  (setq-local comment-use-syntax t)
  (set-syntax-table fennel-mode-syntax-table)
  (fennel-font-lock-setup)

  ;; A dummy process for comint. The friar was a fraud all along!
  (unless (comint-check-proc (current-buffer))
    ;; use hexl as the dummy process, because it'll be there if emacs is.
    (start-process "friar" (current-buffer) "hexl")
    (set-process-query-on-exit-flag (friar-process) nil)
    (goto-char (point-max))

    (set (make-local-variable 'comint-inhibit-carriage-motion) t)

    ;; Print the welcome message
    (insert friar-header)
    (friar-set-pm (point-max))
    (unless comint-use-prompt-regexp
      (let ((inhibit-read-only t))
	(add-text-properties
	 (point-min) (point-max)
	 '(rear-nonsticky t field output inhibit-line-move-field-capture t))))
    (comint-output-filter (friar-process) friar-prompt)
    (set-marker comint-last-input-start (friar-pm))
    (set-process-filter (get-buffer-process (current-buffer)) 'comint-output-filter)))

;;;###autoload
(defun friar (&optional buf-name)
  "Interact with the Awesome window manager via a Fennel REPL.
Switches to the buffer named BUF-NAME if provided (`*friar*' by default),
or creates it if it does not exist."
  (interactive)
  (get-buffer-create "*friar-stderr*") ;; create stderr buffer aot
  (let (old-point
	(buf-name (or buf-name "*friar*")))
    (unless (comint-check-proc buf-name)
      (with-current-buffer (get-buffer-create buf-name)
	(unless (zerop (buffer-size)) (setq old-point (point)))
	(friar-mode)))
    (pop-to-buffer-same-window buf-name)
    (when old-point (push-mark old-point))))

(provide 'friar)

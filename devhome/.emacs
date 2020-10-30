;;; minimal emacs-nerd customization for LOCKSS hosts

(setq version-control t)
(setq completion-ignore-case nil)

(global-set-key "\C-z" 'undefined)

(global-set-key [home] 'beginning-of-buffer)
(global-set-key [end] 'end-of-buffer)

(global-set-key "\C-xc" 'compile)
(global-set-key "\C-cg" 'grep-find)
(global-set-key "\C-c\C-c" 'comment-region)
(global-set-key "\C-cb" 'bury-buffer)
(setq grep-program "egrep")

(define-key minibuffer-local-filename-completion-map " "
  'minibuffer-complete-word)

(custom-set-variables
 ;; custom-set-variables was added by Custom.                                   
 ;; If you edit it by hand, you could mess it up, so be careful.                
 ;; Your init file should contain only one such instance.                       
 ;; If there is more than one, they won't work right.                           
 '(dabbrev-abbrev-char-regexp "\\sw\\|\\s_")
 '(electric-indent-mode t)
 '(font-lock-global-modes nil)
 '(global-font-lock-mode nil)
 '(line-move-visual nil)
 '(tool-bar-mode nil)
 '(transient-mark-mode nil)
 '(fill-column 75)
 '(inhibit-startup-message t)
 '(diff-switches "-u")
 '(vc-diff-switches "-u"))

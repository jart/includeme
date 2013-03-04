;;; includeme.el --- Automatic C/C++ '#include' and 'using' in Emacs

;; Copyright (C) 2013 Justine Tunney.

;; Author: Justine Tunney <jtunney@gmail.com>
;; Created: 2013-03-03
;; Version: 0.1
;; Keywords: tools
;; URL: https://github.com/jart/includeme

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; includeme is an extension for GNU Emacs that will automatically insert
;; '#include' and 'using' statements into your source code while you write
;; C/C++ and it's 100% guaranteed to actually work. For instance if you started
;; writing a new C++ program and typed `cout` and then pressed `C-c C-h`,
;; includeme would then insert `#include <stdio>` and `using std::cout` at the
;; top of your file in comformance with Google C++ style requirements.
;;
;; So what's the catch? It only works for popular and standardized APIs. No
;; attempt is made whatsoever to run static analysis tools on your codebase.
;; includeme comes preprogrammed with an efficient lisp binary tree of all the
;; symbol and header definitions for libraries deemed important by Justine
;; Tunney. Things like POSIX, the Standard C Library, C++ STL, etc.

;;; Installation:

;; Run `make` and put this stuff in your `~/.emacs` file:
;;
;;     (eval-after-load 'cc-mode
;;       '(progn
;;          (add-to-list 'load-path "/PATH/TO/INCLUDEME")
;;          (require 'includeme)
;;          (defun my-c-mode-common-hook ()
;;            (define-key c-mode-base-map (kbd "C-c C-h") 'includeme))
;;          (add-hook 'c-mode-common-hook 'my-c-mode-common-hook)))

;;; Code:

(defgroup includeme nil
  "Automatic C/C++ '#include' and 'using' in Emacs"
  :prefix "includeme-"
  :group 'tools)

(provide 'includeme)

;;; includeme.el ends here

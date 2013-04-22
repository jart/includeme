;;; includeme.el --- Auto C/C++ '#include' and 'using' in Emacs

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

;; **Demo Video: <http://www.youtube.com/watch?v=vhs5r-iGpNU>**
;;
;; includeme is an extension for GNU Emacs that will automatically insert
;; `#include` and `using` statements into your source code while you write
;; C/C++ and it's 100% guaranteed to actually work. For instance if you started
;; writing a new C++ program and typed `cout` and then pressed the magic key,
;; includeme would then insert `#include <iostream>` and `using std::cout` at
;; the top of your file.
;;
;; So what's the catch? It only works for popular and standardized
;; APIs. No attempt is made whatsoever to analyse your code. includeme
;; comes with a database of all the symbol and header definitions for
;; libraries deemed important by Justine Tunney. Things like POSIX,
;; the Standard C Library, C++ STL, etc.

;;; Installation:

;; Put this stuff in your init file:
;;
;;     (add-to-list 'load-path "/PATH/TO/INCLUDEME")
;;     (require 'includeme)
;;     (define-key c-mode-base-map (kbd "C-c i") 'includeme)

;;; Code:

(require 'cc-mode)

(defgroup includeme nil
  "Automatically insert '#include' and 'using' statements in C/C++."
  :prefix "includeme-"
  :group 'tools)

(defcustom includeme-indexes '((c-mode "includeme-index-c.el")
                               (c++-mode "includeme-index-cpp.el"))
  "An alist of files for each mode containing symbol/headers tables.

You can use this variable to add your own symbol tables. Here's
an example of how to do it: Create \"my-proj-headers.el\"
somewhere on your emacs load path with the code below. Once
that's done you must customize the variable (M-x
customize-variable) `includeme-indexes' to add the name of your
file to the list for your mode (in this case, c++-mode). Then run
`includeme-reload'.

    ;; my-proj-headers.el
    (setq includeme! '(
      (\"my_proj_func1\" my_proj/funcs.h)  ;; Function with one header.
      (\"my_proj_func2\" my_proj/funcs.h)
      (\"lol::MyClass\" lol/MyClass.h lol/class_defs.h)  ;; Two headers.
      (\"MyClass\" . \"lol::MyClass\")  ;; Use that dot for canonical names.
      ;; etc...
    ))
"
  :group 'includeme
  :type 'alist)

(defconst includeme-match-using
  "^using[ \t]+\\(namespace[ \t]+\\)?[_a-z0-9]+::[_:a-z0-9]+[ \t]*;[ \t]*$"
  "A regular expression for matching using statements.")

(defconst includeme-match-include "^#include "
  "A regular expression for matching include statements.")

(defvar includeme--loaded-indexes nil
  "An alist of the loaded binary tree symbol/header dicts for each mode.")

;;;###autoload
(defun includeme ()
  "Insert headers and using statements necessary to for name
under cursor to compile.

For example if you type \"std::cout\" and run this command in a
C++ buffer, includeme will insert `#include <iostream>` at the
top of your buffer. If you had only typed \"cout\" then includeme
would have also inserted a `using std::cout` statement."
  (interactive "*")
  (let* ((name (includeme--name-at-point))
         (tree (includeme--get-index major-mode))
         (look (includeme--lookup name tree)))
    (if look
        (let ((canonical-name (car look))
              (headers (cdr look))
              (reports nil)
              (did-work nil))
          (while headers
            (setq reports (cons (includeme--insert-include
                                 (symbol-name (car headers)))
                                reports)
                  did-work t
                  headers (cdr headers)))
          (if (and (not (equal name canonical-name))
                   (eq major-mode 'c++-mode))
              (setq reports (cons (includeme--insert-using canonical-name)
                                  reports)
                    did-work t))
          (let ((report (includeme--join (reverse reports) "', '")))
            (if (and report (not (equal report "")))
                (message (format "Inserted: '%s'" report))
              (if did-work
                  (message "Headers already exist :)")))))
      (message (format "Symbol '%s' not found, sorry :(" name)))))

(defun includeme--join (strings &optional sep)
  "Joins a list of strings ignoring nil elements."
  (let (strings-sans-nil)
    (while strings
      (when (car strings)
        (setq strings-sans-nil (cons (car strings) strings-sans-nil)))
      (setq strings (cdr strings)))
    (mapconcat 'identity (reverse strings-sans-nil) (or sep " "))))

(defun includeme--get-index (mode)
  "Returns symbol/header binary tree dict for mode, loading if needed."
  (when (or (not includeme--loaded-indexes)
            (not (assoc mode includeme--loaded-indexes)))
    (when (not (assoc mode includeme-indexes))
      (error (format "%s not supported" mode)))
    (let ((files (cdr (assoc mode includeme-indexes)))
          (items nil))
      (while files
        (let (includeme! loaded)
          (when (if (stringp (car files))
                    (load (car files) t)
                  (if (symbolp (car files))
                      (setq includeme! (eval (car files)))
                    (progn (warn (format "Not a string or symbol: %s"
                                         (car files))) nil)))
            (if includeme!
                (if (and (consp includeme!)
                         (consp (car includeme!))
                         (stringp (caar includeme!)))
                    (setq items (append includeme! items))
                  (warn (format "%s contains the wrong data structure"
                                (car files))))
              (warn (format "%s forgot to run (setq includeme! ...)"
                            (car files)))))
          (setq files (cdr files))))
      (when (not items)
        (error (format "no definitions found for %s" mode)))
      (setq includeme--loaded-indexes
            (cons (cons mode (includeme--make-btree items))
                  includeme--loaded-indexes))))
  (cdr (assoc mode includeme--loaded-indexes)))

(defun includeme--lookup (name tree)
  "Returns `(cons canonical-name list-of-headers)` for NAME in TREE."
  (when (and name tree)
    (let ((headers (includeme--btree-search name tree))
          (canonical-name name))
      (if (stringp headers)
          (setq canonical-name headers
                headers (includeme--btree-search headers tree)))
      (if headers
          (cons canonical-name headers)))))

(defun includeme--btree-search (symbol node)
  "Searches a lisp binary tree."
  (when node
    (let ((comp (compare-strings symbol 0 nil            (caar node) 0 nil)))
      (cond ((eq t comp)                                 (cdar node))
            ((>  0 comp) (includeme--btree-search symbol (cadr node)))
            ((<  0 comp) (includeme--btree-search symbol (cddr node)))))))

(defun includeme--make-btree (items)
  "Constructs a balanced binary tree, destroying ITEMS in process.

ITEMS should be a list of unordered cons cells where `(car cell)`
is a key string and `(cdr cell)` is an arbitrary associated
value."
  (when items
    ;; (assert (consp items))
    ;; (assert (consp (car items)))
    ;; (assert (stringp (caar items)))
    (let ((items (sort items (lambda (a b) (string< (car a) (car b)))))
          (do_node nil))
      (setq do_node (lambda (start end)
                      (when (not (eq end start))
                        (let ((pivot (+ start (/ (- end start) 2))))
                          (cons (nth pivot items)
                                (cons (funcall do_node start pivot)
                                      (funcall do_node (+ pivot 1) end)))))))
      (funcall do_node 0 (length items)))))

(defun includeme--name-at-point ()
  "Returns text under cursor matching `[:a-zA-Z0-9]+`. Like
`\"printf\"` or `\"std::cout\"`. This function was written
because `symbol-at-point' wouldn't give me the namespace."
  (save-excursion
    ;; If they typed the symbol but also typed '(' by mistake before running
    ;; this command, give them a break and move the cursor back.
    (if (and (or (looking-back "(")
                 (looking-back "<"))
             (looking-at "[ \t\n]"))
        (backward-char))
    (condition-case exc
        (let ((start (point))
              (begin (progn
                       (search-backward-regexp "[^_:a-zA-Z0-9]")
                       (forward-char)
                       (point)))
              (end (- (search-forward-regexp "[^_:a-zA-Z0-9]") 1)))
          (if (and (< begin end)
                   (>= start begin)
                   (<= start end))
              (buffer-substring-no-properties begin end)))
      (error (message (format "includeme caught: %s" exc)) nil))))

(defun includeme--forward-line-add-newlines (&optional count)
  "They told me I couldn't use `next-line'."
  (let ((n (or 1 count)))
    (while (> n 0)
      (let ((current-line (line-number-at-pos)))
        (forward-line)
        (if (and (eobp) (eq (line-number-at-pos) current-line))
            (insert "\n")))
      (setq n (- n 1)))))

(defun includeme--does-buffer-contain (regexp)
  "Returns non-nil if current buffer contains text matching REGEXP."
  (save-excursion
    (goto-char 0)
    (search-forward-regexp regexp nil t)))

(defun includeme--goto-line-after-initial-comments ()
  "Places cursor at beginning of line after initial comment section."
  (goto-char 0)
  (let (done)
    (while (and (not done) (not (eobp)))
      (cond ((looking-at "[ \t]*//")       ;; C++ comment.
             (includeme--forward-line-add-newlines))
            ((looking-at "[ \t]*/\\*")     ;; C comment.
             (c-forward-single-comment)
             (if (not (looking-at "[ \t]*\n"))
                 (error "Weird source code."))
             (includeme--forward-line-add-newlines)
             (beginning-of-line))
            ((looking-at "[ \t\n]*/[/*]")  ;; Blank line before comment line.
             (includeme--forward-line-add-newlines))
            (t                             ;; Everything else.
             (setq done t))))))

(defun includeme--goto-line-after-last (regexp)
  "Finds last occurance of REGEXP and goes to beginning of the
following line, inserting one if necessary. Returns non-nil if
successful."
  (let ((res (save-excursion
               (goto-char (point-max))
               (search-backward-regexp regexp nil t))))
    (when res
      (goto-char res)
      (includeme--forward-line-add-newlines)
      (beginning-of-line)
      t)))

(defun includeme--count-looking-at-blank-lines ()
  "Counts number of continuous blank lines from current line."
  ;; (assert (= (point) (save-excursion (move-beginning-of-line 1) (point))))
  (if (eobp)
      1
    (save-excursion
      (let ((count 0))
        (while (and (not (eobp))
                    (looking-at "[ \t]*\n"))
          (setq count (+ 1 count))
          (forward-line))
        count))))

(defun includeme--create-section ()
  "Inserts blank lines at point necessary to create a new code section."
  ;; (assert (or (bobp) (looking-back "\n")))
  ;; (assert (not (looking-back "\n\n")))
  (let ((blanks (includeme--count-looking-at-blank-lines)))
    (if (bobp)
        (open-line (max 0 (min 2 (- 3 blanks))))
      (progn
        (open-line (max 0 (min 2 (- 3 blanks))))
        (forward-line)))))

(defun includeme--insert-include (header)
  "Inserts the text `#include <HEADER>` near the top of your
buffer and returns the inserted string if successful. HEADER
should be a string name of the header you want, including the
\".h\" if applicable. This function tries to be smart about how
it organizes your header file includes."
  (save-excursion
    (let ((line (format "#include <%s>" header)))
      (when (not (includeme--does-buffer-contain
                  (concat "^" (regexp-quote line) "[ \t]*$")))
        (if (includeme--goto-line-after-last includeme-match-include)
            (open-line 1)
          (progn
            (includeme--goto-line-after-initial-comments)
            (includeme--create-section)))
        (insert line)
        line))))

(defun includeme--insert-using (name)
  "Inserts the text `using NAME;` near the top of your buffer and
returns the inserted string if successful. HEADER should be a
string name of the header you want, including the \".h\" if
applicable. This function tries to be smart about how it
organizes your using statements."
  (save-excursion
    (let ((line (format "using %s;" name)))
      (when (not (includeme--does-buffer-contain
                  (concat "^" (regexp-quote line) "[ \t]*$")))
        (if (includeme--goto-line-after-last includeme-match-using)
            (open-line 1)
          (progn
            (or (includeme--goto-line-after-last includeme-match-include)
                (includeme--goto-line-after-initial-comments))
            (includeme--create-section)))
        (insert line)
        line))))

(provide 'includeme)

;;; includeme.el ends here

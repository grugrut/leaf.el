;;; leaf-tests.el ---                                -*- lexical-binding: t; -*-

;; Copyright (C) 2018  Naoya Yamashita

;; Author: Naoya Yamashita <conao3@gmail.com>
;; Maintainer: Naoya Yamashita <conao3@gmail.com>
;; URL: https://github.com/conao3/leaf.el

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the Affero GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the Affero
;; GNU General Public License for more details.

;; You should have received a copy of the Affero GNU General Public
;; License along with this program.  If not, see
;; <https://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(load "cort-test")
(require 'leaf)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  test settings
;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  support legacy Emacs
;;

(when (not (fboundp 'autoload-do-load))
  (defun autoload-do-load (fundef &optional funname macro-only)
    (if (or (not (consp fundef)) (not (eql 'autoload (car fundef))))
        fundef
      (let ((kind (nth 4 fundef)))
        (if (and (eql macro-only 'macro)
                 (not (or (eql kind t)
                          (eql kind 'macro))))
            fundef)
        (if purify-flag
            (error "Attempt to autoload %s while preparing to dump" (symbol-name funnname)))
        (unwind-protect
            (let ((ignore-errors (if (or (eql kind t) (eql kind 'macro)) nil macro_only)))
              (load (cadr fundef) ignore-errors t nil t))
          ;; FIXME: revert partially performed defuns
          ())
        (if (or (not funname) ignore-errors)
            nil
          (let ((fun (indirect-function funname, nil)))
            (if (equal fun fundef)
                (error "Autoloading file %s failed to define function %s"
                       (caar load-history)
                       (symbol-name funname))
              fun)))))))

(when (not (fboundp 'macroexpand-1))
  (defun macroexpand-1 (form &optional environment)
    "Perform (at most) one step of macroexpansion."
    (cond
     ((consp form)
      (let* ((head (car form))
             (env-expander (assq head environment)))
        (if env-expander
            (if (cdr env-expander)
                (apply (cdr env-expander) (cdr form))
              form)
          (if (not (and (symbolp head) (fboundp head)))
              form
            (let ((def (autoload-do-load (symbol-function head) head 'macro)))
              (cond
               ;; Follow alias, but only for macros, otherwise we may end up
               ;; skipping an important compiler-macro (e.g. cl--block-wrapper).
               ((and (symbolp def) (macrop def)) (cons def (cdr form)))
               ((not (consp def)) form)
               (t
                (if (eq 'macro (car def))
                    (apply (cdr def) (cdr form))
                  form))))))))
     (t form))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  support macros for test definition
;;

(defmacro cort-deftest-with-equal (name form)
  "Return `cort-deftest' compare by `equal' for NAME, FORM.

Example:
  (p (cort-deftest-with-equal leaf/disabled
       '((asdf asdf-fn)
         (uiop uiop-fn))))
   => (cort-deftest leaf/disabled
        '((:equal 'asdf asdf-fn)
          (:equal 'uiop uiop-fn)))"
  (declare (indent 1))
  `(cort-deftest ,name
     ',(mapcar (lambda (elm)
                 `(:equal ,(cadr elm) ,(car elm)))
               (cadr form))))

(defmacro cort-deftest-with-macroexpand (name form)
  "Return `cort-deftest' compare by `equal' for NAME, FORM.

Example:
  (p (cort-deftest-with-equal leaf/disabled
       '((asdf asdf)
         (uiop uiop))))
   => (cort-deftest leaf/disabled
        '((:equal 'asdf
                  (macroexpand-1 'asdf))
          (:equal 'uiop
                  (macroexpand-1 'uiop))))"
  (declare (indent 1))
  `(cort-deftest ,name
     ',(mapcar (lambda (elm)
                 `(:equal
                   ',(cadr elm)
                   (macroexpand-1 ',(car elm))))
               (cadr form))))

(defmacro cort-deftest-with-macroexpand-let (name letform form)
  "Return `cort-deftest' compare by `equal' for NAME, LETFORM FORM.

Example:
  (p (cort-deftest-with-macroexpand-let leaf/leaf
         ((leaf-expand-leaf-protect t))
       '(((leaf leaf
            :config (leaf-init))
          (prog1 'leaf
            (leaf-handler-leaf-protect leaf
              (leaf-init)))))))
   => (cort-deftest leaf/leaf
        '((:equal
           '(prog1 'leaf
              (leaf-handler-leaf-protect leaf
                (leaf-init)))
           (let ((leaf-expand-leaf-protect t))
             (macroexpand-1
              '(leaf leaf
                 :config (leaf-init)))))))"
  (declare (indent 2))
  `(cort-deftest ,name
     ',(mapcar (lambda (elm)
                 `(:equal
                   ',(cadr elm)
                   (let ,letform (macroexpand-1 ',(car elm)))))
               (cadr form))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  test definition
;;

(custom-set-variables '(leaf-backend-bind   'bind-key)
                      '(leaf-expand-leaf-protect nil))

(cort-deftest-with-macroexpand leaf/none
  '(((leaf leaf)
     (prog1 'leaf))))

(cort-deftest-with-macroexpand leaf/disabled
  '(((leaf leaf :disabled t       :config (leaf-init))
     (prog1 'leaf))
    ((leaf leaf :disabled nil     :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))
    ((leaf leaf :disabled t t     :config (leaf-init))
     (prog1 'leaf))
    ((leaf leaf :disabled t nil   :config (leaf-init))
     (prog1 'leaf))
    ((leaf leaf :disabled nil t   :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))
    ((leaf leaf :disabled nil nil :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))

    ((leaf leaf :disabled t :disabled t       :config (leaf-init))
     (prog1 'leaf))
    ((leaf leaf :disabled t :disabled nil     :config (leaf-init))
     (prog1 'leaf))
    ((leaf leaf :disabled t :disabled t t     :config (leaf-init))
     (prog1 'leaf))
    ((leaf leaf :disabled t :disabled t nil   :config (leaf-init))
     (prog1 'leaf))
    ((leaf leaf :disabled t :disabled nil t   :config (leaf-init))
     (prog1 'leaf))
    ((leaf leaf :disabled t :disabled nil nil :config (leaf-init))
     (prog1 'leaf))

    ((leaf leaf :disabled nil :disabled t       :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))
    ((leaf leaf :disabled nil :disabled nil     :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))
    ((leaf leaf :disabled nil :disabled t t     :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))
    ((leaf leaf :disabled nil :disabled t nil   :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))
    ((leaf leaf :disabled nil :disabled nil t   :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))
    ((leaf leaf :disabled nil :disabled nil nil :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))

    ((leaf leaf :disabled t :disabled t       :config (leaf-init) :disabled t)
     (prog1 'leaf))
    ((leaf leaf :disabled t :disabled nil     :config (leaf-init) :disabled nil)
     (prog1 'leaf))
    ((leaf leaf :disabled t :disabled t t     :config (leaf-init) :disabled t t)
     (prog1 'leaf))
    ((leaf leaf :disabled t :disabled t nil   :config (leaf-init) :disabled t nil)
     (prog1 'leaf))
    ((leaf leaf :disabled t :disabled nil t   :config (leaf-init) :disabled nil t)
     (prog1 'leaf))
    ((leaf leaf :disabled t :disabled nil nil :config (leaf-init) :disabled nil nil)
     (prog1 'leaf))

    ((leaf leaf :disabled nil :disabled t       :config (leaf-init) :disabled t)
     (prog1 'leaf
       (leaf-init)))
    ((leaf leaf :disabled nil :disabled nil     :config (leaf-init) :disabled nil)
     (prog1 'leaf
       (leaf-init)))
    ((leaf leaf :disabled nil :disabled t t     :config (leaf-init) :disabled t t)
     (prog1 'leaf
       (leaf-init)))
    ((leaf leaf :disabled nil :disabled t nil   :config (leaf-init) :disabled t nil)
     (prog1 'leaf
       (leaf-init)))
    ((leaf leaf :disabled nil :disabled nil t   :config (leaf-init) :disabled nil t)
     (prog1 'leaf
       (leaf-init)))
    ((leaf leaf :disabled nil :disabled nil nil :config (leaf-init) :disabled nil nil)
     (prog1 'leaf
       (leaf-init)))))

(cort-deftest-with-macroexpand leaf/ensure
  '(
    ;; 't will be converted leaf--name
    ((leaf leaf
       :ensure t
       :config (leaf-init))
     (prog1 'leaf
       (leaf-handler-package leaf leaf nil)
       (leaf-init)))

    ;; multi symbols will be accepted
    ((leaf leaf
       :ensure t leaf-browser
       :config (leaf-init))
     (prog1 'leaf
       (leaf-handler-package leaf leaf nil)
       (leaf-handler-package leaf leaf-browser nil)
       (leaf-init)))

    ;; multi symbols in list will be accepted
    ((leaf leaf
       :ensure (feather leaf-key leaf-browser)
       :config (leaf-init))
     (prog1 'leaf
       (leaf-handler-package leaf feather nil)
       (leaf-handler-package leaf leaf-key nil)
       (leaf-handler-package leaf leaf-browser nil)
       (leaf-init)))

    ;; ensure from pin
    ((leaf leaf
       :ensure (t . pin))
     (prog1 'leaf
       (leaf-handler-package leaf leaf pin)))))

(cort-deftest-with-macroexpand leaf/package
  '(((leaf leaf
       :package t
       :config (leaf-init))
     (prog1 'leaf
       (leaf-handler-package leaf leaf nil)
       (leaf-init)))

    ((leaf leaf
       :package t leaf-browser
       :config (leaf-init))
     (prog1 'leaf
       (leaf-handler-package leaf leaf nil)
       (leaf-handler-package leaf leaf-browser nil)
       (leaf-init)))

    ((leaf leaf
       :package feather leaf-key leaf-browser
       :config (leaf-init))
     (prog1 'leaf
       (leaf-handler-package leaf feather nil)
       (leaf-handler-package leaf leaf-key nil)
       (leaf-handler-package leaf leaf-browser nil)
       (leaf-init)))

    ((leaf leaf
       :package (t . pin))
     (prog1 'leaf
       (leaf-handler-package leaf leaf pin)))))

(cort-deftest-with-macroexpand leaf/doc
  '(
    ;; any sexp will be ignored
    ((leaf leaf
       :doc "Symplify init.el configuration"
       :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))

    ((leaf leaf
       :file "~/.emacs.d/elpa/leaf.el/leaf.el"
       :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))

    ((leaf leaf
       :url "https://github.com/conao3/leaf.el"
       :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))

    ((leaf leaf
       :doc "Symplify init.el configuration"
       :file "~/.emacs.d/elpa/leaf.el/leaf.el"
       :url "https://github.com/conao3/leaf.el"
       :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))

    ((leaf leaf
       :doc "Symplify init.el configuration"
       "
(leaf leaf
  :doc \"Symplify init.el configuration\"
  :config (leaf-init))
 => (progn
      (leaf-init))"
       "
(leaf leaf
  :disabled nil
  :config (leaf-init))
 => (progn
      (leaf-init))"
       :file "~/.emacs.d/elpa/leaf.el/leaf.el"
       :url "https://github.com/conao3/leaf.el"
       :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))))

(cort-deftest-with-macroexpand leaf/load-path
  '(
    ;; string will be accepted
    ((leaf leaf
       :load-path "~/.emacs.d/elpa-archive/leaf.el/"
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (add-to-list 'load-path "~/.emacs.d/elpa-archive/leaf.el/")
       (require 'leaf)
       (leaf-init)))

    ;; multi strings will be accepted
    ((leaf leaf
       :load-path
       "~/.emacs.d/elpa-archive/leaf.el/"
       "~/.emacs.d/elpa-archive/leaf-browser.el/"
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (add-to-list 'load-path "~/.emacs.d/elpa-archive/leaf.el/")
       (add-to-list 'load-path "~/.emacs.d/elpa-archive/leaf-browser.el/")
       (require 'leaf)
       (leaf-init)))

    ;; multi strings in list will be accepted
    ((leaf leaf
       :load-path ("~/.emacs.d/elpa-archive/leaf.el/"
                   "~/.emacs.d/elpa-archive/leaf-browser.el/")
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (add-to-list 'load-path "~/.emacs.d/elpa-archive/leaf.el/")
       (add-to-list 'load-path "~/.emacs.d/elpa-archive/leaf-browser.el/")
       (require 'leaf)
       (leaf-init)))

    ;; nested strings is supported
    ((leaf leaf
       :load-path ("~/.emacs.d/elpa-archive/leaf.el/"
                   ("~/.emacs.d/elpa-archive/leaf.el/"
                    "~/.emacs.d/elpa-archive/leaf-browser.el/"))
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (add-to-list 'load-path "~/.emacs.d/elpa-archive/leaf.el/")
       (add-to-list 'load-path "~/.emacs.d/elpa-archive/leaf-browser.el/")
       (require 'leaf)
       (leaf-init)))

    ;; duplicated value is ignored
    ((leaf leaf
       :load-path ("~/.emacs.d/elpa-archive/leaf.el/"
                   ("~/.emacs.d/elpa-archive/leaf.el/"
                    ("~/.emacs.d/elpa-archive/leaf.el/"
                     ("~/.emacs.d/elpa-archive/leaf.el/"
                      ("~/.emacs.d/elpa-archive/leaf.el/")))))
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (add-to-list 'load-path "~/.emacs.d/elpa-archive/leaf.el/")
       (require 'leaf)
       (leaf-init)))

    ;; use backquote and comma to configure with result of sexp
    ((leaf leaf
       :load-path ("~/.emacs.d/elpa-archive/leaf.el/")
       :load-path `(,(mapcar (lambda (elm)
                               (concat "~/.emacs.d/elpa-archive/" elm "/"))
                             '("leaf.el" "leaf-broser.el" "orglyth.el")))
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (add-to-list 'load-path "~/.emacs.d/elpa-archive/leaf.el/")
       (add-to-list 'load-path "~/.emacs.d/elpa-archive/leaf-broser.el/")
       (add-to-list 'load-path "~/.emacs.d/elpa-archive/orglyth.el/")
       (require 'leaf)
       (leaf-init)))))

(cort-deftest-with-macroexpand leaf/defun
  '(
    ;; symbol will be accepted and use leaf--name
    ((leaf leaf
       :defun leaf)
     (prog1 'leaf
       (declare-function leaf "leaf")))

    ;; multi symbols will be accepted
    ((leaf leaf
       :defun leaf leaf-normalize-plist leaf-merge-dupkey-values-plist)
     (prog1 'leaf
       (declare-function leaf "leaf")
       (declare-function leaf-normalize-plist "leaf")
       (declare-function leaf-merge-dupkey-values-plist "leaf")))

    ;; multi symbols in list will be accepted
    ((leaf leaf
       :defun (leaf leaf-normalize-plist leaf-merge-dupkey-values-plist))
     (prog1 'leaf
       (declare-function leaf "leaf")
       (declare-function leaf-normalize-plist "leaf")
       (declare-function leaf-merge-dupkey-values-plist "leaf")))

    ;; cons-cell will be accepted
    ((leaf leaf
       :defun (lbrowser-open . leaf-browser))
     (prog1 'leaf
       (declare-function lbrowser-open "leaf-browser")))

    ;; distribution feature is supported
    ((leaf leaf
       :defun ((lbrowser-open lbrowser-close) . leaf-browser))
     (prog1 'leaf
       (declare-function lbrowser-open "leaf-browser")
       (declare-function lbrowser-close "leaf-browser")))))

(cort-deftest-with-macroexpand leaf/defvar
  '(
    ;; symbol will be accepted
    ((leaf leaf
       :defvar leaf-var)
     (prog1 'leaf
       (defvar leaf-var)))

    ;; multi symbols will be accepted
    ((leaf leaf
       :defvar leaf-var1 leaf-var2 leaf-var3)
     (prog1 'leaf
       (defvar leaf-var1)
       (defvar leaf-var2)
       (defvar leaf-var3)))

    ;; multi symbols in list will be accepted
    ((leaf leaf
       :defvar (leaf-var1 leaf-var2 leaf-var3))
     (prog1 'leaf
       (defvar leaf-var1)
       (defvar leaf-var2)
       (defvar leaf-var3)))

    ;; nested list will be accepted
    ;; duplicated values will be ignored
    ((leaf leaf
       :defvar (leaf-var1 (leaf-var1 leaf-var2 leaf-var3)))
     (prog1 'leaf
       (defvar leaf-var1)
       (defvar leaf-var2)
       (defvar leaf-var3)))))

(cort-deftest-with-macroexpand leaf/preface
  '(
    ;; sexp will be expanded in order of :preface, :when, :require, :init, :config. 
    ((leaf leaf
       :require t
       :preface (preface-init)
       :when (some-condition)
       :init (package-preconfig)
       :config (package-init))
     (prog1 'leaf
       (preface-init)
       (when (some-condition)
         (package-preconfig)
         (require 'leaf)
         (package-init))))

    ;; multi sexp will be accepted
    ((leaf leaf
       :preface
       (leaf-pre-init)
       (leaf-pre-init-after)
       :when (some-condition)
       :require t
       :init (package-preconfig)
       :config (package-init))
     (prog1 'leaf
       (leaf-pre-init)
       (leaf-pre-init-after)
       (when
           (some-condition)
         (package-preconfig)
         (require 'leaf)
         (package-init))))

    ;; you can use `progn' if you prefer it
    ((leaf leaf
       :preface (progn
                  (leaf-pre-init)
                  (leaf-pre-init-after))
       :when (some-condition)
       :require t
       :init (package-preconfig)
       :config (package-init))
     (prog1 'leaf
       (progn
         (leaf-pre-init)
         (leaf-pre-init-after))
       (when
           (some-condition)
         (package-preconfig)
         (require 'leaf)
         (package-init))))))

(cort-deftest-with-macroexpand leaf/if
  '(
    ;; single xexp will accepted
    ((leaf leaf
       :if leafp
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (if leafp
           (progn
             (require 'leaf)
             (leaf-init)))))

    ;; multi sexp will accepted and eval them in `and'
    ((leaf leaf
       :if leafp leaf-avairablep (window-system)
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (if (and leafp leaf-avairablep (window-system))
           (progn
             (require 'leaf)
             (leaf-init)))))

    ;; you can use other condition keywords same time
    ((leaf leaf
       :if leafp leaf-avairablep (window-system)
       :when leaf-browserp
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (when leaf-browserp
         (if (and leafp leaf-avairablep (window-system))
             (progn
               (require 'leaf)
               (leaf-init))))))

    ;; you want eval sexp before any conditions, you can use :preface
    ((leaf leaf
       :if leafp leaf-avairablep (window-system)
       :when leaf-browserp
       :load-path "~/.emacs.d/elpa-archive/leaf.el/"
       :preface (leaf-load)
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (add-to-list 'load-path "~/.emacs.d/elpa-archive/leaf.el/")
       (leaf-load)
       (when leaf-browserp
         (if (and leafp leaf-avairablep (window-system))
             (progn
               (require 'leaf)
               (leaf-init))))))))

(cort-deftest-with-macroexpand leaf/when
  '(
    ;; same as :if
    ((leaf leaf
       :when leafp
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (when leafp
         (require 'leaf)
         (leaf-init))))

    ((leaf leaf
       :when leafp leaf-avairablep (window-system)
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (when (and leafp leaf-avairablep (window-system))
         (require 'leaf)
         (leaf-init))))))

(cort-deftest-with-macroexpand leaf/unless
  '(
    ;; same as :if
    ((leaf leaf
       :unless leafp
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (unless leafp
         (require 'leaf)
         (leaf-init))))

    ((leaf leaf
       :unless leafp leaf-avairablep (window-system)
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (unless (and leafp leaf-avairablep (window-system))
         (require 'leaf)
         (leaf-init))))))

(cort-deftest-with-macroexpand leaf/after
  '(
    ;; 't will be converted leaf--name
    ((leaf leaf-browser
       :after leaf
       :require t
       :config (leaf-browser-init))
     (prog1 'leaf-browser
       (eval-after-load 'leaf
         '(progn
            (require 'leaf-browser)
            (leaf-browser-init)))))

    ;; multi symbols will be accepted
    ((leaf leaf-browser
       :after leaf org orglyth
       :require t
       :config (leaf-browser-init))
     (prog1 'leaf-browser
       (eval-after-load 'orglyth
         '(eval-after-load 'org
            '(eval-after-load 'leaf
               '(progn
                  (require 'leaf-browser)
                  (leaf-browser-init)))))))

    ;; multi symbols in list will be accepted
    ((leaf leaf-browser
       :after leaf (org orglyth)
       :require t
       :config (leaf-browser-init))
     (prog1 'leaf-browser
       (eval-after-load 'orglyth
         '(eval-after-load 'org
            '(eval-after-load 'leaf
               '(progn
                  (require 'leaf-browser)
                  (leaf-browser-init)))))))

    ;; duplicated symbol will be ignored
    ((leaf leaf-browser
       :after leaf (org orglyth) org org
       :require t
       :config (leaf-browser-init))
     (prog1 'leaf-browser
       (eval-after-load 'orglyth
         '(eval-after-load 'org
            '(eval-after-load 'leaf
               '(progn
                  (require 'leaf-browser)
                  (leaf-browser-init)))))))))

(cort-deftest-with-macroexpand leaf/custom
  '(
    ;; multi cons-cell will be accepted
    ((leaf foo-package
       :custom
       (foo-package-to-enable   . t)
       (foo-package-to-disable  . nil)
       (foo-package-to-symbol   . 'symbol)
       (foo-package-to-function . #'ignore)
       (foo-package-to-lambda   . (lambda (elm) (message elm))))
     (prog1 'foo-package
       (custom-set-variables
        '(foo-package-to-enable t "Customized with leaf in foo-package block")
        '(foo-package-to-disable nil "Customized with leaf in foo-package block")
        '(foo-package-to-symbol 'symbol "Customized with leaf in foo-package block")
        '(foo-package-to-function #'ignore "Customized with leaf in foo-package block")
        '(foo-package-to-lambda (lambda (elm) (message elm)) "Customized with leaf in foo-package block"))))

    ;; multi cons-cell in list will be accepted
    ((leaf foo-package
       :custom ((foo-package-to-enable   . t)
                (foo-package-to-disable  . nil)
                (foo-package-to-symbol   . 'symbol)
                (foo-package-to-function . #'ignore)
                (foo-package-to-lambda   . (lambda (elm) (message elm)))))
     (prog1 'foo-package
       (custom-set-variables
        '(foo-package-to-enable t "Customized with leaf in foo-package block")
        '(foo-package-to-disable nil "Customized with leaf in foo-package block")
        '(foo-package-to-symbol 'symbol "Customized with leaf in foo-package block")
        '(foo-package-to-function #'ignore "Customized with leaf in foo-package block")
        '(foo-package-to-lambda (lambda (elm) (message elm)) "Customized with leaf in foo-package block"))))

    ;; distribution feature is supported
    ((leaf foo-package
       :custom (((to-enable1 to-enable2 to-enable3) . t)
                ((to-disable1 to-disable2 to-disable3) . nil)))
     (prog1 'foo-package
       (custom-set-variables
        '(to-enable1 t "Customized with leaf in foo-package block")
        '(to-enable2 t "Customized with leaf in foo-package block")
        '(to-enable3 t "Customized with leaf in foo-package block")
        '(to-disable1 nil "Customized with leaf in foo-package block")
        '(to-disable2 nil "Customized with leaf in foo-package block")
        '(to-disable3 nil "Customized with leaf in foo-package block"))))

    ;; and mix specification is accepted
    ((leaf foo-package
       :custom
       (foo-package-to-function . #'ignore)
       ((to-symbol1 to-symbol2) . 'baz)
       (((to-enable1 to-enable2 to-enable3) . t)
        ((to-disable1 to-disable2 to-disable3) . nil)))
     (prog1 'foo-package
       (custom-set-variables
        '(foo-package-to-function #'ignore "Customized with leaf in foo-package block")
        '(to-symbol1 'baz "Customized with leaf in foo-package block")
        '(to-symbol2 'baz "Customized with leaf in foo-package block")
        '(to-enable1 t "Customized with leaf in foo-package block")
        '(to-enable2 t "Customized with leaf in foo-package block")
        '(to-enable3 t "Customized with leaf in foo-package block")
        '(to-disable1 nil "Customized with leaf in foo-package block")
        '(to-disable2 nil "Customized with leaf in foo-package block")
        '(to-disable3 nil "Customized with leaf in foo-package block"))))))

(cort-deftest-with-macroexpand leaf/custom-face
  '(
    ;; cons-cell will be accepted
    ((leaf eruby-mode
       :custom-face
       (eruby-standard-face . '((t (:slant italic)))))
     (prog1 'eruby-mode
       (custom-set-faces
        '(eruby-standard-face ((t (:slant italic)))))))

    ;; distribution feature is supported
    ((leaf eruby-mode
       :custom-face
       ((default eruby-standard-face) . '((t (:slant italic)))))
     (prog1 'eruby-mode
       (custom-set-faces
        '(default ((t (:slant italic))))
        '(eruby-standard-face ((t (:slant italic)))))))))

(cort-deftest-with-macroexpand leaf/pl-custom
  '(
    ;; Emulate customizing `sql-connection-alist' with value taken from `some-plstore'.
    ((leaf sql
       :pl-custom
       (sql-connection-alist . some-plstore))
     (prog1 'sql
       (custom-set-variables
        '(sql-connection-alist (plist-get
                                (cdr
                                 (plstore-get some-plstore "leaf-sql"))
                                :sql-connection-alist)
                               "Customized in leaf `sql' from plstore `some-plstore'"))))

    ;; Emulate customizing `erc-password' and `erc-nickserv-passwords'
    ;; with values taken from `some-plstore', and `erc-user-full-name'
    ;; and `erc-nick' with values taken from `another-plstore'.
    ((leaf erc
       :pl-custom
       ((erc-password erc-nickserv-passwords) . some-plstore)
       ((erc-user-full-name erc-nick) . another-plstore))
     (prog1 'erc
       (custom-set-variables
        '(erc-password           (plist-get
                                  (cdr
                                   (plstore-get some-plstore "leaf-erc"))
                                  :erc-password)
                                 "Customized in leaf `erc' from plstore `some-plstore'")
        '(erc-nickserv-passwords (plist-get
                                  (cdr
                                   (plstore-get some-plstore "leaf-erc"))
                                  :erc-nickserv-passwords)
                                 "Customized in leaf `erc' from plstore `some-plstore'")
        '(erc-user-full-name     (plist-get
                                  (cdr
                                   (plstore-get another-plstore "leaf-erc"))
                                  :erc-user-full-name)
                                 "Customized in leaf `erc' from plstore `another-plstore'")
        '(erc-nick               (plist-get
                                  (cdr
                                   (plstore-get another-plstore "leaf-erc"))
                                  :erc-nick)
                                 "Customized in leaf `erc' from plstore `another-plstore'"))))

    ;; you can use symbol to configure with `leaf-default-plstore'.
    ((leaf erc
       :pl-custom erc-nick erc-password)
     (prog1 'erc
       (custom-set-variables
        '(erc-nick     (plist-get
                        (cdr
                         (plstore-get leaf-default-plstore "leaf-erc"))
                        :erc-nick)
                       "Customized in leaf `erc' from plstore `leaf-default-plstore'")
        '(erc-password (plist-get
                        (cdr
                         (plstore-get leaf-default-plstore "leaf-erc"))
                        :erc-password)
                       "Customized in leaf `erc' from plstore `leaf-default-plstore'"))))))

(cort-deftest-with-macroexpand leaf/bind
  '(
    ;; cons-cell will be accepted
    ((leaf macrostep
       :ensure t
       :bind ("C-c e" . macrostep-expand))
     (prog1 'macrostep
       (autoload #'macrostep-expand "macrostep" nil t)
       (leaf-handler-package macrostep macrostep nil)
       (leaf-keys (("C-c e" . macrostep-expand)))))

    ;; multi cons-cell will be accepted
    ((leaf color-moccur
       :bind
       ("M-s O" . moccur)
       ("M-o" . isearch-moccur)
       ("M-O" . isearch-moccur-all))
     (prog1 'color-moccur
       (autoload #'moccur "color-moccur" nil t)
       (autoload #'isearch-moccur "color-moccur" nil t)
       (autoload #'isearch-moccur-all "color-moccur" nil t)
       (leaf-keys (("M-s O" . moccur)
                   ("M-o" . isearch-moccur)
                   ("M-O" . isearch-moccur-all)))))

    ;; multi cons-cell in list will be accepted
    ((leaf color-moccur
       :bind (("M-s O" . moccur)
              ("M-o" . isearch-moccur)
              ("M-O" . isearch-moccur-all)))
     (prog1 'color-moccur
       (autoload #'moccur "color-moccur" nil t)
       (autoload #'isearch-moccur "color-moccur" nil t)
       (autoload #'isearch-moccur-all "color-moccur" nil t)
       (leaf-keys (("M-s O" . moccur)
                   ("M-o" . isearch-moccur)
                   ("M-O" . isearch-moccur-all)))))

    ;; bind to nil to unbind shortcut
    ((leaf color-moccur
       :bind (("M-s" . nil)
              ("M-s o" . isearch-moccur)
              ("M-s i" . isearch-moccur-all)))
     (prog1 'color-moccur
       (autoload #'isearch-moccur "color-moccur" nil t)
       (autoload #'isearch-moccur-all "color-moccur" nil t)
       (leaf-keys (("M-s")
                   ("M-s o" . isearch-moccur)
                   ("M-s i" . isearch-moccur-all)))))

    ;; nested cons-cell list will be accepted
    ((leaf color-moccur
       :bind (("M-s O" . moccur)
              (("M-o" . isearch-moccur)
               (("M-O" . isearch-moccur-all))
               ("M-s" . isearch-moccur-some))))
     (prog1 'color-moccur
       (autoload #'moccur "color-moccur" nil t)
       (autoload #'isearch-moccur "color-moccur" nil t)
       (autoload #'isearch-moccur-all "color-moccur" nil t)
       (autoload #'isearch-moccur-some "color-moccur" nil t)
       (leaf-keys (("M-s O" . moccur)
                   ("M-o" . isearch-moccur)
                   ("M-O" . isearch-moccur-all)
                   ("M-s" . isearch-moccur-some)))))

    ;; use keyword at first element to bind specific map
    ((leaf color-moccur
       :bind (("M-s O" . moccur)
              (:isearch-mode-map
               ("M-o" . isearch-moccur)
               ("M-O" . isearch-moccur-all))))
     (prog1 'color-moccur
       (autoload #'moccur "color-moccur" nil t)
       (autoload #'isearch-moccur "color-moccur" nil t)
       (autoload #'isearch-moccur-all "color-moccur" nil t)
       (leaf-keys (("M-s O" . moccur)
                   (:isearch-mode-map
                    :package color-moccur
                    ("M-o" . isearch-moccur)
                    ("M-O" . isearch-moccur-all))))))

    ;; specific map at top-level will be accepted
    ((leaf color-moccur
       :bind
       ("M-s O" . moccur)
       (:isearch-mode-map
        ("M-o" . isearch-moccur)
        ("M-O" . isearch-moccur-all)))
     (prog1 'color-moccur
       (autoload #'moccur "color-moccur" nil t)
       (autoload #'isearch-moccur "color-moccur" nil t)
       (autoload #'isearch-moccur-all "color-moccur" nil t)
       (leaf-keys (("M-s O" . moccur)
                   (:isearch-mode-map
                    :package color-moccur
                    ("M-o" . isearch-moccur)
                    ("M-O" . isearch-moccur-all))))))

    ;; use :package to deffering :iserch-mode-map declared
    ((leaf color-moccur
       :bind (("M-s O" . moccur)
              (:isearch-mode-map
               :package isearch
               ("M-o" . isearch-moccur)
               ("M-O" . isearch-moccur-all))))
     (prog1 'color-moccur
       (autoload #'moccur "color-moccur" nil t)
       (autoload #'isearch-moccur "color-moccur" nil t)
       (autoload #'isearch-moccur-all "color-moccur" nil t)
       (leaf-keys (("M-s O" . moccur)
                   (:isearch-mode-map
                    :package isearch
                    ("M-o" . isearch-moccur)
                    ("M-O" . isearch-moccur-all))))))

    ;; you can use symbol instead of keyword to specify map
    ((leaf color-moccur
       :bind (("M-s O" . moccur)
              (isearch-mode-map
               :package isearch
               ("M-o" . isearch-moccur)
               ("M-O" . isearch-moccur-all))))
     (prog1 'color-moccur
       (autoload #'moccur "color-moccur" nil t)
       (autoload #'isearch-moccur "color-moccur" nil t)
       (autoload #'isearch-moccur-all "color-moccur" nil t)
       (leaf-keys (("M-s O" . moccur)
                   (isearch-mode-map
                    :package isearch
                    ("M-o" . isearch-moccur)
                    ("M-O" . isearch-moccur-all))))))))

(cort-deftest-with-macroexpand leaf/bind*
  '(
    ;; bind* to bind override any key-bind map
    ((leaf color-moccur
       :bind*
       ("M-s O" . moccur)
       ("M-o" . isearch-moccur)
       ("M-O" . isearch-moccur-all))
     (prog1 'color-moccur
       (autoload #'moccur "color-moccur" nil t)
       (autoload #'isearch-moccur "color-moccur" nil t)
       (autoload #'isearch-moccur-all "color-moccur" nil t)
       (leaf-keys* (("M-s O" . moccur)
                    ("M-o" . isearch-moccur)
                    ("M-O" . isearch-moccur-all)))))

    ((leaf color-moccur
       :bind* (("M-s O" . moccur)
               ("M-o" . isearch-moccur)
               ("M-O" . isearch-moccur-all)))
     (prog1 'color-moccur
       (autoload #'moccur "color-moccur" nil t)
       (autoload #'isearch-moccur "color-moccur" nil t)
       (autoload #'isearch-moccur-all "color-moccur" nil t)
       (leaf-keys* (("M-s O" . moccur)
                    ("M-o" . isearch-moccur)
                    ("M-O" . isearch-moccur-all)))))

    ((leaf color-moccur
       :bind* (("M-s O" . moccur)
               (("M-o" . isearch-moccur)
                (("M-O" . isearch-moccur-all)))))
     (prog1 'color-moccur
       (autoload #'moccur "color-moccur" nil t)
       (autoload #'isearch-moccur "color-moccur" nil t)
       (autoload #'isearch-moccur-all "color-moccur" nil t)
       (leaf-keys* (("M-s O" . moccur)
                    ("M-o" . isearch-moccur)
                    ("M-O" . isearch-moccur-all)))))

    ((leaf color-moccur
       :bind* (("M-s O" . moccur)
               (("M-o" . isearch-moccur)
                (("M-O" . isearch-moccur-all))
                ("M-s" . isearch-moccur-some))))
     (prog1 'color-moccur
       (autoload #'moccur "color-moccur" nil t)
       (autoload #'isearch-moccur "color-moccur" nil t)
       (autoload #'isearch-moccur-all "color-moccur" nil t)
       (autoload #'isearch-moccur-some "color-moccur" nil t)
       (leaf-keys* (("M-s O" . moccur)
                    ("M-o" . isearch-moccur)
                    ("M-O" . isearch-moccur-all)
                    ("M-s" . isearch-moccur-some)))))))

(cort-deftest-with-macroexpand leaf/mode
  '(
    ;; string will be accepted and use leaf--name
    ((leaf web-mode
       :mode "\\.js\\'")
     (prog1 'web-mode
       (autoload #'web-mode "web-mode" nil t)
       (add-to-list 'auto-mode-alist '("\\.js\\'" . web-mode))))

    ;; multi strings will be accepted
    ((leaf web-mode
       :mode "\\.js\\'" "\\.p?html?\\'")
     (prog1 'web-mode
       (autoload #'web-mode "web-mode" nil t)
       (add-to-list 'auto-mode-alist '("\\.js\\'" . web-mode))
       (add-to-list 'auto-mode-alist '("\\.p?html?\\'" . web-mode))))

    ;; multi strings in list will be accepted
    ((leaf web-mode
       :mode ("\\.js\\'" "\\.p?html?\\'"))
     (prog1 'web-mode
       (autoload #'web-mode "web-mode" nil t)
       (add-to-list 'auto-mode-alist '("\\.js\\'" . web-mode))
       (add-to-list 'auto-mode-alist '("\\.p?html?\\'" . web-mode))))

    ;; cons-cell will be accepted
    ((leaf web-mode
       :mode ("\\.js\\'" . web-strict-mode))
     (prog1 'web-mode
       (autoload #'web-strict-mode "web-mode" nil t)
       (add-to-list 'auto-mode-alist '("\\.js\\'" . web-strict-mode))))

    ;; distribution feature is supported
    ((leaf web-mode
       :mode (("\\.js\\'" "\\.p?html?\\'") . web-strict-mode))
     (prog1 'web-mode
       (autoload #'web-strict-mode "web-mode" nil t)
       (add-to-list 'auto-mode-alist '("\\.js\\'" . web-strict-mode))
       (add-to-list 'auto-mode-alist '("\\.p?html?\\'" . web-strict-mode))))

    ;; mix specification will be accepted
    ((leaf web-mode
       :mode ("\\.html\\'"
              (("\\.js\\'" "\\.p?html?\\'") . web-strict-mode)))
     (prog1 'web-mode
       (autoload #'web-mode "web-mode" nil t)
       (autoload #'web-strict-mode "web-mode" nil t)
       (add-to-list 'auto-mode-alist '("\\.html\\'" . web-mode))
       (add-to-list 'auto-mode-alist '("\\.js\\'" . web-strict-mode))
       (add-to-list 'auto-mode-alist '("\\.p?html?\\'" . web-strict-mode))))))

(cort-deftest-with-macroexpand leaf/interpreter
  '(
    ;; same as :mode
    ((leaf ruby-mode
       :mode "\\.rb\\'" "\\.rb2\\'" ("\\.rbg\\'" . rb-mode)
       :interpreter "ruby")
     (prog1 'ruby-mode
       (autoload #'ruby-mode "ruby-mode" nil t)
       (autoload #'rb-mode "ruby-mode" nil t)
       (add-to-list 'auto-mode-alist '("\\.rb\\'" . ruby-mode))
       (add-to-list 'auto-mode-alist '("\\.rb2\\'" . ruby-mode))
       (add-to-list 'auto-mode-alist '("\\.rbg\\'" . rb-mode))
       (add-to-list 'interpreter-mode-alist '("ruby" . ruby-mode))))

    ((leaf web-mode
       :interpreter "js" "p?html?")
     (prog1 'web-mode
       (autoload #'web-mode "web-mode" nil t)
       (add-to-list 'interpreter-mode-alist '("js" . web-mode))
       (add-to-list 'interpreter-mode-alist '("p?html?" . web-mode))))

    ((leaf web-mode
       :interpreter ("js" "p?html?"))
     (prog1 'web-mode
       (autoload #'web-mode "web-mode" nil t)
       (add-to-list 'interpreter-mode-alist '("js" . web-mode))
       (add-to-list 'interpreter-mode-alist '("p?html?" . web-mode))))

    ((leaf web-mode
       :interpreter (("js" "p?html?") . web-mode))
     (prog1 'web-mode
       (autoload #'web-mode "web-mode" nil t)
       (add-to-list 'interpreter-mode-alist '("js" . web-mode))
       (add-to-list 'interpreter-mode-alist '("p?html?" . web-mode))))))

(cort-deftest-with-macroexpand leaf/magic
  '(
    ;; same as :mode
    ((leaf pdf-tools
       :magic ("%PDF" . pdf-view-mode)
       :config
       (pdf-tools-install))
     (prog1 'pdf-tools
       (autoload #'pdf-view-mode "pdf-tools" nil t)
       (add-to-list 'magic-mode-alist '("%PDF" . pdf-view-mode))
       (eval-after-load 'pdf-tools
         '(progn
            (pdf-tools-install)))))

    ((leaf web-mode
       :magic "js" "p?html?")
     (prog1 'web-mode
       (autoload #'web-mode "web-mode" nil t)
       (add-to-list 'magic-mode-alist '("js" . web-mode))
       (add-to-list 'magic-mode-alist '("p?html?" . web-mode))))

    ((leaf web-mode
       :magic ("js" "p?html?"))
     (prog1 'web-mode
       (autoload #'web-mode "web-mode" nil t)
       (add-to-list 'magic-mode-alist '("js" . web-mode))
       (add-to-list 'magic-mode-alist '("p?html?" . web-mode))))

    ((leaf web-mode
       :magic (("js" "p?html?") . web-mode))
     (prog1 'web-mode
       (autoload #'web-mode "web-mode" nil t)
       (add-to-list 'magic-mode-alist '("js" . web-mode))
       (add-to-list 'magic-mode-alist '("p?html?" . web-mode))))))

(cort-deftest-with-macroexpand leaf/magic-fallback
  '(
    ;; same as :mode
    ((leaf pdf-tools
       :magic-fallback ("%PDF" . pdf-view-mode)
       :config
       (pdf-tools-install))
     (prog1 'pdf-tools
       (autoload #'pdf-view-mode "pdf-tools" nil t)
       (add-to-list 'magic-fallback-mode-alist '("%PDF" . pdf-view-mode))
       (eval-after-load 'pdf-tools
         '(progn
            (pdf-tools-install)))))

    ((leaf web-mode
       :magic-fallback "js" "p?html?")
     (prog1 'web-mode
       (autoload #'web-mode "web-mode" nil t)
       (add-to-list 'magic-fallback-mode-alist '("js" . web-mode))
       (add-to-list 'magic-fallback-mode-alist '("p?html?" . web-mode))))

    ((leaf web-mode
       :magic-fallback ("js" "p?html?"))
     (prog1 'web-mode
       (autoload #'web-mode "web-mode" nil t)
       (add-to-list 'magic-fallback-mode-alist '("js" . web-mode))
       (add-to-list 'magic-fallback-mode-alist '("p?html?" . web-mode))))

    ((leaf web-mode
       :magic-fallback (("js" "p?html?") . web-mode))
     (prog1 'web-mode
       (autoload #'web-mode "web-mode" nil t)
       (add-to-list 'magic-fallback-mode-alist '("js" . web-mode))
       (add-to-list 'magic-fallback-mode-alist '("p?html?" . web-mode))))))

(cort-deftest-with-macroexpand leaf/hook
  '(
    ;; symbol will be accepted
    ((leaf ace-jump-mode
       :hook cc-mode-hook
       :config (ace-jump-mode))
     (prog1 'ace-jump-mode
       (autoload #'ace-jump-mode "ace-jump-mode" nil t)
       (add-hook 'cc-mode-hook #'ace-jump-mode)
       (eval-after-load 'ace-jump-mode
         '(progn
            (ace-jump-mode)))))

    ;; multi symbols will be accepted
    ((leaf ace-jump-mode
       :hook cc-mode-hook prog-mode-hook)
     (prog1 'ace-jump-mode
       (autoload #'ace-jump-mode "ace-jump-mode" nil t)
       (add-hook 'cc-mode-hook #'ace-jump-mode)
       (add-hook 'prog-mode-hook #'ace-jump-mode)))

    ;; cons-cell will be accepted
    ((leaf ace-jump-mode
       :hook (prog-mode-hook . my-ace-jump-mode))
     (prog1 'ace-jump-mode
       (autoload #'my-ace-jump-mode "ace-jump-mode" nil t)
       (add-hook 'prog-mode-hook #'my-ace-jump-mode)))

    ;; distribution feature is supported
    ((leaf ace-jump-mode
       :hook ((cc-mode-hook prog-mode-hook) . my-ace-jump-mode))
     (prog1 'ace-jump-mode
       (autoload #'my-ace-jump-mode "ace-jump-mode" nil t)
       (add-hook 'cc-mode-hook #'my-ace-jump-mode)
       (add-hook 'prog-mode-hook #'my-ace-jump-mode)))

    ;; lambda sexp is supported
    ((leaf hook
       :hook (foo-hook . (lambda () (foo))))
     (prog1 'hook
       (add-hook 'foo-hook #'(lambda nil (foo)))))

    ;; lambda sexp with many sexps
    ((leaf hook
       :hook (foo-hook . (lambda () (foo) (bar) (baz))))
     (prog1 'hook
       (add-hook 'foo-hook #'(lambda nil (foo) (bar) (baz)))))))

(cort-deftest-with-macroexpand leaf/advice
  '(
    ;; define advice function(s) in :preface
    ;; list like ({{place}} {{adviced-function}} {{advice-function}}) will be accepted
    ((leaf leaf
       :preface
       (defun matu (x)
         (princ (format ">>%s<<" x))
         nil)
       (defun matu-around0 (f &rest args)
         (prog2
             (princ "around0 ==>")
             (apply f args)
           (princ "around0 <==")))
       (defun matu-before0 (&rest args)
         (princ "before0:"))
       :advice
       (:around matu matu-around0)
       (:before matu matu-before0))
     (prog1 'leaf
       (autoload #'matu-around0 "leaf" nil t)
       (autoload #'matu-before0 "leaf" nil t)
       (defun matu (x)
         (princ
          (format ">>%s<<" x))
         nil)
       (defun matu-around0
           (f &rest args)
         (prog2
             (princ "around0 ==>")
             (apply f args)
           (princ "around0 <==")))
       (defun matu-before0
           (&rest args)
         (princ "before0:"))
       (advice-add 'matu :around #'matu-around0)
       (advice-add 'matu :before #'matu-before0)))

    ;; multi lists like ({{place}} {{adviced-function}} {{advice-function}}) in list is accepted
    ((leaf leaf
       :preface
       (defun matu (x)
         (princ (format ">>%s<<" x))
         nil)
       (defun matu-around0 (f &rest args)
         (prog2
             (princ "around0 ==>")
             (apply f args)
           (princ "around0 <==")))
       (defun matu-before0 (&rest args)
         (princ "before0:"))
       :advice ((:around matu matu-around0)
                (:before matu matu-before0)))
     (prog1 'leaf
       (autoload #'matu-around0 "leaf" nil t)
       (autoload #'matu-before0 "leaf" nil t)
       (defun matu (x)
         (princ
          (format ">>%s<<" x))
         nil)
       (defun matu-around0
           (f &rest args)
         (prog2
             (princ "around0 ==>")
             (apply f args)
           (princ "around0 <==")))
       (defun matu-before0
           (&rest args)
         (princ "before0:"))
       (advice-add 'matu :around #'matu-around0)
       (advice-add 'matu :before #'matu-before0)))

    ;; you can use `lambda' in {{function}} place
    ((leaf leaf
       :preface
       (defun matu (x)
         (princ (format ">>%s<<" x))
         nil)
       (defun matu-around0 (f &rest args)
         (prog2
             (princ "around0 ==>")
             (apply f args)
           (princ "around0 <==")))
       (defun matu-before0 (&rest args)
         (princ "before0:"))
       :advice ((:around matu matu-around0)
                (:before matu matu-before0)
                (:around matu (lambda (f &rest args)
                                (prog2
                                    (princ "around1 ==>")
                                    (apply f args)
                                  (princ "around1 <=="))))))
     (prog1 'leaf
       (autoload #'matu-around0 "leaf" nil t)
       (autoload #'matu-before0 "leaf" nil t)
       (defun matu
           (x)
         (princ
          (format ">>%s<<" x))
         nil)
       (defun matu-around0
           (f &rest args)
         (prog2
             (princ "around0 ==>")
             (apply f args)
           (princ "around0 <==")))
       (defun matu-before0
           (&rest args)
         (princ "before0:"))
       (advice-add 'matu :around #'matu-around0)
       (advice-add 'matu :before #'matu-before0)
       (advice-add 'matu :around (function
                                  (lambda
                                    (f &rest args)
                                    (prog2
                                        (princ "around1 ==>")
                                        (apply f args)
                                      (princ "around1 <==")))))))))

(cort-deftest-with-macroexpand leaf/advice-remove
  '(
    ;; list like ({{adviced-function}} {{advice-function}}) will be accepted
    ((leaf leaf
       :advice-remove
       (matu matu-around0)
       (matu matu-before0))
     (prog1 'leaf
       (autoload #'matu-before0 "leaf" nil t)
       (autoload #'matu-around0 "leaf" nil t)
       (advice-remove 'matu #'matu-around0)
       (advice-remove 'matu #'matu-before0)))

    ;; multi lists like ({{adviced-function}} {{advice-function}}) in list will be accepted
    ((leaf leaf
       :advice-remove ((matu matu-around0)
                       (matu matu-before0)))
     (prog1 'leaf
       (autoload #'matu-before0 "leaf" nil t)
       (autoload #'matu-around0 "leaf" nil t)
       (advice-remove 'matu #'matu-around0)
       (advice-remove 'matu #'matu-before0)))))

(cort-deftest-with-macroexpand leaf/commands
  '(
    ;; specify a symbol to set to autoload function
    ((leaf leaf
       :commands leaf
       :config (leaf-init))
     (prog1 'leaf
       (autoload #'leaf "leaf" nil t)
       (eval-after-load 'leaf
         '(progn
            (leaf-init)))))

    ;; multi symbols will be accepted
    ((leaf leaf
       :commands leaf leaf-pairp leaf-plist-get)
     (prog1 'leaf
       (autoload #'leaf "leaf" nil t)
       (autoload #'leaf-pairp "leaf" nil t)
       (autoload #'leaf-plist-get "leaf" nil t)))

    ;; multi symbols in list will be accepted
    ((leaf leaf
       :commands (leaf leaf-pairp leaf-plist-get))
     (prog1 'leaf
       (autoload #'leaf "leaf" nil t)
       (autoload #'leaf-pairp "leaf" nil t)
       (autoload #'leaf-plist-get "leaf" nil t)))

    ;; It is accepted even if you specify symbol and list at the same time
    ((leaf leaf
       :commands leaf (leaf-pairp leaf-plist-get (leaf-insert-list-after)))
     (prog1 'leaf
       (autoload #'leaf "leaf" nil t)
       (autoload #'leaf-pairp "leaf" nil t)
       (autoload #'leaf-plist-get "leaf" nil t)
       (autoload #'leaf-insert-list-after "leaf" nil t)))))

(cort-deftest-with-macroexpand leaf/pre-setq
  '(
    ;; :pre-setq setq before `require'
    ((leaf alloc
       :pre-setq `((gc-cons-threshold . ,(* 512 1024 1024))
                   (garbage-collection-messages . t))
       :require t)
     (prog1 'alloc
       (setq gc-cons-threshold 536870912)
       (setq garbage-collection-messages t)
       (require 'alloc)))

    ((leaf alloc
       :pre-setq ((gc-cons-threshold . 536870912)
                  (garbage-collection-messages . t))
       :require t)
     (prog1 'alloc
       (setq gc-cons-threshold 536870912)
       (setq garbage-collection-messages t)
       (require 'alloc)))

    ((leaf leaf
       :pre-setq
       (leaf-backend-bind . 'bind-key)
       (leaf-backend-bind* . 'bind-key)
       :require t)
     (prog1 'leaf
       (setq leaf-backend-bind 'bind-key)
       (setq leaf-backend-bind* 'bind-key)
       (require 'leaf)))

    ((leaf leaf
       :pre-setq ((leaf-backend-bind leaf-backend-bind*) . 'bind-key)
       :require t)
     (prog1 'leaf
       (setq leaf-backend-bind 'bind-key)
       (setq leaf-backend-bind* 'bind-key)
       (require 'leaf)))

    ((leaf lsp-mode
       :pre-setq ((lsp-print-io lsp-trace lsp-print-performance) . nil)
       :require t)
     (prog1 'lsp-mode
       (setq lsp-print-io nil)
       (setq lsp-trace nil)
       (setq lsp-print-performance nil)
       (require 'lsp-mode)))

    ((leaf lsp-mode
       :pre-setq ((lsp-use-native-json . t)
                  ((lsp-enable-folding lsp-enable-snippet) . t)
                  ((lsp-print-io lsp-trace lsp-print-performance) . nil))
       :require t)
     (prog1 'lsp-mode
       (setq lsp-use-native-json t)
       (setq lsp-enable-folding t)
       (setq lsp-enable-snippet t)
       (setq lsp-print-io nil)
       (setq lsp-trace nil)
       (setq lsp-print-performance nil)
       (require 'lsp-mode)))))

(cort-deftest-with-macroexpand leaf/init
  '(((leaf leaf
       :init (leaf-pre-init)
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (leaf-pre-init)
       (require 'leaf)
       (leaf-init)))

    ((leaf leaf
       :init (progn
               (leaf-pre-init)
               (leaf-pre-init-after))
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (progn
         (leaf-pre-init)
         (leaf-pre-init-after))
       (require 'leaf)
       (leaf-init)))

    ((leaf leaf
       :init
       (leaf-pre-init)
       (leaf-pre-init-after)
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (leaf-pre-init)
       (leaf-pre-init-after)
       (require 'leaf)
       (leaf-init)))))

(cort-deftest-with-macroexpand leaf/require
  '(
    ;; 't will be converted leaf--name 
    ((leaf leaf
       :init (leaf-pre-init)
       :when leaf-workable-p
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (when leaf-workable-p
         (leaf-pre-init)
         (require 'leaf)
         (leaf-init))))

    ;; 'nil will be just ignored it
    ((leaf leaf
       :init (leaf-pre-init)
       :require nil
       :config (leaf-init))
     (prog1 'leaf
       (leaf-pre-init)
       (leaf-init)))

    ;; multi symbols will be accepted
    ((leaf leaf
       :init (leaf-pre-init)
       :require leaf leaf-polyfill
       :config (leaf-init))
     (prog1 'leaf
       (leaf-pre-init)
       (require 'leaf)
       (require 'leaf-polyfill)
       (leaf-init)))

    ;; multi keywords will be accepted
    ((leaf leaf
       :init (leaf-pre-init)
       :require t
       :require leaf-polyfill
       :config (leaf-init))
     (prog1 'leaf
       (leaf-pre-init)
       (require 'leaf)
       (require 'leaf-polyfill)
       (leaf-init)))

    ;; multi symbols in list will be accepted
    ((leaf leaf
       :init (leaf-pre-init)
       :require (leaf leaf-polyfill leaf-sub leaf-subsub)
       :config (leaf-init))
     (prog1 'leaf
       (leaf-pre-init)
       (require 'leaf)
       (require 'leaf-polyfill)
       (require 'leaf-sub)
       (require 'leaf-subsub)
       (leaf-init)))))

(cort-deftest-with-macroexpand leaf/setq
  '(
    ;; cons-cell will be accepted
    ((leaf alloc
       :setq (gc-cons-threshold . 536870912)
       :require t)
     (prog1 'alloc
       (require 'alloc)
       (setq gc-cons-threshold 536870912)))

    ;; multi cons-cell will be accepted
    ((leaf alloc
       :setq
       (gc-cons-threshold . 536870912)
       (garbage-collection-messages . t)
       :require t)
     (prog1 'alloc
       (require 'alloc)
       (setq gc-cons-threshold 536870912)
       (setq garbage-collection-messages t)))

    ;; multi cons-cell in list will be accepted
    ((leaf alloc
       :setq ((gc-cons-threshold . 536870912)
              (garbage-collection-messages . t))
       :require t)
     (prog1 'alloc
       (require 'alloc)
       (setq gc-cons-threshold 536870912)
       (setq garbage-collection-messages t)))

    ;; use backquote and comma to set result of sexp
    ((leaf alloc
       :setq `((gc-cons-threshold . ,(* 512 1024 1024))
               (garbage-collection-messages . t))
       :require t)
     (prog1 'alloc
       (require 'alloc)
       (setq gc-cons-threshold 536870912)
       (setq garbage-collection-messages t)))

    ;; distribution feature is supported
    ((leaf leaf
       :setq ((leaf-backend-bind leaf-backend-bind*) . 'bind-key)
       :require t)
     (prog1 'leaf
       (require 'leaf)
       (setq leaf-backend-bind 'bind-key)
       (setq leaf-backend-bind* 'bind-key)))))

(cort-deftest-with-macroexpand leaf/pl-setq
  '(
    ;; Emulate setting `sql-connection-alist' with value taken from `some-plstore'.
    ((leaf sql
       :pl-setq
       (sql-connection-alist . some-plstore))
     (prog1 'sql
       (setq sql-connection-alist (plist-get
                                   (cdr
                                    (plstore-get some-plstore "leaf-sql"))
                                   :sql-connection-alist))))
    ;; Emulate setting `erc-password' and `erc-nickserv-passwords'
    ;; with values taken from `some-plstore', and `erc-user-full-name'
    ;; and `erc-nick' with values taken from `another-plstore'.
    ((leaf erc
       :pl-setq
       ((erc-password erc-nickserv-passwords) . some-plstore)
       ((erc-user-full-name erc-nick) . another-plstore))
     (prog1 'erc
       (setq erc-password           (plist-get
                                     (cdr
                                      (plstore-get some-plstore "leaf-erc"))
                                     :erc-password))
       (setq erc-nickserv-passwords (plist-get
                                     (cdr
                                      (plstore-get some-plstore "leaf-erc"))
                                     :erc-nickserv-passwords))
       (setq erc-user-full-name     (plist-get
                                     (cdr
                                      (plstore-get another-plstore "leaf-erc"))
                                     :erc-user-full-name))
       (setq erc-nick               (plist-get
                                     (cdr
                                      (plstore-get another-plstore "leaf-erc"))
                                     :erc-nick))))))

(cort-deftest-with-macroexpand leaf/setq-default
  '(
    ;; :setq-default to `setq-default'
    ((leaf alloc
       :setq-default `((gc-cons-threshold . ,(* 512 1024 1024))
                       (garbage-collection-messages . t))
       :require t)
     (prog1 'alloc
       (require 'alloc)
       (setq-default gc-cons-threshold 536870912)
       (setq-default garbage-collection-messages t)))

    ((leaf alloc
       :setq-default ((gc-cons-threshold . 536870912)
                      (garbage-collection-messages . t))
       :require t)
     (prog1 'alloc
       (require 'alloc)
       (setq-default gc-cons-threshold 536870912)
       (setq-default garbage-collection-messages t)))

    ((leaf leaf
       :setq-default
       (leaf-backend-bind . 'bind-key)
       (leaf-backend-bind* . 'bind-key)
       :require t)
     (prog1 'leaf
       (require 'leaf)
       (setq-default leaf-backend-bind 'bind-key)
       (setq-default leaf-backend-bind* 'bind-key)))

    ((leaf leaf
       :setq-default ((leaf-backend-bind leaf-backend-bind*) . 'bind-key)
       :require t)
     (prog1 'leaf
       (require 'leaf)
       (setq-default leaf-backend-bind 'bind-key)
       (setq-default leaf-backend-bind* 'bind-key)))))

(cort-deftest-with-macroexpand leaf/pl-setq-default
  ;; Emulate setting `indent-tabs-mode' with a default value taken
  ;; from `some-plstore'.
  '(((leaf indent
       :pl-setq-default
       (indent-tabs-mode . some-plstore))
     (prog1 'indent
       (setq-default indent-tabs-mode
                     (plist-get
                      (cdr
                       (plstore-get some-plstore "leaf-indent"))
                      :indent-tabs-mode))))))

(cort-deftest-with-macroexpand leaf/pl-pre-setq
  ;; Emulate setting `indent-tabs-mode' with a default value taken
  ;; from `some-plstore'.
  '(((leaf indent
       :pl-pre-setq (indent-tabs-mode . some-plstore)
       :require t)
     (prog1 'indent
       (setq indent-tabs-mode
             (plist-get
              (cdr
               (plstore-get some-plstore "leaf-indent"))
              :indent-tabs-mode))
       (require 'indent)))))

(cort-deftest-with-macroexpand leaf/config
  '(((leaf leaf
       :init (leaf-pre-init)
       :require t
       :config (leaf-init))
     (prog1 'leaf
       (leaf-pre-init)
       (require 'leaf)
       (leaf-init)))

    ((leaf leaf
       :init (leaf-init)
       :require t
       :config (progn
                 (leaf-pre-init)
                 (leaf-pre-init-after)))
     (prog1 'leaf
       (leaf-init)
       (require 'leaf)
       (progn
         (leaf-pre-init)
         (leaf-pre-init-after))))

    ((leaf leaf
       :init (leaf-init)
       :require t
       :config
       (leaf-pre-init)
       (leaf-pre-init-after))
     (prog1 'leaf
       (leaf-init)
       (require 'leaf)
       (leaf-pre-init)
       (leaf-pre-init-after)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  System keywords
;;

(cort-deftest-with-macroexpand-let leaf/leaf-expand-minimally
    ((leaf-expand-leaf-protect t)
     (leaf-expand-minimally    t))
  '(((leaf leaf
       :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))))

(cort-deftest-with-macroexpand leaf/leaf-autoload
  '(((leaf leaf
       :commands leaf
       :config (leaf-init))
     (prog1 'leaf
       (autoload #'leaf "leaf" nil t)
       (eval-after-load 'leaf
         '(progn
            (leaf-init)))))

    ((leaf leaf
       :leaf-autoload nil
       :commands leaf
       :config (leaf-init))
     (prog1 'leaf
       (eval-after-load 'leaf
         '(progn
            (leaf-init)))))))

(cort-deftest-with-macroexpand leaf/leaf-defer
  '(((leaf leaf
       :commands leaf
       :config (leaf-init))
     (prog1 'leaf
       (autoload #'leaf "leaf" nil t)
       (eval-after-load 'leaf
         '(progn
            (leaf-init)))))

    ((leaf leaf
       :leaf-defer nil
       :commands leaf
       :config (leaf-init))
     (prog1 'leaf
       (autoload #'leaf "leaf" nil t)
       (leaf-init)))))

(cort-deftest-with-macroexpand-let leaf/leaf-protect
    ((leaf-expand-leaf-protect t))
  '(((leaf leaf
       :config (leaf-init))
     (prog1 'leaf
       (leaf-handler-leaf-protect leaf
         (leaf-init))))

    ((leaf leaf
       :leaf-protect nil
       :config (leaf-init))
     (prog1 'leaf
       (leaf-init)))

    ((leaf leaf
       :leaf-protect t nil
       :config (leaf-init))
     (prog1 'leaf
       (leaf-handler-leaf-protect leaf
         (leaf-init))))

    ((leaf-handler-leaf-protect leaf
       (leaf-load)
       (leaf-init))
     (condition-case err
         (progn
           (leaf-load)
           (leaf-init))
       (error
        (display-warning 'leaf
                         (format "Error in `leaf' block.  Error msg: %s"
                                 (error-message-string err))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Support leaf macros
;;

(cort-deftest-with-macroexpand leaf/handler-package
  '(
    ;; simple :ensure expandion example
    ((leaf macrostep :ensure t)
     (prog1 'macrostep
       (leaf-handler-package macrostep macrostep nil)))

    ;; `leaf-handler-package' expandion example.
    ;; If `macrostep' isn't installed, try to install.
    ;; If fail install, update local cache and retry to install.
    ((leaf-handler-package macrostep macrostep nil)
     (unless (package-installed-p 'macrostep)
       (unless (assoc 'macrostep package-archive-contents)
         (package-refresh-contents))
       (condition-case err
           (package-install 'macrostep)
         (error
          (condition-case err
              (progn
                (package-refresh-contents)
                (package-install 'macrostep))
            (error
             (signal 'error
                     (format "In `macrostep' block, failed to :package of macrostep.  Error msg: %s"
                             (error-message-string err)))))))))))

(when (version< "24.0" emacs-version)
  (cort-deftest-with-macroexpand leaf/leaf-key
    '(((leaf-key "C-M-i" 'flyspell-correct-wrapper)
       (let* ((old (lookup-key global-map (kbd "C-M-i")))
              (value `(("C-M-i" . global-map) flyspell-correct-wrapper ,(and old (not (numberp old)) old))))
         (push value leaf-key-bindlist)
         (define-key global-map (kbd "C-M-i") 'flyspell-correct-wrapper)))

      ((leaf-key [remap backward-sentence] 'sh-beginning-of-command)
       (let* ((old (lookup-key global-map [remap backward-sentence]))
              (value `(("<remap> <backward-sentence>" . global-map) sh-beginning-of-command ,(and old (not (numberp old)) old))))
         (push value leaf-key-bindlist)
         (define-key global-map [remap backward-sentence] 'sh-beginning-of-command)))

      ((leaf-key "C-M-i" 'flyspell-correct-wrapper 'c-mode-map)
       (let* ((old (lookup-key c-mode-map (kbd "C-M-i")))
              (value `(("C-M-i" . c-mode-map) flyspell-correct-wrapper ,(and old (not (numberp old)) old))))
         (push value leaf-key-bindlist)
         (define-key c-mode-map (kbd "C-M-i") 'flyspell-correct-wrapper)))

      ((leaf-key [remap backward-sentence] 'sh-beginning-of-command)
       (let* ((old (lookup-key global-map [remap backward-sentence]))
              (value `(("<remap> <backward-sentence>" . global-map) sh-beginning-of-command ,(and old (not (numberp old)) old))))
         (push value leaf-key-bindlist)
         (define-key global-map [remap backward-sentence] 'sh-beginning-of-command)))

      ((leaf-key (vector 'key-chord ?i ?j) 'undo nil)
       (let* ((old (lookup-key global-map (vector 'key-chord 105 106)))
              (value `(("<key-chord> i j" . global-map) undo ,(and old (not (numberp old)) old))))
         (push value leaf-key-bindlist)
         (define-key global-map (vector 'key-chord 105 106) 'undo))))))

(cort-deftest-with-macroexpand leaf/leaf-key*
  '(((leaf-key* "C-M-i" 'flyspell-correct-wrapper)
     (leaf-key "C-M-i" 'flyspell-correct-wrapper 'leaf-key-override-global-map))

    ((leaf-key* [remap backward-sentence] 'sh-beginning-of-command)
     (leaf-key [remap backward-sentence] 'sh-beginning-of-command 'leaf-key-override-global-map))))

(cort-deftest-with-macroexpand leaf/leaf-keys
  '(((leaf-keys ("C-M-i" . flyspell-correct-wrapper))
     (leaf-key "C-M-i"
               #'flyspell-correct-wrapper))

    ((leaf-keys (("C-M-i" . flyspell-correct-wrapper)))
     (leaf-key "C-M-i"
               #'flyspell-correct-wrapper))

    ((leaf-keys (("C-c C-n" . go-run)
                 ("C-c ."   . go-test-current-test)))
     (progn
       (leaf-key "C-c C-n" #'go-run)
       (leaf-key "C-c ." #'go-test-current-test)))

    ((leaf-keys (:go-mode-map ("C-M-i" . flyspell-correct-wrapper)))
     (progn
       (leaf-key "C-M-i" #'flyspell-correct-wrapper 'go-mode-map)))

    ((leaf-keys (:go-mode-map
                 ("C-c C-n" . go-run)
                 ("C-c ."   . go-test-current-test)))
     (progn
       (leaf-key "C-c C-n" #'go-run 'go-mode-map)
       (leaf-key "C-c ." #'go-test-current-test 'go-mode-map)))

    ((leaf-keys (:go-mode-map (("C-c C-n" . go-run)
                               ("C-c ."   . go-test-current-test))))
     (progn
       (leaf-key "C-c C-n" #'go-run 'go-mode-map)
       (leaf-key "C-c ." #'go-test-current-test 'go-mode-map)))

    ((leaf-keys (:go-mode-map
                 :package go-mode
                 ("C-M-i" . flyspell-correct-wrapper)))
     (eval-after-load 'go-mode
       '(progn
          (leaf-key "C-M-i" #'flyspell-correct-wrapper 'go-mode-map))))

    ((leaf-keys (:go-mode-map
                 :package go-mode
                 (("C-c C-n" . go-run)
                  ("C-c ."   . go-test-current-test))))
     (eval-after-load 'go-mode
       '(progn
          (leaf-key "C-c C-n" #'go-run 'go-mode-map)
          (leaf-key "C-c ." #'go-test-current-test 'go-mode-map))))

    ((leaf-keys (:go-mode-map
                 :package (cc-mode go-mode)
                 (("C-c C-n" . go-run)
                  ("C-c ."   . go-test-current-test))))
     (eval-after-load 'go-mode
       '(eval-after-load 'cc-mode
          '(progn
             (leaf-key "C-c C-n" #'go-run 'go-mode-map)
             (leaf-key "C-c ." #'go-test-current-test 'go-mode-map)))))

    ((leaf-keys (:go-mode-map
                 :package (cc-mode go-mode)
                 (("C-c C-n" . go-run)
                  ("C-c ."   . go-test-current-test))))
     (eval-after-load 'go-mode
       '(eval-after-load 'cc-mode
          '(progn
             (leaf-key "C-c C-n" #'go-run 'go-mode-map)
             (leaf-key "C-c ." #'go-test-current-test 'go-mode-map)))))

    ((leaf-keys ((:isearch-mode-map
                  ("M-o" . isearch-moccur)
                  ("M-O" . isearch-moccur-all))
                 (:go-mode-map
                  :package (cc-mode go-mode)
                  (("C-c C-n" . go-run)
                   ("C-c ."   . go-test-current-test)))))
     (progn
       (progn
         (leaf-key "M-o"
                   #'isearch-moccur
                   'isearch-mode-map)
         (leaf-key "M-O"
                   #'isearch-moccur-all
                   'isearch-mode-map))
       (eval-after-load 'go-mode
         '(eval-after-load 'cc-mode
            '(progn
               (leaf-key "C-c C-n"
                         #'go-run
                         'go-mode-map)
               (leaf-key "C-c ."
                         #'go-test-current-test
                         'go-mode-map))))))

    ((leaf-keys (("C-c C-n" . go-run)
                 ("C-c ."   . go-test-current-test)
                 (:isearch-mode-map
                  ("M-o" . isearch-moccur)
                  ("M-O" . isearch-moccur-all))
                 (:go-mode-map
                  :package (cc-mode go-mode)
                  (("C-c C-n" . go-run)
                   ("C-c ."   . go-test-current-test)))))
     (progn
       (leaf-key "C-c C-n" #'go-run)
       (leaf-key "C-c ." #'go-test-current-test)
       (progn
         (leaf-key "M-o" #'isearch-moccur 'isearch-mode-map)
         (leaf-key "M-O" #'isearch-moccur-all 'isearch-mode-map))
       (eval-after-load 'go-mode
         '(eval-after-load 'cc-mode
            '(progn
               (leaf-key "C-c C-n" #'go-run 'go-mode-map)
               (leaf-key "C-c ." #'go-test-current-test 'go-mode-map))))))

    ((leaf-keys (([remap compile] . go-run)
                 ("C-c ."   . go-test-current-test)))
     (progn
       (leaf-key [remap compile] #'go-run)
       (leaf-key "C-c ." #'go-test-current-test)))

    ((leaf-keys (((vector 'key-chord ?i ?j) . undo)
                 ([remap compile] . go-run)
                 ("C-c ."   . go-test-current-test)))
     (progn
       (leaf-key (vector 'key-chord 105 106) #'undo)
       (leaf-key [remap compile] #'go-run)
       (leaf-key "C-c ." #'go-test-current-test)))

    ((leaf-keys (:go-mode-map
                 :package go-mode
                 (((vector 'key-chord ?i ?j) . undo)
                  ("C-c C-n" . go-run)
                  ("C-c ."   . go-test-current-test))))
     (eval-after-load 'go-mode
       '(progn
          (leaf-key (vector 'key-chord 105 106) #'undo 'go-mode-map)
          (leaf-key "C-c C-n" #'go-run 'go-mode-map)
          (leaf-key "C-c ." #'go-test-current-test 'go-mode-map))))))

(cort-deftest-with-macroexpand leaf/leaf-keys-dryrun
  '(((leaf-keys ("C-M-i" . flyspell-correct-wrapper) flyspell)
     '((("C-M-i" . flyspell-correct-wrapper))
       (flyspell-correct-wrapper)))

    ((leaf-keys (("C-M-i" . flyspell-correct-wrapper)) flyspell)
     '((("C-M-i" . flyspell-correct-wrapper))
       (flyspell-correct-wrapper)))

    ((leaf-keys (("C-c C-n" . go-run)
                 ("C-c ."   . go-test-current-test))
                go-mode)
     '((("C-c C-n" . go-run)
        ("C-c ." . go-test-current-test))
       (go-run go-test-current-test)))

    ((leaf-keys (:go-mode-map ("C-M-i" . flyspell-correct-wrapper)) go-mode)
     '(((:go-mode-map :package go-mode
                      ("C-M-i" . flyspell-correct-wrapper)))
       (flyspell-correct-wrapper)))

    ((leaf-keys (:go-mode-map
                 ("C-c C-n" . go-run)
                 ("C-c ."   . go-test-current-test))
                go-mode)
     '(((:go-mode-map :package go-mode
                      ("C-c C-n" . go-run)
                      ("C-c ." . go-test-current-test)))
       (go-run go-test-current-test)))

    ((leaf-keys (:go-mode-map
                 :package go-mode
                 ("C-M-i" . flyspell-correct-wrapper))
                go-mode)
     '(((:go-mode-map :package go-mode
                      ("C-M-i" . flyspell-correct-wrapper)))
       (flyspell-correct-wrapper)))

    ((leaf-keys (:go-mode-map
                 :package go-mode
                 (("C-c C-n" . go-run)
                  ("C-c ."   . go-test-current-test)))
                go-mode)
     '(((:go-mode-map :package go-mode
                      (("C-c C-n" . go-run)
                       ("C-c ." . go-test-current-test))))
       (go-run go-test-current-test)))

    ((leaf-keys (:go-mode-map
                 :package (cc-mode go-mode)
                 (("C-c C-n" . go-run)
                  ("C-c ."   . go-test-current-test)))
                go-mode)
     '(((:go-mode-map :package
                      (cc-mode go-mode)
                      (("C-c C-n" . go-run)
                       ("C-c ." . go-test-current-test))))
       (go-run go-test-current-test)))

    ((leaf-keys (:go-mode-map
                 :package (cc-mode go-mode)
                 (("C-c C-n" . go-run)
                  ("C-c ."   . go-test-current-test)))
                go-mode)
     '(((:go-mode-map :package
                      (cc-mode go-mode)
                      (("C-c C-n" . go-run)
                       ("C-c ." . go-test-current-test))))
       (go-run go-test-current-test)))

    ((leaf-keys ((:isearch-mode-map
                  ("M-o" . isearch-moccur)
                  ("M-O" . isearch-moccur-all))
                 (:go-mode-map
                  :package (cc-mode go-mode)
                  (("C-c C-n" . go-run)
                   ("C-c ."   . go-test-current-test))))
                go-mode)
     '(((:isearch-mode-map :package go-mode
                           ("M-o" . isearch-moccur)
                           ("M-O" . isearch-moccur-all))
        (:go-mode-map :package
                      (cc-mode go-mode)
                      (("C-c C-n" . go-run)
                       ("C-c ." . go-test-current-test))))
       (isearch-moccur isearch-moccur-all go-run go-test-current-test)))

    ((leaf-keys (("C-c C-n" . go-run)
                 ("C-c ."   . go-test-current-test)
                 (:isearch-mode-map
                  ("M-o" . isearch-moccur)
                  ("M-O" . isearch-moccur-all))
                 (:go-mode-map
                  :package (cc-mode go-mode)
                  (("C-c C-n" . go-run)
                   ("C-c ."   . go-test-current-test))))
                go-mode)
     '((("C-c C-n" . go-run)
        ("C-c ." . go-test-current-test)
        (:isearch-mode-map :package go-mode
                           ("M-o" . isearch-moccur)
                           ("M-O" . isearch-moccur-all))
        (:go-mode-map :package
                      (cc-mode go-mode)
                      (("C-c C-n" . go-run)
                       ("C-c ." . go-test-current-test))))
       (go-run go-test-current-test isearch-moccur isearch-moccur-all go-run go-test-current-test)))

    ((leaf-keys (([remap compile] . go-run)
                 ("C-c ."   . go-test-current-test))
                go-mode)
     '((([remap compile] . go-run)
        ("C-c ." . go-test-current-test))
       (go-run go-test-current-test)))

    ((leaf-keys (((vector 'key-chord ?i ?j) . undo)
                 ([remap compile] . go-run)
                 ("C-c ."   . go-test-current-test))
                go-mode)
     '((((vector 'key-chord 105 106) . undo)
        ([remap compile] . go-run)
        ("C-c ." . go-test-current-test))
       (undo go-run go-test-current-test)))

    ((leaf-keys (:go-mode-map
                 :package go-mode
                 (((vector 'key-chord ?i ?j) . undo)
                  ("C-c C-n" . go-run)
                  ("C-c ."   . go-test-current-test)))
                go-mode)
     '(((:go-mode-map :package go-mode
                      (((vector 'key-chord 105 106) . undo)
                       ("C-c C-n" . go-run)
                       ("C-c ." . go-test-current-test))))
       (undo go-run go-test-current-test)))

    ((leaf-keys (isearch-mode-map
                 :package isearch
                 ("M-o" . isearch-moccur)
                 ("M-O" . isearch-moccur-all)))
     (eval-after-load 'isearch
       '(progn
          (leaf-key "M-o" #'isearch-moccur 'isearch-mode-map)
          (leaf-key "M-O" #'isearch-moccur-all 'isearch-mode-map))))))

(cort-deftest-with-macroexpand leaf/leaf-keys*
  '(((leaf-keys* ("C-M-i" . flyspell-correct-wrapper))
     (leaf-keys
      (:leaf-key-override-global-map
       ("C-M-i" . flyspell-correct-wrapper))))

    ((leaf-keys* (("C-c C-n" . go-run)
                  ("C-c ."   . go-test-current-test)))
     (leaf-keys
      (:leaf-key-override-global-map
       ("C-c C-n" . go-run)
       ("C-c ." . go-test-current-test))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Misc functions
;;

(cort-deftest-with-equal leaf/pairp
  '(((leaf-pairp nil) nil)
    ((leaf-pairp t)   nil)
    ((leaf-pairp 'a)  nil)

    ((leaf-pairp '(nil . nil)) nil)
    ((leaf-pairp '(a . nil))   nil)
    ((leaf-pairp '(a . t))     t)
    ((leaf-pairp '(a . 'b))    t)
    ((leaf-pairp '(a . `b))    t)
    ((leaf-pairp '(a . #'b))   t)
    ((leaf-pairp '(a . (lambda (elm) elm))) t)))

(cort-deftest-with-equal leaf/pairp-allow-nil
  '(((leaf-pairp nil 'allow-nil) t)
    ((leaf-pairp t   'allow-nil) nil)
    ((leaf-pairp 'a  'allow-nil) nil)

    ((leaf-pairp '(nil . nil) 'allow-nil) t)
    ((leaf-pairp '(a . nil)   'allow-nil) t)
    ((leaf-pairp '(a . t)     'allow-nil) t)
    ((leaf-pairp '(a . 'b)    'allow-nil) t)
    ((leaf-pairp '(a . `b)    'allow-nil) t)
    ((leaf-pairp '(a . #'b)   'allow-nil) t)
    ((leaf-pairp '(a . (lambda (elm) elm))) t)))

(cort-deftest-with-equal leaf/normalize-list-in-list--normal
  '(((leaf-normalize-list-in-list 'a)                   '(a))
    ((leaf-normalize-list-in-list '(a b c))             '(a b c))
    ((leaf-normalize-list-in-list '(a . b))             '(a . b))
    ((leaf-normalize-list-in-list '(a . nil))           '(a . nil))
    ((leaf-normalize-list-in-list '(a . 'b))            '(a . 'b))
    ((leaf-normalize-list-in-list '(a . 'nil))          '(a . 'nil))
    ((leaf-normalize-list-in-list '(a))                 '(a . nil))
    ((leaf-normalize-list-in-list '((a . b) (c . d)))   '((a . b) (c . d)))
    ((leaf-normalize-list-in-list '((a . 'b) (c . 'd))) '((a . 'b) (c . 'd)))
    ((leaf-normalize-list-in-list '((a) (b) (c)))       '((a) (b) (c)))
    ((leaf-normalize-list-in-list '((a b c) . d))       '((a b c) . d))
    ((leaf-normalize-list-in-list '((a b c) . 'd))      '((a b c) . 'd))))

(cort-deftest-with-equal normalize-list-in-list--distribute
  '(((leaf-normalize-list-in-list 'a                          'dotlist) '((a)))
    ((leaf-normalize-list-in-list '(a)                        'dotlist) '((a . nil)))
    ((leaf-normalize-list-in-list '(a b c)                    'dotlist) '((a . nil) (b . nil) (c . nil)))
    ((leaf-normalize-list-in-list '(a . b)                    'dotlist) '((a . b)))
    ((leaf-normalize-list-in-list '(a . nil)                  'dotlist) '((a . nil)))
    ((leaf-normalize-list-in-list '(a . 'nil)                 'dotlist) '((a . 'nil)))
    ((leaf-normalize-list-in-list '(a . 'b)                   'dotlist) '((a . 'b)))
    ((leaf-normalize-list-in-list '(a . `b)                   'dotlist) '((a . `b)))
    ((leaf-normalize-list-in-list '(a . #'b)                  'dotlist) '((a . #'b)))
    ((leaf-normalize-list-in-list '(a . '(b c))               'dotlist) '((a . '(b c))))
    ((leaf-normalize-list-in-list '(a . `(b ,c))              'dotlist) '((a . `(b ,c))))
    ((leaf-normalize-list-in-list '(a . (lambda (v) v))       'dotlist) '((a . (lambda (v) v))))
    ((leaf-normalize-list-in-list '(a . '(lambda (v) v))      'dotlist) '((a . '(lambda (v) v))))
    ((leaf-normalize-list-in-list '(a . #'(lambda (v) v))     'dotlist) '((a . #'(lambda (v) v))))
                                                              
    ((leaf-normalize-list-in-list '(a z . b)                  'dotlist) '((a . b) (z . b)))
    ((leaf-normalize-list-in-list '(a z . nil)                'dotlist) '((a . nil) (z . nil)))
    ((leaf-normalize-list-in-list '(a z . 'nil)               'dotlist) '((a . 'nil) (z . 'nil)))
    ((leaf-normalize-list-in-list '(a z . 'b)                 'dotlist) '((a . 'b) (z . 'b)))
    ((leaf-normalize-list-in-list '(a z . `b)                 'dotlist) '((a . `b) (z . `b)))
    ((leaf-normalize-list-in-list '(a z . #'b)                'dotlist) '((a . #'b) (z . #'b)))
    ((leaf-normalize-list-in-list '(a z . '(b c))             'dotlist) '((a . '(b c)) (z . '(b c))))
    ((leaf-normalize-list-in-list '(a z . `(b ,c))            'dotlist) '((a . `(b ,c)) (z . `(b ,c))))
    ((leaf-normalize-list-in-list '(a z . (lambda (v) v))     'dotlist) '((a . (lambda (v) v)) (z . (lambda (v) v))))
    ((leaf-normalize-list-in-list '(a z . '(lambda (v) v))    'dotlist) '((a . '(lambda (v) v)) (z . '(lambda (v) v))))
    ((leaf-normalize-list-in-list '(a z . #'(lambda (v) v))   'dotlist) '((a . #'(lambda (v) v)) (z . #'(lambda (v) v))))
                                                              
    ((leaf-normalize-list-in-list '((a) (b))                  'dotlist) '((a . nil) (b . nil)))
    ((leaf-normalize-list-in-list '((a . b) (c . nil))        'dotlist) '((a . b) (c . nil)))
    ((leaf-normalize-list-in-list '((a . b) (c . d))          'dotlist) '((a . b) (c . d)))
    ((leaf-normalize-list-in-list '((a . 'b) (c . 'd))        'dotlist) '((a . 'b) (c . 'd)))
    ((leaf-normalize-list-in-list '((a . 'b) (c . #'d))       'dotlist) '((a . 'b) (c . #'d)))
    ((leaf-normalize-list-in-list '((a . 'b) (c . '(d e)))    'dotlist) '((a . 'b) (c . '(d e))))
    ((leaf-normalize-list-in-list '((a . 'b) (c . `(d ,e)))   'dotlist) '((a . 'b) (c . `(d ,e))))
    ((leaf-normalize-list-in-list '((a . 'b) (c . (lambda (v) v)))   'dotlist) '((a . 'b) (c . (lambda (v) v))))
    ((leaf-normalize-list-in-list '((a . 'b) (c . '(lambda (v) v)))  'dotlist) '((a . 'b) (c . '(lambda (v) v))))
    ((leaf-normalize-list-in-list '((a . 'b) (c . #'(lambda (v) v))) 'dotlist) '((a . 'b) (c . #'(lambda (v) v))))

    ((leaf-normalize-list-in-list '((a) (b z))                'dotlist) '((a . nil) (b . nil) (z . nil)))
    ((leaf-normalize-list-in-list '((a . b) (c z . nil))      'dotlist) '((a . b) (c . nil) (z . nil)))
    ((leaf-normalize-list-in-list '((a . b) (c z . d))        'dotlist) '((a . b) (c . d) (z . d)))
    ((leaf-normalize-list-in-list '((a . 'b) (c z . 'd))      'dotlist) '((a . 'b) (c . 'd) (z . 'd)))
    ((leaf-normalize-list-in-list '((a . 'b) (c z . #'d))     'dotlist) '((a . 'b) (c . #'d) (z . #'d)))
    ((leaf-normalize-list-in-list '((a . 'b) (c z . '(d e)))  'dotlist) '((a . 'b) (c . '(d e)) (z . '(d e))))
    ((leaf-normalize-list-in-list '((a . 'b) (c z . `(d ,e))) 'dotlist) '((a . 'b) (c . `(d ,e)) (z . `(d ,e))))
    ((leaf-normalize-list-in-list '((a . 'b) (c z . (lambda (v) v)))   'dotlist) '((a . 'b) (c . (lambda (v) v)) (z . (lambda (v) v))))
    ((leaf-normalize-list-in-list '((a . 'b) (c z . '(lambda (v) v)))  'dotlist) '((a . 'b) (c . '(lambda (v) v)) (z . '(lambda (v) v))))
    ((leaf-normalize-list-in-list '((a . 'b) (c z . #'(lambda (v) v))) 'dotlist) '((a . 'b) (c . #'(lambda (v) v)) (z . #'(lambda (v) v))))

    ((leaf-normalize-list-in-list '((a b c) . nil)            'dotlist) '((a . nil) (b . nil) (c . nil)))
    ((leaf-normalize-list-in-list '((a b c) . d)              'dotlist) '((a . d) (b . d) (c . d)))
    ((leaf-normalize-list-in-list '((a b c) . 'd)             'dotlist) '((a . 'd) (b . 'd) (c . 'd)))
    ((leaf-normalize-list-in-list '((a b c) . #'d)            'dotlist) '((a . #'d) (b . #'d) (c . #'d)))
    ((leaf-normalize-list-in-list '((a b c) . (lambda (v) v)) 'dotlist) '((a . (lambda (v) v)) (b . (lambda (v) v)) (c . (lambda (v) v))))
    ((leaf-normalize-list-in-list '((x . 'y) ((a b c) . nil)) 'dotlist) '((x . 'y) (a . nil) (b . nil) (c . nil)))
    ((leaf-normalize-list-in-list '((x . 'y) ((a b c) . d))   'dotlist) '((x . 'y) (a . d) (b . d) (c . d)))
    ((leaf-normalize-list-in-list '((x . 'y) ((a b c) . 'd))  'dotlist) '((x . 'y) (a . 'd) (b . 'd) (c . 'd)))
    ((leaf-normalize-list-in-list '((x . 'y) ((a b c) . #'d)) 'dotlist) '((x . 'y) (a . #'d) (b . #'d) (c . #'d)))
    ((leaf-normalize-list-in-list '((x . 'y) ((a b c) . (lambda (v) v))) 'dotlist) '((x . 'y) (a . (lambda (v) v)) (b . (lambda (v) v)) (c . (lambda (v) v))))))

(provide 'leaf-tests)

;; Local Variables:
;; indent-tabs-mode: nil
;; End:

;;; leaf-tests.el ends here

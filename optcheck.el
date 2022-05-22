;;; optcheck.el --- A flycheck extension to report optimisation success/failure. -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2022  Paul Bartholomew
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;;
;;; Header:
;;
;; Created: 2022-05-21
;; Version: 0.0
;; Package-Requires: ((flycheck "0.33"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;; Code:

(require 'flycheck)

(flycheck-def-option-var flycheck-gcc-vectorize t c/c++-gcc
  "Whether to enable auto-vectorization in GCC.

When non-nil, enable auto-vectorization for optimisation checker, via
`-ftree-vectorize'."
  :type 'boolean
  :safe #'booleanp
  :package-version '(flycheck . "0.21"))

(flycheck-def-option-var flycheck-gfortran-vectorize t fortran-gfortran-opt
  "Whether to enable auto-vectorization in gfortran.

When non-nil, enable auto-vectorization for optimisation checker, via
`-ftree-vectorize'."
  :type 'boolean
  :safe #'booleanp
  :package-version '(flycheck . "0.21"))

(flycheck-define-checker c/c++-gcc-opt
  "Reports missed optimisations in C/C++ code using GCC.

This reporter is based on the c/c++-gcc syntax checker from flycheck."
  :command ("gcc"
	    ;; Request GCC to report all missed optimisations
	    "-fopt-info-missed-optall"
	    "-O2" ;; Nothing seems to be reported below -O2
            "-fshow-column"
            "-iquote" (eval (flycheck-c/c++-quoted-include-directory))
            (option "-std=" flycheck-gcc-language-standard concat)
            (option-flag "-fno-exceptions" flycheck-gcc-no-exceptions)
            (option-flag "-fno-rtti" flycheck-gcc-no-rtti)
	    (option-flag "-ftree-vectorize" flycheck-gcc-vectorize)
            (option-flag "-fopenmp" flycheck-gcc-openmp)
            (option-list "-include" flycheck-gcc-includes)
            (option-list "-W" flycheck-gcc-warnings concat)
            (option-list "-D" flycheck-gcc-definitions concat)
            (option-list "-I" flycheck-gcc-include-path)
            (eval flycheck-gcc-args)
            "-x" (eval
                  (pcase major-mode
                    (`c++-mode "c++")
                    (`c-mode "c")))
            ;; GCC performs full checking only when actually compiling, so `-fsyntax-only' is not enough. Just let it
            ;; generate assembly code.
            "-S" "-o" null-device
            ;; Read from standard input
            "-")
  :standard-input t
  :error-patterns ((info line-start (or "<stdin>" (file-name))
			 ":" line (optional ":" column)
			 ": missed: " (message) line-end))
  :modes (c-mode c++-mode))

(flycheck-define-checker fortran-gfortran-opt
  "Reports missed optimisations in Fortran code using gfortran.

Uses GCC's Fortran compiler gfortran.  See URL
`https://gcc.gnu.org/onlinedocs/gfortran/'."
  :command ("gfortran"
	    ;; Request GCC to report all missed optimisations
	    "-fopt-info-missed-optall"
	    "-O2" ;; Nothing seems to be reported below -O2
            "-fshow-column"
            ;; Do not visually indicate the source location
            "-fno-diagnostics-show-caret"
            ;; Do not show the corresponding warning group
            "-fno-diagnostics-show-option"
            ;; Fortran has similar include processing as C/C++
            "-iquote" (eval (flycheck-c/c++-quoted-include-directory))
            (option "-std=" flycheck-gfortran-language-standard concat)
            (option "-f" flycheck-gfortran-layout concat flycheck-option-gfortran-layout)
	    (option-flag "-ftree-vectorize" flycheck-gfortran-vectorize)
            (option-list "-W" flycheck-gfortran-warnings concat)
            (option-list "-I" flycheck-gfortran-include-path concat)
            (eval flycheck-gfortran-args)
            ;; Optimisation is only attempted when actually compiling, so `-fsyntax-only' is not enough. Just let it
            ;; generate assembly code.
	    "-S" "-o" null-device
	    ;; Specify the input
	    source)
  :error-patterns ((info line-start (or "<stdin>" (file-name))
			 ":" line (optional ":" column)
			 ": missed: " (message) line-end))
  :error-filter optcheck/gnu-filter
  :modes (fortran-mode f90-mode))

(defun optcheck/gnu-filter (missed-opts)
  "Filter `MISSED-OPTS' to reduce noise in GNU missed optimisation reports.

For example, many missed optimisation reports will flood the output with
'statement clobbers memory' to the extent it is useless, this function will
filter out messages in `MISSED-OPTS' to reduce this noise."
  (flycheck-sanitize-errors
  (seq-remove
      (lambda (err)
	(-when-let (msg (flycheck-error-message err))
	  (or (string-match-p "statement clobbers memory" msg)
	      (string-match-p "function body not available" msg))))
      missed-opts)))

;; Register the optimisation reporter.
(setq flycheck-checkers (append flycheck-checkers
				'(c/c++-gcc-opt
				  fortran-gfortran-opt)))

;; Perform optimisation report AFTER running syntax checkers.
;; The APPEND attribute is set TRUE to ensure any additional checkers
;; already specified are run.
(flycheck-add-next-checker 'c/c++-gcc '(warning . c/c++-gcc-opt) t)
(flycheck-add-next-checker 'fortran-gfortran '(warning . fortran-gfortran-opt) t)
(provide 'optcheck)

;;; optcheck.el ends here

;;; optcheck --- A flycheck extension to report optimisation success/failure.
;;
;;; Commentary:
;;
;;; Code:

(require 'flycheck)

(flycheck-define-checker c/c++-gcc-opt
  "A C/C++ missed optimisation reporter using GCC.

Requires GCC 4.4 or newer.  See URL `https://gcc.gnu.org/'."
  :command ("gcc"
	    "-fopt-info-missed-optall"
            "-fshow-column"
            "-iquote" (eval (flycheck-c/c++-quoted-include-directory))
            (option "-std=" flycheck-gcc-language-standard concat)
            (option-flag "-fno-exceptions" flycheck-gcc-no-exceptions)
            (option-flag "-fno-rtti" flycheck-gcc-no-rtti)
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
            ;; GCC performs full checking only when actually compiling, so
            ;; `-fsyntax-only' is not enough. Just let it generate assembly
            ;; code.
            "-S" "-o" null-device
            ;; Read from standard input
            "-")
  :standard-input t
  :error-patterns ((info line-start (or "<stdin>" (file-name))
			 ":" line (optional ":" column)
			 ": missed: " (message) line-end))
  :modes (c-mode c++-mode)
  :next-checkers ((warning . c/c++-cppcheck)))

(provide 'optcheck)

;;; optcheck.el ends here

;;; -*- lexical-binding: t -*-

(require 'with-simulated-input)
(require 'cl-lib)
(require 'buttercup)

;; Needs to be dynamically bound
(defvar my-collection)
(defvar my-non-lexical-var)

(defun call-wsi-from-bytecomp-fun ()
  "This function calls `with-simulated-input' and is byte-compiled.

It will only work if `with-simulated-input' works when called
from byte-compiled code."
  (with-simulated-input "hello SPC world RET"
    (read-string "Say hello: ")))
(byte-compile 'call-wsi-from-bytecomp-fun)

(describe "`wsi-get-unbound-key'"
  (it "should find an unbound key"
    (let ((unbound-key (wsi-get-unbound-key)))
      (expect unbound-key :to-be-truthy)
      (expect (wsi-key-bound-p unbound-key) :not :to-be-truthy)))
  (it "should report an error if it fails to find an unbound key"
    ;; Now we call it with an empty list of modifiers and keys to
    ;; search, so it definitely should not find a binding.
    (expect
     (let ((wsi-last-used-next-action-bind nil))
       (wsi-get-unbound-key "" '("abc" "123")))
     :to-throw 'error))
  (it "should find a new key when its previously chosen key becomes bound"
    (let ((overriding-terminal-local-map (make-sparse-keymap))
          (previous-key (wsi-get-unbound-key)))
      (define-key overriding-terminal-local-map
        (kbd previous-key) #'ignore)
      ;; Claim another few unbound keys as well, just for good
      ;; measure.
      (define-key overriding-terminal-local-map
        (kbd (wsi-get-unbound-key)) #'ignore)
      (define-key overriding-terminal-local-map
        (kbd (wsi-get-unbound-key)) #'ignore)
      (define-key overriding-terminal-local-map
        (kbd (wsi-get-unbound-key)) #'ignore)
      (expect
       (wsi-get-unbound-key)
       :not :to-equal previous-key))))

(defmacro expect-warning (&rest body)
  "Evaluate BODY and verify that it produces a warning.

Note that in order to catch warnings produced during macro
expansion, Eldev is configure to unbind the
`internal-macroexpand-for-load' function while loading this test
file."
  (declare (debug body))
  `(progn
     (spy-on #'display-warning :and-call-through)
     (prog1 (progn ,@body)
       (expect #'display-warning :to-have-been-called))))

(describe "`with-simulated-input'"

  (before-each
    (setq warnings-displayed-count 0))

  (describe "should work when KEYS"

    (it "is a literal string"
      (expect
       (with-simulated-input "hello RET"
         (read-string "Enter a string: "))
       :to-equal "hello"))

    (it "is a literal character"
      (expect
       (with-simulated-input ?y
         (read-char "Choose your character: "))
       :to-equal ?y))

    (it "is a quoted list of literal strings (deprecated)"
      (expect-warning
       (expect
        (with-simulated-input '("hello" "RET")
          (read-string "Enter a string: "))
        :to-equal "hello")))

    (it "is a quoted list of characters (deprecated)"
      (expect-warning
       (expect
        ;; 10 is RET
        (with-simulated-input '(?h ?e ?l ?l ?o 10)
          (read-string "Enter a string: "))
        :to-equal "hello")))

    (it "is a quoted list of lisp forms (deprecated)"
      (expect-warning
       (expect
        (with-simulated-input '((insert "hello") (exit-minibuffer))
          (read-string "Enter a string: "))
        :to-equal "hello")))

    (it "is a quoted list of strings, characters, and lisp forms (deprecated)"
      (expect-warning
       (expect
        (with-simulated-input '((insert "hello") "RET")
          (read-string "Enter a string: "))
        :to-equal "hello"))
      (expect-warning
       (expect
        (with-simulated-input '("hello" (exit-minibuffer))
          (read-string "Enter a string: "))
        :to-equal "hello"))
      (expect-warning
       (expect
        ;; 10 is RET
        (with-simulated-input '("hello SPC" (insert "world") "RET")
          (read-string "Enter a string: "))
        :to-equal "hello world"))
      (expect-warning
       (expect
        (with-simulated-input '("hello SPC" (insert "wor") ?l ?d 10)
          (read-string "Enter a string: "))
        :to-equal "hello world")))

    (it "is an un-quoted list of literal strings"
      (expect
       (with-simulated-input ("hello" "RET")
         (read-string "Enter a string: "))
       :to-equal "hello"))

    (it "is a quoted list of characters"
      (expect
       ;; 10 is RET
       (with-simulated-input (?h ?e ?l ?l ?o 10)
         (read-string "Enter a string: "))
       :to-equal "hello"))

    (it "is an un-quoted list of lisp forms"
      (expect
       (with-simulated-input ((insert "hello") (exit-minibuffer))
         (read-string "Enter a string: "))
       :to-equal "hello"))

    (it "is an un-quoted list of strings and lisp forms"
      (expect
       (with-simulated-input ((insert "hello") "RET")
         (read-string "Enter a string: "))
       :to-equal "hello")
      (expect
       (with-simulated-input ("hello" (exit-minibuffer))
         (read-string "Enter a string: "))
       :to-equal "hello")
      (expect
       (with-simulated-input ("hello SPC" (insert "world") "RET")
         (read-string "Enter a string: "))
       :to-equal "hello world")
      (expect
       (with-simulated-input ("hello SPC" (insert "wor") ?l ?d 10)
         (read-string "Enter a string: "))
       :to-equal "hello world"))

    ;; TODO: Decide whether to deprecate this
    (it "is a variable containing any of the above"
      (cl-loop
       for input in
       '("hello RET"
         ("hello" "RET")
         ((insert "hello") (exit-minibuffer))
         ((insert "hello") "RET")
         ("hello" (exit-minibuffer))
         (?h ?e ?l ?l ?o 10))
       do (expect
           (with-simulated-input input
             (read-string "Enter a string: "))
           :to-equal "hello"))
      (let ((answer-char ?y))
        (expect
         (with-simulated-input answer-char
           (read-char "Choose your character: "))
         :to-equal answer-char)))

    ;; This syntax is not known to be used in any real code.
    (it "is an arbitrary expression evaluating to any of the above (deprecated)"
      (expect-warning
       (expect
        (with-simulated-input (list "hello" "RET")
          (read-string "Enter a string: "))
        :to-equal "hello"))
      (expect-warning
       (expect
        (let ((my-input "hello"))
          (with-simulated-input (list (list 'insert my-input) "RET")
            (read-string "Enter a string: ")))
        :to-equal "hello"))
      (expect-warning
       (expect
        (with-simulated-input (concat "hello" " " "RET")
          (read-string "Enter a string: "))
        :to-equal "hello")
       (let ((my-key-sequence (kbd "hello"))
             (my-lisp-form '(insert " world")))
         (expect-warning
          (expect
           (with-simulated-input (list
                                  my-key-sequence
                                  my-lisp-form
                                  "RET")
             (read-string "Enter a string: "))
           :to-equal "hello world"))
         (expect-warning
          (expect
           (with-simulated-input '((execute-kbd-macro my-key-sequence)
                                   (eval my-lisp-form)
                                   "RET")
             (read-string "Enter a string: "))
           :to-equal "hello world"))
         (expect-warning
          (expect
           (with-simulated-input (list
                                  `(execute-kbd-macro ,my-key-sequence)
                                  `(eval ,my-lisp-form)
                                  "RET")
             (read-string "Enter a string: "))
           :to-equal "hello world"))
         (expect-warning
          (expect
           (with-simulated-input `((execute-kbd-macro ,my-key-sequence)
                                   (eval ,my-lisp-form)
                                   "RET")
             (read-string "Enter a string: "))
           :to-equal "hello world")))))

    ;; This syntax is not known to be used in any real code
    (it "is evaluated at run time in a lexical environment"
      (expect-warning
       (let ((my-input "hello"))
         (expect
          (with-simulated-input `((insert ,my-input) "RET")
            (read-string "Enter a string: "))
          :to-equal "hello")))
      (expect-warning
       (let ((greeting "hello")
             (target "world"))
         (expect
          (with-simulated-input
              (list greeting "SPC"
                    (list 'insert target)
                    "RET")
            (read-string "Say hello: "))
          :to-equal "hello world")))
      (let ((my-lexical-var nil))
        (with-simulated-input ("hello"
                               (setq my-lexical-var t)
                               "RET")
          (read-string "Enter a string: "))
        (expect my-lexical-var
                :to-be-truthy)))

    (it "is evaluated at run time in a non-lexical environment"
      (let ((my-non-lexical-var nil))
        (eval
         '(with-simulated-input ("hello"
                                 (setq my-non-lexical-var t)
                                 "RET")
            (read-string "Enter a string: "))
         nil)
        (expect my-non-lexical-var
                :to-be-truthy))))

  (describe "should throw an error when KEYS"

    (it "is an invalid literal expression"
      (expect
       ;; Eval prevents eager macro-expansion, since this macro
       ;; expansion throws an error.
       (eval '(with-simulated-input :invalid-input
                (read-string "Enter a string: ")))
       :to-throw 'error)
      (expect
       (eval '(with-simulated-input ["vectors" "are" "invalid"]
                (read-string "Enter a string: ")))
       :to-throw 'error))

    (it "is a variable with an invalid value"
      (cl-loop
       for input in
       '(:invalid-input
         ["vectors" "are" "invalid"])
       do (expect
           (with-simulated-input input
             (read-string "Enter a string: "))
           :to-throw 'error))))

  (describe "should correctly propagate an error when it"

    (it "is thrown directly from expressions in KEYS"
      (expect
       (with-simulated-input ("hello" (error "Throwing an error from KEYS") "RET")
         (read-string "Enter a string: "))
       :to-throw 'error '("Throwing an error from KEYS")))

    (it "is caused indirectly by the inputs in KEYS"
      (expect
       (with-simulated-input
           "(error SPC \"Manually SPC throwing SPC an SPC error\") RET"
         (command-execute 'eval-expression))
       :to-throw 'error '("Manually throwing an error")))

    (it "is thrown by BODY"
      (expect
       (with-simulated-input
           "hello RET"
         (read-string "Enter a string: ")
         (error "Throwing an error after reading input"))
       :to-throw 'error '("Throwing an error after reading input"))
      (expect
       (with-simulated-input
           "hello RET"
         (error "Throwing an error before reading input")
         (read-string "Enter a string: "))
       :to-throw 'error '("Throwing an error before reading input")))

    (it "is caused by C-g in KEYS"
      (expect
       (condition-case nil
           (with-simulated-input "C-g"
             (read-string "Enter a string: "))
         (quit 'caught-quit))
       :to-be 'caught-quit)))

  ;; TODO: Warn on no-op elements like this: any variable or
  ;; non-string literal, or any expression known to involve only pure
  ;; functions.
  (it "should ignore the return value of non-literal expressions in KEYS"
    (expect-warning
     (let ((desired-input "hello")
           (undesired-input "goodbye"))
       (expect
        (with-simulated-input
            ((prog1 undesired-input
               ;; This is the only thing that should actually get
               ;; inserted.
               (insert desired-input))
             undesired-input
             "RET")
          (read-string "Enter a string: "))
        :to-equal desired-input))))

  (it "should throw an error if the input is incomplete"
    (expect
     (with-simulated-input "hello"      ; No RET
       (read-string "Enter a string: "))
     :to-throw 'error))

  (it "should throw an error if the input is empty and BODY reads input"
    (expect
     (with-simulated-input nil
       (read-string "Enter a string: "))
     :to-throw 'error)
    (expect
     (with-simulated-input ()
       (read-string "Enter a string: "))
     :to-throw 'error)
    (expect-warning
     (expect
      (with-simulated-input '()
        (read-string "Enter a string: "))
      :to-throw 'error)
     (expect
      (with-simulated-input (nil)
        (read-string "Enter a string: "))
      :to-throw 'error))
    (let ((my-input nil))
      (expect
       (with-simulated-input my-input
         (read-string "Enter a string: "))
       :to-throw 'error)))

  (it "should not throw an error if the input is empty unless BODY reads input"
    (expect
     (with-simulated-input nil
       (+ 1 2))
     :not :to-throw)
    (expect
     (with-simulated-input ()
       (+ 1 2))
     :not :to-throw)
    (expect-warning
     (expect
      (with-simulated-input '()
        (+ 1 2))
      :not :to-throw)
     (expect
      (with-simulated-input '(nil)
        (+ 1 2))
      :not :to-throw))
    (let ((my-input nil))
      (expect
       (with-simulated-input my-input
         (+ 1 2))
       :not :to-throw)))

  (it "should discard any extra input after BODY has completed"
    (expect
     (with-simulated-input
         "hello RET M-x eval-expression (error SPC \"Manually SPC throwing SPC an SPC error\") RET"
       (read-string "Enter a string: "))
     :to-equal "hello")
    (expect
     (with-simulated-input
         ("hello RET" (error "Throwing an error after BODY has completed."))
       (read-string "Enter a string: "))
     :to-equal "hello"))

  (it "should allow multiple functions in BODY to read input"
    (expect
     (with-simulated-input "hello RET world RET"
       (list (read-string "First word: ")
             (read-string "Second word: ")))
     :to-equal '("hello" "world")))

  (it "should allow an empty/constant BODY, with a warning"
    ;; We need `eval' to ensure the macro is evalauted during the
    ;; test, not while loading the file.
    (expect-warning
     (expect (with-simulated-input "Is SPC anybody SPC listening? RET")
             :to-be nil))
    (expect-warning
     (expect (with-simulated-input "Is SPC anybody SPC listening? RET" t)
             :to-be t))
    (expect-warning
     (expect (with-simulated-input "Is SPC anybody SPC listening? RET" 1 2 3)
             :to-equal 3))
    (expect-warning
     (expect (let ((x (+ 1 2)))
               (with-simulated-input "Is SPC anybody SPC listening? RET" x))
             :to-equal 3)))

  (it "should work when `overriding-terminal-local-map' is bound"
    (let ((overriding-terminal-local-map (make-sparse-keymap)))
      ;; Claim the first few unbound keys to force
      ;; `with-simulated-input' to find a new one.
      (define-key overriding-terminal-local-map
        (kbd (wsi-get-unbound-key)) #'ignore)
      (define-key overriding-terminal-local-map
        (kbd (wsi-get-unbound-key)) #'ignore)
      (define-key overriding-terminal-local-map
        (kbd (wsi-get-unbound-key)) #'ignore)
      (expect
       (with-simulated-input "hello RET"
         (read-string "Enter a string: "))
       :to-equal "hello")))

  (describe "used with `completing-read'"

    :var (completing-read-function)

    (before-each
      (setq my-collection '("bluebird" "blueberry" "bluebell" "bluegrass" "baseball")
            completing-read-function #'completing-read-default))

    ;; Unambiguous completion
    (it "should work with unambiguous tab completion"
      (expect
       ;; First TAB completes "blue", 2nd completes "bird"
       (with-simulated-input "bl TAB bi TAB RET"
         (completing-read "Choose: " my-collection))
       :to-equal "bluebird"))

    (it "should work with ambiguous tab completion"
      (expect
       (with-simulated-input "bl TAB C-j"
         (completing-read "Choose: " my-collection))
       :to-equal "blue"))

    (it "should fail to exit with ambiguous completion and `require-match'"
      ;; Suppress messages by replacing `message' with a stub
      (spy-on 'message)
      (expect
       (with-simulated-input "bl TAB C-j"
         (completing-read "Choose: " my-collection nil t))
       :to-throw 'error)))

  (describe "should not reproduce past issues:"
    ;; https://github.com/DarwinAwardWinner/with-simulated-input/issues/4
    (it "Issue #4: simulating input should not switch buffers"
      (let ((orig-current-buffer (current-buffer)))
        (with-temp-buffer
          (let ((temp-buffer (current-buffer)))
            (with-simulated-input "a" (read-char))
            (expect (current-buffer) :to-equal temp-buffer)
            (expect (current-buffer) :not :to-equal orig-current-buffer)))))
    (it "Issue #6: `with-simulated-input' should work in byte-compiled code"
      (expect (call-wsi-from-bytecomp-fun)
              :not :to-throw))))

(defun time-equal-p (t1 t2)
  "Return non-nil if T1 and T2 represent the same time.

Note that there are multiple ways to represent a time, so
`time-equal-p' does not necessarily imply `equal'."
  (not (or (time-less-p t1 t2)
           (time-less-p t2 t1))))

(defvar canary-idle-time nil)
(defun idle-canary ()
  (setq canary-idle-time (current-idle-time)))
(defvar timers-to-cancel nil)
(defvar orig-timer--activate (symbol-function 'timer--activate))

(describe "`wsi-simulate-idle-time'"

  (before-each
    (setq canary-idle-time nil)
    (spy-on 'idle-canary :and-call-through)
    (spy-on 'timer--activate
            :and-call-fake
            (lambda (timer &rest args)
              (push timer timers-to-cancel)
              (apply orig-timer--activate timer args))))

  (after-each
    (mapc #'cancel-timer timers-to-cancel)
    (setq timers-to-cancel nil)
    (spy-calls-reset 'idle-canary))

  (it "should run idle timers"
    (run-with-idle-timer 500 nil 'idle-canary)
    (wsi-simulate-idle-time 500)
    (expect 'idle-canary :to-have-been-called))

  (it "should not run idle timers with longer times even when called multiple times"
    (run-with-idle-timer 500 nil 'set 'idle-canary)
    (wsi-simulate-idle-time 400)
    (wsi-simulate-idle-time 400)
    (wsi-simulate-idle-time 400)
    (expect 'idle-canary :not :to-have-been-called))

  (it "should run idle timers added by other idle timers"
    (run-with-idle-timer
     100 nil 'run-with-idle-timer
     200 nil 'idle-canary)
    (wsi-simulate-idle-time 500)
    (expect 'idle-canary :to-have-been-called))

  (it "should run idle timers added by other idle timers when the new timer is in the past"
    (run-with-idle-timer
     100 nil 'run-with-idle-timer
     90 nil 'run-with-idle-timer
     80 nil 'run-with-idle-timer
     70 nil 'run-with-idle-timer
     60 nil 'run-with-idle-timer
     50 nil 'idle-canary)
    (wsi-simulate-idle-time 110)
    (expect 'idle-canary :to-have-been-called))

  (it "should run all idle timers when called with SECS = nil"
    (run-with-idle-timer 1000 nil 'idle-canary)
    (wsi-simulate-idle-time 1)
    (expect 'idle-canary :not :to-have-been-called)
    (wsi-simulate-idle-time)
    (expect 'idle-canary :to-have-been-called))

  (it "should simulate the appropriate value for `(current-idle-time)'"
    (spy-on 'current-idle-time@simulate-idle-time :and-call-through)
    (run-with-idle-timer 1 nil 'idle-canary)
    (wsi-simulate-idle-time 2)
    (expect 'current-idle-time@simulate-idle-time :to-have-been-called)
    (expect canary-idle-time :to-be-truthy)
    (expect (time-equal-p canary-idle-time (seconds-to-time 1))))

  (it "should not interfere with the normal operation of `current-idle-time'"
    ;; Outside WSI, this will just return the normal value
    (expect (current-idle-time) :not :to-throw))

  (it "should actually wait the specified time when `actually-wait' is non-nil"
    (spy-on 'sleep-for :and-call-through)
    (run-with-idle-timer 0.01 nil 'idle-canary)
    (run-with-idle-timer 0.02 nil 'idle-canary)
    (run-with-idle-timer 0.03 nil 'idle-canary)
    (run-with-idle-timer 0.04 nil 'idle-canary)
    ;; These shouldn't get called
    (run-with-idle-timer 1 nil 'idle-canary)
    (run-with-idle-timer 2 nil 'idle-canary)
    (run-with-idle-timer 3 nil 'idle-canary)
    (wsi-simulate-idle-time 0.05 t)
    (expect 'idle-canary :to-have-been-called-times 4)
    (expect 'sleep-for :to-have-been-called-times 5))

  (describe "used within `with-simulated-input'"
    (it "should allow idle timers to trigger during simulated input"
      (run-with-idle-timer 500 nil 'insert "world")
      (expect
       (with-simulated-input
           ("hello SPC"
            (wsi-simulate-idle-time 501)
            "RET")
         (read-string "Enter a string: "))
       :to-equal "hello world"))))

;;; test-with-simulated-input.el ends here

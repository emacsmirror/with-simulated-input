# with-simulated-input

[![MELPA Stable](https://stable.melpa.org/packages/with-simulated-input-badge.svg)](https://stable.melpa.org/#/with-simulated-input)
[![CI Status](https://github.com/DarwinAwardWinner/with-simulated-input/actions/workflows/test.yml/badge.svg)](https://github.com/DarwinAwardWinner/with-simulated-input/actions/workflows/test.yml)
[![Coverage Status](https://coveralls.io/repos/github/DarwinAwardWinner/with-simulated-input/badge.svg?branch=master)](https://coveralls.io/github/DarwinAwardWinner/with-simulated-input?branch=master)

This package provides an Emacs Lisp macro, `with-simulated-input`,
which evaluates one or more forms while simulating a sequence of input
events for those forms to read. The result is the same as if you had
evaluated the forms and then manually typed in the same input. This
macro is useful for non-interactive testing of normally interactive
commands and functions, such as `completing-read`.

For example:

```elisp
(with-simulated-input
    "hello SPC world RET"
  (read-string "Say hello to the world: "))
```

This would return the string `"hello world"`.

## Running code during input

Sometimes you need to simulate an interaction that is difficult or
impossible to express as a sequence of keys. In this case, you can
pass a list of "inputs" instead of a single string. Any string in this
list will be treated as a key sequence, and any other form will be
treated as Emacs Lisp code and evaluated at that point during the
simulated interaction. For example, we can use Emacs Lisp code to
enter "world" after entering "hello" via key sequence:

```elisp
(let ((thing-to-greet "world"))
  (with-simulated-input
      ("hello SPC" (insert thing-to-greet) "RET")
    (read-string "Say hello: ")))
```

Note 1: The return values of any forms in the input list are ignored.
Only the side effects matter. In this case, the side effect of
`insert` is to insert "world" into the minibuffer.

Note 2: Previous versions of `with-simulated-input` attempted to
evalaute KEYS normally despite being a macro, so a quote was required
in front of KEYS if it was a list. This is no longer the case as of
version 3.0.

## Simulating idleness

Some interactive functions rely on idle timers to do their work, so
you might need a way to simulate idleness. For that, there is the
`wsi-simulate-idle-time` function. For example, the following code
will return `"hello world"`.

```elisp
;; Insert "world" after 500 seconds
(run-with-idle-timer 500 nil 'insert "world")
(with-simulated-input
    ;; Type "hello ", then "wait" 501 seconds, then type "RET"
    ("hello SPC" (wsi-simulate-idle-time 501) "RET")
  (read-string "Enter a string: "))
```

Note that the example code above only *pretends* to be idle for 501
seconds. It actually runs immediately.

## Running the tests

This package comes with a test suite. If you want to run it yourself,
first install the [Eldev](https://github.com/doublep/eldev), then use
`eldev test` to run the tests. Please run this test suite before
submitting any pull requests, and note in the pull request whether any
of the tests fail.

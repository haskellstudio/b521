#lang racket
;; Written for Spring 2013 by Andre Kuhlenschmidt and Jason Hemann

#| The underlying principles of the autograding framework is simple. 
We use the rackunit unit testing framework that comes with the racket
distrobution. We have define a set of calls that take a test-suite.
and executes the test-suite with eval rebound to a sandboxed evaluator
that provides racket and the file being tested. Disk access should be
limited to those files and time and space are limited by the parameters
time-for-eval and space-for-eval. 
|#

(require rackunit rackunit/text-ui racket/sandbox)
(provide test-file)

#|
 Test File is the minimum requirement for being able to understand
 our the autograder. test-file is a function that when invoked with
 no arguments will search will the current directory for the file 
 named a1.rkt and run the test suite with that file.
 If a single argument is provided that argument must be the relative or
 absolute path to the file containing the definitions for the assignment.
|#

(define test-file
  (lambda (#:file-name (file "./a4.rkt")
	   #:sec-of-eval (sec 5)
	   #:mb-of-eval (mb 5))
    (parameterize ((read-accept-reader #t)
                   (read-accept-lang #t))
      (let ((sandboxed-eval
             (make-module-evaluator (read (open-input-file file))
                                    #:allow-for-require '(C311/pmatch))))
        (set-eval-limits sandboxed-eval sec mb)
        (parameterize ((current-eval sandboxed-eval)
	               (error-print-context-length 0))
          (run-tests tests))))))

#|
  A tests is the name of the test-suite that is run by a call to test-file.
The test suite is a type that is define in the rackunit module. I will give
some examples of how test might be structured. If furthure documentation is
require feel free to browse the rackunit documentation at the following address.
http://docs.racket-lang.org/rackunit/?q=rackunit
|#
    
(define tests
  (test-suite "a4"
    (test-suite "value-of/RI-closures/fn-reps"
      (test-equal-if-defined value-of-fn
        ((value-of-fn 
                '((lambda (x) (if (zero? x) 
                                  12 
                                  47)) 
                   0) 
                (empty-env))
              12)    
        ((value-of-fn
          '(let ([y (* 3 4)])
             ((lambda (x) (* x y)) (sub1 6)))
          (empty-env))
         60)
        ((value-of-fn
          '(let ([x (* 2 3)])
             (let ([y (sub1 x)])
               (* x y)))
          (empty-env))
         30)
        ((value-of-fn
          '(let ([x (* 2 3)])
             (let ([x (sub1 x)])
               (* x x)))
          (empty-env))
         25)))
    (test-suite "value-of/RI-closures/ds-reps"
      (test-equal-if-defined value-of-ds
        ((value-of-ds
          '((lambda (x) (if (zero? x) 
        		    12 
        		    47)) 
            0) 
          (empty-env))
         12)    
        ((value-of-ds
          '(let ([y (* 3 4)])
             ((lambda (x) (* x y)) (sub1 6)))
          (empty-env))
         60)
        ((value-of-ds
          '(let ([x (* 2 3)])
             (let ([y (sub1 x)])
               (* x y)))
          (empty-env))
         30)
        ((value-of-ds
          '(let ([x (* 2 3)])
             (let ([x (sub1 x)])
               (* x x)))
          (empty-env))
         25)))
    (test-suite "value-of-scopes"
      (test-equal-if-defined value-of-scopes
        ((value-of-scopes '(let ([x 2])
        		   (let ([f (lambda (e) x)])
        		     (let ([x 5])
        		       (f 0)))) (empty-env))
         2)
        ((value-of-scopes '(let ([x 2])
        		   (let ([f (d-lambda (e) x)])
        		     (let ([x 5])
        		       (f 0)))) (empty-env))
         5)
        ((value-of-scopes
          '(let
               ([l (cons 1 (cons 2 (cons 3 '())))])
             ((map (lambda (e) (cons e l))) l))
          (extend-env
           'map
           (value-of-scopes
            '(let ([map (lambda (map)
        		  (lambda (f)
        		    (lambda (l)
        		      (if (null? l) '()
        			  (cons (f (car l)) (((map map) f) (cdr l)))))))])
               (map map)) (empty-env))
           (empty-env)))
         '((1 1 2 3) (2 1 2 3) (3 1 2 3)))
        ((value-of-scopes
          '(let
               ([l (cons 1 (cons 2 (cons 3 '())))])
             ((map (d-lambda (e) (cons e l))) l))
          (extend-env
           'map
           (value-of-scopes
            '(let ([map (lambda (map)
        		  (lambda (f)
        		    (lambda (l)
        		      (if (null? l) '()
        			  (cons (f (car l)) (((map map) f) (cdr l)))))))])
               (map map)) (empty-env))
           (empty-env)))
         '((1 1 2 3) (2 2 3) (3 3)))
        ;; Notice the behavior of let in this next example.
        ;; we get letrec for free. (This is not a good thing.)
        ((value-of-scopes
          '(let
               ([map (d-lambda (f)
        		       (d-lambda (l)
        				 (if (null? l) '()
        				     (cons (f (car l)) ((map f) (cdr l))))))])
             (let ([f (d-lambda (e) (cons e l))])
               ((map f) (cons 1 (cons 2 (cons 3 '()))))))
          (empty-env))
         '((1 1 2 3) (2 2 3) (3 3)))))
    (test-suite "value-of-ri"
      (test-equal-if-defined "value-of-ri"
        (((value-of-ri empty-env-fn extend-env-fn apply-env-fn closure-fn-ri apply-closure-fn-ri) '((lambda (x) x) 5))
         5)
        (((value-of-ri empty-env-ds extend-env-ds apply-env-ds closure-ds-ri apply-closure-ds-ri) '((lambda (x) x) 5))
         5)
        (((value-of-ri empty-env-fn extend-env-fn apply-env-fn closure-ds-ri apply-closure-ds-ri) '((lambda (x) x) 5))
         5)
        (((value-of-ri empty-env-ds extend-env-ds apply-env-ds closure-fn-ri apply-closure-fn-ri) '((lambda (x) x) 5))
         5)))))


(define-syntax test-if-defined
  (syntax-rules ()
    ((_ sym tests ...)
     (test-case (format "~a undefined" 'sym)
                (check-not-false (lambda () (eval 'sym)))
                tests ...))))

(define-syntax test-equal-if-defined
  (syntax-rules ()
    ((_ ident (expr val) ...)
      (let ((n 1))
        (test-case (format "~a: undefined" 'ident)
                   (check-not-exn (lambda () (eval 'ident)))
                   (test-case (format "~a: ~a" 'ident n)
                              (with-check-info 
                               (('tested 'expr))
                               (set! n (add1 n))
                               (check equal? (eval 'expr) val))) ...)))))

(define-syntax ifdef-suite
  (syntax-rules ()
    ((_ ident (expr val) ...)
     (let ((n 1))
       (test-suite (~a 'ident)
        (test-case "undefined"
         (check-not-exn (lambda () (eval 'ident)))
         (test-case (~a n)
          (with-check-info (('tested 'expr))
           (set! n (add1 n))
           (check equal? (eval 'expr) val))) ...))))))


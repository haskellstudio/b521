#lang racket

(require "parenthec.rkt")
(require C311/pmatch)

(define-union exp
  (const n)
  (var v)
  (if test conseq alt)
  (mult rand1 rand2)
  (sub1 rand)
  (zero rand)
  (capture body)
  (return vexp kexp)
  (let vexp body)
  (lambda body)
  (app rator rand))

(define-union cont
  (empty-k jumpout)
  (if-k conseq env alt k)
  (inner-mult-k n1 k)
  (outer-mult-k rand2 env k)
  (sub1-k k)
  (zero-k k)
  (inner-return-k kexp^)
  (outer-return-k vexp env)
  (let-k body env k)
  (inner-app-k rator^ k)
  (outer-app-k rand env k))

(define-registers
  c-reg
  a-reg
  k-reg
  env-reg
  num-reg
  v-reg
  expr-reg)

(define-program-counter pc)

(define-label apply-k
  (union-case k-reg cont
              ((empty-k jumpout) (dismount-trampoline jumpout))
              ((if-k conseq env alt k) (if v-reg
                                           (begin
                                             (set! expr-reg conseq)
                                             (set! env-reg env)
                                             (set! k-reg k)
                                             (set! pc value-of))
                                           (begin
                                             (set! expr-reg alt)
                                             (set! env-reg env)
                                             (set! k-reg k)
                                             (set! pc value-of))))
              ((inner-mult-k n1 k) (begin
                                     (set! v-reg (* n1 v-reg))
                                     (set! k-reg k)
                                     (set! pc apply-k)))
              ((outer-mult-k rand2 env k) (begin
                                            (set! k-reg (cont_inner-mult-k v-reg k))
                                            (set! expr-reg rand2)
                                            (set! env-reg env)
                                            (set! pc value-of)))
              ((sub1-k k) (begin
                            (set! v-reg (- v-reg 1))
                            (set! k-reg k)
                            (set! pc apply-k)))
              ((zero-k k) (begin
                            (set! v-reg (zero? v-reg))
                            (set! k-reg k)
                            (set! pc apply-k)))
              ((inner-return-k kexp^) (begin
                                        (set! k-reg kexp^)
                                        (set! pc apply-k)))
              ((outer-return-k vexp env) (begin
                                           (set! k-reg (cont_inner-return-k v-reg))
                                           (set! expr-reg vexp)
                                           (set! env-reg env)
                                           (set! pc value-of)))
              ((let-k body env k) (begin
                                    (set! env-reg (envr_extend v-reg env))
                                    (set! expr-reg body)
                                    (set! k-reg k)
                                    (set! pc value-of)))
              ((inner-app-k rator^ k) (begin
                                        (set! c-reg rator^)
                                        (set! a-reg v-reg)
                                        (set! k-reg k)
                                        (set! pc apply-closure)))
              ((outer-app-k rand env k) (begin
                                          (set! k-reg (cont_inner-app-k v-reg k))
                                          (set! expr-reg rand)
                                          (set! env-reg env)
                                          (set! pc value-of)))))

(define-label value-of
  ;; expr env k
  (union-case expr-reg exp
              [(const n) (begin
                           (set! v-reg n)
                           (set! pc apply-k))]
              [(var v) (begin
                         (set! num-reg v)
                         (set! pc apply-env))]
              [(if test conseq alt)
               (begin
                 (set! expr-reg test)
                 (set! k-reg (cont_if-k conseq env-reg alt k-reg))
                 (set! pc value-of))]
              [(mult rand1 rand2) (begin
                                    (set! k-reg (cont_outer-mult-k rand2 env-reg k-reg))
                                    (set! expr-reg rand1)
                                    (set! pc value-of))]
              [(sub1 rand) (begin
                             (set! k-reg (cont_sub1-k k-reg))
                             (set! expr-reg rand)
                             (set! pc value-of))]
              [(zero rand) (begin
                             (set! k-reg (cont_zero-k k-reg))
                             (set! expr-reg rand)
                             (set! pc value-of))]
              [(capture body)
               (begin
                 (set! expr-reg body)
                 (set! env-reg (envr_extend k-reg env-reg))
                 (set! pc value-of))]
              [(return vexp kexp)
               (begin
                 (set! expr-reg kexp)
                 (set! k-reg (cont_outer-return-k vexp env-reg))
                 (set! pc value-of))]
              [(let vexp body)
               (begin
                 (set! expr-reg vexp)
                 (set! k-reg (cont_let-k body env-reg k-reg))
                 (set! pc value-of))]
              [(lambda body) (begin
                               (set! v-reg (clos_closure body env-reg))
                               (set! pc apply-k))]
              [(app rator rand)
               (begin
                 (set! expr-reg rator)
                 (set! k-reg (cont_outer-app-k rand env-reg k-reg))
                 (set! pc value-of))]))

(define-union envr
  (empty)
  (extend arg env))

(define-label apply-env
  ;; env num k
  (union-case env-reg envr
              [(empty) (begin
                         (set! v-reg (error 'env "unbound variable"))
                         (set! pc apply-k))]
              [(extend arg env)
               (if (zero? num-reg)
                   (begin
                     (set! v-reg arg)
                     (set! pc apply-k))
                   (begin
                     (set! num-reg (sub1 num-reg))
                     (set! env-reg env)
                     (set! pc apply-env)))]))

(define-union clos
  (closure code env))

(define-label apply-closure
  (union-case c-reg clos
              [(closure code env)
               (begin
                 (set! expr-reg code)
                 (set! env-reg (envr_extend a-reg env))
                 (set! pc value-of))]))

(define-label main
  (begin
    (set! env-reg (envr_empty))
    (set! expr-reg (exp_app
                    (exp_app
                     (exp_lambda (exp_lambda (exp_var 1)))
                     (exp_const 5))
                    (exp_const 6)))
    (set! pc value-of)
    (mount-trampoline cont_empty-k k-reg pc)
    (pretty-print v-reg)
    (set! env-reg (envr_empty))
    (set! expr-reg (exp_app
                    (exp_lambda
                     (exp_app
                      (exp_app (exp_var 0) (exp_var 0))
                      (exp_const 5)))
                    (exp_lambda
                     (exp_lambda
                      (exp_if (exp_zero (exp_var 0))
                              (exp_const 1)
                              (exp_mult (exp_var 0)
                                        (exp_app
                                         (exp_app (exp_var 1) (exp_var 1))
                                         (exp_sub1 (exp_var 0)))))))))
    (set! pc value-of)
    (mount-trampoline cont_empty-k k-reg pc)
    (pretty-print v-reg)
    (set! expr-reg (exp_mult (exp_const 2)
                             (exp_capture
                              (exp_mult (exp_const 5)
                                        (exp_return (exp_mult (exp_const 2) (exp_const 6))
                                                    (exp_var 0))))))
    (set! env-reg (envr_empty))
    (set! pc value-of)
    (mount-trampoline cont_empty-k k-reg pc)
    (pretty-print v-reg)
    (set! env-reg (envr_empty))
    (set! expr-reg (exp_let
                    (exp_lambda
                     (exp_lambda
                      (exp_if
                       (exp_zero (exp_var 0))
                       (exp_const 1)
                       (exp_mult
                        (exp_var 0)
                        (exp_app
                         (exp_app (exp_var 1) (exp_var 1))
                         (exp_sub1 (exp_var 0)))))))
                    (exp_app (exp_app (exp_var 0) (exp_var 0)) (exp_const 5))))
    (set! pc value-of)
    (mount-trampoline cont_empty-k k-reg pc)
    (pretty-print v-reg)))

(main)

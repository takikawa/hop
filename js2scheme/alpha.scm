;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/js2scheme/alpha.scm                 */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Wed Jan 20 14:34:39 2016                          */
;*    Last change :  Fri Jul 22 15:53:02 2022 (serrano)                */
;*    Copyright   :  2016-22 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    AST Alpha conversion                                             */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __js2scheme_alpha

   (import __js2scheme_ast
	   __js2scheme_dump
	   __js2scheme_compile
	   __js2scheme_stage
	   __js2scheme_syntax
	   __js2scheme_utils)

   (static (class AlphaInfo
	      %oinfo
	      new)
	   (class TargetInfo
	      new))

   (export (j2s-alpha::J2SNode node::J2SNode ::pair-nil ::pair-nil)))

;*---------------------------------------------------------------------*/
;*    j2s-alpha ...                                                    */
;*---------------------------------------------------------------------*/
(define (j2s-alpha node olds news)
   (with-trace 'inline (format "j2s-alpha [~a]" (typeof node))
      (trace-item "node=" (j2s->sexp node))
      (trace-item "olds=" (map j2s->sexp olds))
      (trace-item "new=" (map j2s->sexp news))
      (j2s-alpha/proc node olds news alpha)))

;*---------------------------------------------------------------------*/
;*    j2s-alpha/proc ...                                               */
;*---------------------------------------------------------------------*/
(define (j2s-alpha/proc node olds news proc::procedure)
   (for-each (lambda (old new)
		(cond
		   ((isa? old J2SDecl)
		    (with-access::J2SDecl old (%info)
		       (set! %info
			  (instantiate::AlphaInfo
			     (new new)
			     (%oinfo %info)))))
		   ((and (isa? old J2SFun) (isa? new J2SFun))
		    (with-access::J2SFun old (%info)
		       (set! %info
			  (instantiate::AlphaInfo
			     (new new)
			     (%oinfo %info)))))
		   (else
		    (error "j2s-alpha/proc" "Illegal expression"
		       (j2s->sexp old)))))
      olds news)
   (let ((newbody (proc node)))
      (for-each (lambda (old new)
		   (when (or (isa? old J2SDecl)
			     (and (isa? old J2SFun) (isa? new J2SFun)))
		      (with-access::J2SNode old (%info)
			 (with-access::AlphaInfo %info (%oinfo)
			    (set! %info %oinfo)))))
	 olds news)
      newbody))

;*---------------------------------------------------------------------*/
;*    j2s->list ::AlphaInfo ...                                        */
;*---------------------------------------------------------------------*/
(define-method (j2s->list o::AlphaInfo stack)
   (with-access::AlphaInfo o (new)
      (if (isa? new J2SDecl)
	  (with-access::J2SDecl new (id)
	     (format "<AlphaInfo ~a>" id))
	  (format "<AlphaInfo ~a>" (typeof new)))))

;*---------------------------------------------------------------------*/
;*    alpha ::obj ...                                                  */
;*---------------------------------------------------------------------*/
(define-generic (alpha this::obj)
   (if (pair? this)
       (map alpha this)
       this))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SNode ...                                              */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SNode)
   (with-trace 'inline (format "alpha::~a" (typeof this))
      (with-access::J2SNode this (loc)
	 (let* ((clazz (object-class this))
		(ctor (class-constructor clazz))
		(inst ((class-allocator clazz)))
		(fields (class-all-fields clazz)))
	    ;; instance fields
	    (let loop ((i (-fx (vector-length fields) 1)))
	       (when (>=fx i 0)
		  (let* ((f (vector-ref-ur fields i))
			 (v ((class-field-accessor f) this))
			 (fi (class-field-info f))
			 (nv (cond
				((and (pair? fi) (member "notraverse" fi)) v)
				((pair? v) (map alpha v))
				(else (alpha v)))))
		     ((class-field-mutator f) inst nv)
		     (loop (-fx i 1)))))
	    ;; constructor
	    (when (procedure? ctor) (ctor inst))
	    inst))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SProgram ...                                           */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SProgram)
   (with-access::J2SProgram this (nodes decls)
      (set! decls (map (lambda (old)
			  (let ((nd (with-access::J2SDecl old (%info id)
				       (if (isa? %info AlphaInfo)
					   (with-access::AlphaInfo %info (new)
					      (if (isa? new J2SDecl)
						  new
						  old))
					   old))))
			     (if (isa? nd J2SDeclInit)
				 (with-access::J2SDeclInit nd (val)
				    (set! val (alpha val))))
			     nd))
		     decls))
      (set! nodes (map alpha nodes))
      this))
	 
;*---------------------------------------------------------------------*/
;*    alpha/targetinfo ...                                             */
;*---------------------------------------------------------------------*/
(define (alpha/targetinfo this::J2SNode)
   (with-access::J2SNode this (%info)
      (let* ((clazz (object-class this))
	     (ctor (class-constructor clazz))
	     (inst ((class-allocator clazz)))
	     (fields (class-all-fields clazz))
	     (oinfo %info))
	 (set! %info (instantiate::TargetInfo (new inst)))
	 ;; instance fields
	 (let loop ((i (-fx (vector-length fields) 1)))
	    (when (>=fx i 0)
	       (let* ((f (vector-ref-ur fields i))
		      (v ((class-field-accessor f) this))
		      (fi (class-field-info f))
		      (nv (if (and (pair? fi) (member "notraverse" fi))
			      v
			      (alpha v))))
		  ((class-field-mutator f) inst nv)
		  (loop (-fx i 1)))))
	 ;; constructor
	 (when (procedure? ctor) ctor inst)
	 (set! %info oinfo)
	 inst)))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SDecl ...                                              */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SDecl)
   (with-trace 'inline "alpha::J2SDecl"
      (trace-item "this=" (j2s->sexp this))
      (with-access::J2SDecl this (%info id scope)
	 (if (isa? %info AlphaInfo)
	     (with-access::AlphaInfo %info (new)
		(if (isa? new J2SDecl)
		    (begin
		       (when (isa? new J2SDeclInit)
			  (with-access::J2SDeclInit new (val)
			     (set! val (alpha val))))
		       new)
		    this))
	     (let* ((clazz (object-class this))
		    (ctor (class-constructor clazz))
		    (inst ((class-allocator clazz)))
		    (fields (class-all-fields clazz)))
		(unless (or (isa? %info AlphaInfo) (eq? scope 'unbound))
		   (tprint "*** ERROR, alpha: should not be here "
		      (j2s->sexp this) " scope=" scope)
		   (set! %info
		      (instantiate::AlphaInfo
			 (%oinfo %info)
			 (new inst))))
		;; instance fields
		(let loop ((i (-fx (vector-length fields) 1)))
		   (when (>=fx i 0)
		      (let* ((f (vector-ref-ur fields i))
			     (v ((class-field-accessor f) this))
			     (fi (class-field-info f))
			     (nv (cond
				    ((and (pair? fi) (member "notraverse" fi)) v)
				    ((pair? v) (map alpha v))
				    (else (alpha v)))))
			 ((class-field-mutator f) inst nv)
			 (loop (-fx i 1)))))
		;; decl key
		(with-access::J2SDecl inst (key)
		   (set! key (ast-decl-key)))
		;; constructor
		(when (procedure? ctor) ctor inst)
		inst)))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SLoop ...                                              */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SLoop)
   (alpha/targetinfo this))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SSwitch ...                                            */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SSwitch)
   (alpha/targetinfo this))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SBindExit ...                                          */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SBindExit)
   (let ((new (duplicate::J2SBindExit this)))
      (with-access::J2SBindExit this (%info)
	 (set! %info
	    (instantiate::AlphaInfo
	       (new new)
	       (%oinfo %info)))
	 (with-access::J2SBindExit new (stmt)
	    (set! stmt (alpha stmt))
	    (with-access::AlphaInfo %info (%oinfo)
	       (set! %info %oinfo))
	    new))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SReturn ...                                            */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SReturn)
   (with-access::J2SReturn this (expr from)
      (if (isa? from J2SExpr)
	  (with-access::J2SExpr from (%info)
	     (if (isa? %info AlphaInfo)
		 (with-access::AlphaInfo %info (new)
		    (duplicate::J2SReturn this
		       (expr (alpha expr))
		       (from new)))
		 (duplicate::J2SReturn this
		    (expr (alpha expr)))))
	  (duplicate::J2SReturn this
	     (expr (alpha expr))))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SBreak ...                                             */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SBreak)
   (with-access::J2SBreak this (target)
      (if target
	  (with-access::J2SStmt target (%info)
	     (duplicate::J2SBreak this
		(target (if (isa? %info TargetInfo)
			    (with-access::TargetInfo %info (new)
			       new)
			    target))))
	  (duplicate::J2SBreak this))))
      
;*---------------------------------------------------------------------*/
;*    alpha ::J2SContinue ...                                          */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SContinue)
   (with-access::J2SContinue this (target)
      (with-access::J2SStmt target (%info)
	 (duplicate::J2SContinue this
	    (target (if (isa? %info TargetInfo)
			(with-access::TargetInfo %info (new)
			   new)
			target))))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SRef ...                                               */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SRef)
   
   (define (min-type x y)
      (cond
	 ((memq x '(int32 uint32 int53 index indexof)) x)
	 ((memq y '(int32 uint32 int53 index indexof)) y)
	 ((not (memq y '(any unknown))) y)
	 (else x)))
   
   (with-access::J2SRef this (decl type loc)
      (with-access::J2SDecl decl (%info id)
	 (if (isa? %info AlphaInfo)
	     (with-access::AlphaInfo %info (new)
		(cond
		   ((isa? new J2SDecl)
		    (with-access::J2SDecl new (vtype)
		       (duplicate::J2SRef this
			  (type (min-type type vtype))
			  (decl new))))
		   ((isa? new J2SExpr)
		    (if (eq? new this)
			this
			(alpha new)))
		   (else
		    (error "alpha"
		       (format "ref: new must be a decl or an expr (~a)"
			  (typeof new))
		       new))))
	     (duplicate::J2SRef this)))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SThis ...                                              */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SThis)
   (with-access::J2SThis this (decl type)
      (with-access::J2SDecl decl (%info)
	 (if (isa? %info AlphaInfo)
	     (with-access::AlphaInfo %info (new)
		(cond
		   ((isa? new J2SThis)
		    (with-access::J2SDecl new (vtype)
		       (duplicate::J2SThis this
			  (type (min-type type vtype))
			  (decl new))))
		   ((isa? new J2SDecl)
		    (with-access::J2SDecl new (vtype)
		       (duplicate::J2SThis this
			  (type (min-type type vtype))
			  (decl new))))
		   ((isa? new J2SExpr)
		    (alpha new))
		   (else
		    (error "alpha"
		       (format "this: new must be a decl or an expr (~a)"
			  (typeof new))
		       new))))
	     (duplicate::J2SThis this)))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SSuper ...                                             */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SSuper)
   (with-access::J2SSuper this (decl type)
      (with-access::J2SDecl decl (%info)
	 (if (isa? %info AlphaInfo)
	     (with-access::AlphaInfo %info (new)
		(cond
		   ((isa? new J2SSuper)
		    (with-access::J2SDecl new (vtype)
		       (duplicate::J2SSuper this
			  (type (min-type type vtype))
			  (decl new))))
		   ((isa? new J2SDecl)
		    (with-access::J2SDecl new (vtype)
		       (duplicate::J2SSuper this
			  (type (min-type type vtype))
			  (decl new))))
		   ((isa? new J2SExpr)
		    (alpha new))
		   (else
		    (error "alpha"
		       (format "super: new must be a decl or an expr (~a)"
			  (typeof new))
		       new))))
	     (duplicate::J2SSuper this)))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SCacheCheck ...                                        */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SCacheCheck)
   (with-access::J2SCacheCheck this (owner obj)
      (duplicate::J2SCacheCheck this
	 (obj (alpha obj))
	 (owner (if (isa? owner J2SRef) (alpha owner) owner)))))
   
;*---------------------------------------------------------------------*/
;*    alpha ::J2SFun ...                                               */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SFun)
   
   (define (alpha-fun/decl this)
      (with-access::J2SFun this (thisp params body method decl name)
	 (let* ((ndecl (duplicate::J2SDeclFun decl
			  (key (ast-decl-key))))
		(nthisp (when thisp (j2sdecl-duplicate thisp)))
		(nparams (map j2sdecl-duplicate params))
		(nfun (duplicate::J2SFun this
			 (decl ndecl)
			 (params nparams))))
	    (with-access::J2SFun nfun (body method)
	       (with-access::J2SDeclFun ndecl (val)
		  (set! val nfun))
	       (when method
		  (set! method
		     (j2s-alpha method
			(cons* decl this thisp params)
			(cons* ndecl nfun nthisp nparams))))
	       (set! body
		  (if thisp
		      (j2s-alpha body
			 (cons* decl this thisp params)
			 (cons* ndecl nfun nthisp nparams))
		      (j2s-alpha body
			 (cons* decl this params)
			 (cons* ndecl nfun nparams)))))
	    nfun)))
   
   (define (alpha-fun/w-decl this)
      (with-access::J2SFun this (params body method name thisp)
	 (let* ((nparams (map j2sdecl-duplicate params))
		(nthisp (when thisp (j2sdecl-duplicate thisp)))
		(nfun (duplicate::J2SFun this
			 (params nparams)
			 (thisp (when thisp nthisp)))))
	    (with-access::J2SFun nfun (body method)
	       (when method
		  (set! method
		     (j2s-alpha method
			(cons thisp params)
			(cons nthisp nparams))))
	       (set! body
		  (if thisp
		      (j2s-alpha body
			 (cons thisp params)
			 (cons nthisp nparams))
		      (j2s-alpha body
			 params
			 nparams))))
	    nfun)))
   
   (with-access::J2SFun this (decl)
      (if (isa? decl J2SDeclFun)
	  (alpha-fun/decl this)
	  (alpha-fun/w-decl this))))
<
;*---------------------------------------------------------------------*/
;*    alpha ::J2SMethod ...                                            */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SMethod)
   (with-access::J2SMethod this (function method)
      (let ((nmethod (alpha method))
	    (nfunction (alpha function)))
	 (with-access::J2SFun nfunction (method)
	    (set! method nmethod))
	 (duplicate::J2SMethod this
	    (function nfunction)
	    (method nmethod)))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SSvc ...                                               */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SSvc)
   (with-access::J2SSvc this (params body init)
      (let ((nparams (map j2sdecl-duplicate params)))
	 (set! init (alpha init))
	 (let ((nsvc (duplicate::J2SSvc this
			(params nparams)
			(body body))))
	    (with-access::J2SSvc nsvc (body)
	       (set! body
		  (j2s-alpha body (cons this params) (cons nsvc nparams))))
	    nsvc))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SArrow ...                                             */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SArrow)
   (with-access::J2SArrow this (params body)
      (let* ((nparams (map j2sdecl-duplicate params))
	     (narrow (duplicate::J2SArrow this
			(params nparams)
			(body body))))
	 (with-access::J2SArrow narrow (body)
	    (set! body
	       (j2s-alpha body (cons this params) (cons narrow nparams))))
	 narrow)))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SCatch ...                                             */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SCatch)
   (with-access::J2SCatch this (body param)
      (let ((nparam (j2sdecl-duplicate param)))
	 (duplicate::J2SCatch this
	    (param nparam)
	    (body (j2s-alpha body (list param) (list nparam)))))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SSeq ...                                               */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SSeq)
   
   (define (get-decls d)
      (cond
	 ((isa? d J2SDecl) (list d))
	 ((isa? d J2SVarDecls) (with-access::J2SVarDecls d (decls) decls))
	 (else '())))

   (with-trace 'inline "alpha::J2SSeq"
      (trace-item "this=" (j2s->sexp this))
      (with-access::J2SSeq this (nodes %info)
	 (let* ((decls (append-map get-decls nodes))
		(ndecls (map j2sdecl-duplicate decls)))
	    (trace-item "decls=" (map j2s->sexp decls))
	    (if (pair? decls)
		(let ((nnodes (map (lambda (n)
				     (j2s-alpha n decls ndecls))
				 nodes)))
		   (trace-item "ndecls=" (map j2s->sexp decls))
		   (if (isa? this J2SBlock)
		       (duplicate::J2SBlock this (nodes nnodes))
		       (duplicate::J2SSeq this (nodes nnodes))))
		(call-next-method))))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SFor ...                                               */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SFor)
   (with-trace 'inline "alpha::J2SFor"
      (trace-item "this=" (j2s->sexp this))
      (with-access::J2SFor this (init test incr body)
	 (if (isa? init J2SVarDecls)
	     (with-access::J2SVarDecls init (decls)
		(let ((ndecls (map j2sdecl-duplicate decls)))
		   (set! init (j2s-alpha init decls ndecls))
		   (set! test (j2s-alpha test decls ndecls))
		   (set! body (j2s-alpha body decls ndecls))
		   this))
	     (call-next-method)))))
	 
;*---------------------------------------------------------------------*/
;*    alpha ::J2SForIn ...                                             */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SForIn)
   (with-trace 'inline "alpha::J2SForIn"
      (trace-item "this=" (j2s->sexp this))
      (with-access::J2SForIn this (lhs obj body)
	 (if (isa? lhs J2SVarDecls)
	     (with-access::J2SVarDecls lhs (decls)
		(let ((ndecls (map j2sdecl-duplicate decls)))
		   (set! obj (j2s-alpha obj decls ndecls))
		   (set! body (j2s-alpha body decls ndecls))
		   this))
	     (call-next-method)))))
	 
;*---------------------------------------------------------------------*/
;*    alpha ::J2SLetBlock ...                                          */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SLetBlock)
   (with-access::J2SLetBlock this (decls nodes)
      (let ((ndecls (map j2sdecl-duplicate decls)))
	 (for-each (lambda (d)
		      (when (isa? d J2SDeclInit)
			 (with-access::J2SDeclInit d (val)
			    (set! val (j2s-alpha val decls ndecls)))))
	    ndecls)
	 (duplicate::J2SLetBlock this
	    (decls ndecls)
	    (nodes (map (lambda (n) (j2s-alpha n decls ndecls)) nodes))))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SClass ...                                             */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SClass)
   (with-access::J2SClass this (decl name elements super)
      (when decl
	 (with-access::J2SDecl decl (%info)
	    (when (isa? %info AlphaInfo)
	       (with-access::AlphaInfo %info (new)
		  (when (isa? new J2SDecl)
		     (set! decl new))))))
      (set! super (alpha super))
      (set! elements (map alpha elements))
      this))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SClassElement ...                                      */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SClassElement)
   (with-access::J2SClassElement this (prop)
      ;; cannot create new class element because of private@J2SString
      (set! prop (alpha prop))
      this))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SKont ...                                              */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SKont)
   (with-access::J2SKont this (param exn body)
      (let ((nparam (j2sdecl-duplicate param))
	    (nexn (j2sdecl-duplicate exn)))
	 (duplicate::J2SKont this
	    (param nparam)
	    (exn nexn)
	    (body (j2s-alpha body (list param exn) (list nparam nexn)))))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SDConsumer ...                                         */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SDConsumer)
   (with-access::J2SDConsumer this (decl expr)
      (duplicate::J2SDConsumer this
	 (decl (j2sdecl-duplicate decl))
	 (expr (alpha expr)))))

;*---------------------------------------------------------------------*/
;*    alpha ::J2SDProducer ...                                         */
;*---------------------------------------------------------------------*/
(define-method (alpha this::J2SDProducer)
   (with-access::J2SDProducer this (decl expr)
      (duplicate::J2SDProducer this
	 (decl (j2sdecl-duplicate decl))
	 (expr (alpha expr)))))

;*---------------------------------------------------------------------*/
;*    j2sdecl-duplicate ...                                            */
;*---------------------------------------------------------------------*/
(define (j2sdecl-duplicate p::J2SDecl)
   (cond
      ((isa? p J2SDeclFunType)
       (duplicate::J2SDeclFunType p
	  (%info #unspecified)
	  (key (ast-decl-key))))
      ((isa? p J2SDeclFun)
       (duplicate::J2SDeclFun p
	  (%info #unspecified)
	  (key (ast-decl-key))))
      ((isa? p J2SDeclClass)
       (duplicate::J2SDeclClass p
	  (%info #unspecified)
	  (key (ast-decl-key))))
      ((isa? p J2SDeclInit)
       (duplicate::J2SDeclInit p
	  (%info #unspecified)
	  (key (ast-decl-key))))
      ((isa? p J2SDeclRest)
       (duplicate::J2SDeclRest p
	  (%info #unspecified)
	  (key (ast-decl-key))))
      ((isa? p J2SDeclArguments)
       (duplicate::J2SDeclArguments p
	  (%info #unspecified)
	  (key (ast-decl-key))))
      (else
       (duplicate::J2SDecl p
	  (%info #unspecified)
	  (key (ast-decl-key))))))


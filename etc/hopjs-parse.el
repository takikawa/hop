;*=====================================================================*/
;*    serrano/prgm/project/hop/3.2.x/etc/hopjs-parse.el                */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Thu Nov  1 07:14:59 2018                          */
;*    Last change :  Sun Nov 18 10:00:31 2018 (serrano)                */
;*    Copyright   :  2018 Manuel Serrano                               */
;*    -------------------------------------------------------------    */
;*    Hopjs JavaScript/HTML parser                                     */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The package                                                      */
;*---------------------------------------------------------------------*/
(provide 'hopjs-parse)
(require 'hopjs-macro)

;*---------------------------------------------------------------------*/
;*    hopjs-parse-tokens ...                                           */
;*---------------------------------------------------------------------*/
(defvar hopjs-parse-tokens '())

;*---------------------------------------------------------------------*/
;*    rx builder ...                                                   */
;*---------------------------------------------------------------------*/
(defun rxor (rx &rest rxs)
  (concat "\\(?:" rx
	  (apply 'concat (mapcar #'(lambda (x) (concat "\\|" x)) rxs))
	  "\\)"))

(defun rx* (rx) (concat rx "*"))

(defun rx? (rx) (concat rx "?"))

(defun rx: (a &rest rxs) (concat a (apply 'concat rxs)))

(defun rxq (rx) (regexp-quote rx))

;*---------------------------------------------------------------------*/
;*    JavaScript tokens                                                */
;*---------------------------------------------------------------------*/
(defconst hopjs-parse-regexps
  (let* ((unicode_char "[[:multibyte:]]")
	 (alpha+ "[[:alpha:][:multibyte:]]")
	 (alnum+ (rxor "[[:alnum:][:multibyte:]]"))
	 (id_part_sans "[[:nonascii:]]")
	 (id_part "[[:alnum:][:multibyte:][:nonascii:]$_]")
	 (id_start "[[:alpha:][:multibyte:][:nonascii:]$_]")
	 (id_start_u "[[:multibyte:][:alnum:][:nonascii:]$_]")
	 (letter "[[:alpha:][:nonascii:]]")
	 (tagid (rx: "[[:digit:]]*" "[[:alnum:]_]" (rx* "[[:alnum:]_.]*"))))
    (list
     ;; blank
     (cons "[ \t\n]+" 'blank)
     ;; line comments
     (cons "//[^\n]*" 'comment)
     ;; comments
     (cons "/[*]\\(?:[^*]\\|[*][^/]\\)*[*]+/" 'comment)
     ;; numbers
     (cons (rxor "\\(?:0[xo]\\)?[0-9]+\\>"
		 "[eE]?-?[0-9]+\\>"
		 "[+]?[0-9]+\\(?:[.][0-9]+\\)?\\>")
	   'number)
     ;; punctuation
     (cons (rxor "[{}()[.;,:?]" (rxq "]")) 'punct)
     ;; binop
     (cons (rxor "<" ">" (rxq "+") (rxq "-") (rxq "*") "%" "=" "|" "==" "==="
		 "<<" ">>" ">>>" "[&^]") 'binop)
     (cons (rxor "&&" "||") 'binop)
     (cons (rxor "<=" ">="  "!=" "!==" "[+*%^&-]=" "<<=" ">>=" ">>>=") '=)
     ;; prefix
     (cons (rxor (rx: (rxq "+") (rxq "+")) "--") 'prefix)
     ;; arrow
     (cons "=>" '=>)
     ;; dots
     (cons "[.][.][].]" 'dots)
     ;; strings
     (cons (rxor "\"\\([^\"\\]\\|\\\\.\\)*\"" "'[^']*'" "`[^`]*`") 'string)
     ;; tilde escape
     (cons "~{" 'tilde)
     ;; dollar escape
     (cons "[$]{" 'dollar)
     ;; ident
     (cons (rx: id_start (rx* id_part)) 'ident)
     ;; html-comment
     (cons "<!--\\(?:[^-]\\|-[^-]\\|--[^>]\\)[-]+->" 'html-comment)
     ;; otag
     (cons (rx: "<" tagid ">") 'otag)
     ;; ctag
     (cons (rx: "</" tagid ">") 'ctag)
     ;; ohtml
     (cons (rx: "\\(<" tagid "\\)[ \t\n]+" (rxor tagid "[$]{" ">")) 'ohtml)
     ;; chtml
     (cons "/>" 'chtml)
     ;; html
     (cons (rx: "<" tagid "/>") 'html)
     ;; end of comment
     (cons (rxq "*/") 'ecomment)
     )))

(defun foo (pos)
  (interactive "d")
  (message "XXXpos=%s" pos)
  (when (looking-at )
    (message "%s %s [%s]- %s %s [%s]" (match-beginning 0) (match-end 0)
	     (buffer-substring-no-properties
	      (match-beginning 0) (match-end 0))
	     (match-beginning 1) (match-end 1)
	     (buffer-substring-no-properties
	      (match-beginning 1) (match-end 1)))))

(defconst hopjs-parse-lexer
  (apply 'rxor (mapcar 'car hopjs-parse-regexps)))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-token ...                                            */
;*---------------------------------------------------------------------*/
(defsubst hopjs-parse-token (type b e) (vector type b e))
(defsubst hopjs-parse-tokenp (obj) (and (vector-p obj) (= (length obj) 3)))

(defsubst hopjs-parse-token-type (tok) (aref tok 0))
(defsubst hopjs-parse-token-beginning (tok) (aref tok 1))
(defsubst hopjs-parse-token-end (tok) (aref tok 2))

(defsubst hopjs-parse-token-string (tok)
  (if (eq (hopjs-parse-token-type tok) 'bof)
      "<BOF>"
    (buffer-substring-no-properties
     (hopjs-parse-token-beginning tok)
     (hopjs-parse-token-end tok))))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-goto-token ...                                       */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-goto-token (tok &optional shift)
  (goto-char (+ (or shift 0) (hopjs-parse-token-beginning tok))))

;*---------------------------------------------------------------------*/
;*    nullp                                                            */
;*---------------------------------------------------------------------*/
(defsubst nullp (o) (not (consp o)))

;*---------------------------------------------------------------------*/
;*    hopjs-regexp-to-token ...                                        */
;*---------------------------------------------------------------------*/
(defun hopjs-regexp-to-token (tok)
  (case (hopjs-parse-token-type tok)
    ((punct)
     (case (char-after (hopjs-parse-token-beginning tok))
       ((?,) (aset tok 0 'comma))
       ((?\;) (aset tok 0 'semicolon))
       ((?\.) (aset tok 0 'dot))
       ((?\() (aset tok 0 'lparen))
       ((?\)) (aset tok 0 'rparen))
       ((?\[) (aset tok 0 'lbracket))
       ((?\]) (aset tok 0 'rbracket))
       ((?\{) (aset tok 0 'lbrace))
       ((?\}) (aset tok 0 'rbrace))
       ((?\:) (aset tok 0 'colon))
       ((?\?) (aset tok 0 'qmark)))
     tok)
    ((ident)
     (let ((sym (intern (hopjs-parse-token-string tok))))
       (when (memq sym '(function function* service return try catch while if
				  var let const else new case switch for))
	 (aset tok 0 sym))
       tok))
    ((binop)
     (case (char-after (hopjs-parse-token-beginning tok))
       ((?=)
	(aset tok 0 '=))
       ((?>)
	(when (= (+ 1 (hopjs-parse-token-beginning tok))
		 (hopjs-parse-token-end tok))
	  (aset tok 0 '>))))
     tok)
    (t
     tok)))
    
;*---------------------------------------------------------------------*/
;*    looking-at-token ...                                             */
;*---------------------------------------------------------------------*/
(defun looking-at-token ()
  (when (looking-at hopjs-parse-lexer)
    (let ((b (match-beginning 0))
	  (e (match-end 0))
	  (token '())
	  (i 0)
	  (l hopjs-parse-regexps)
	  (end 0))
      (while (consp l)
	(when (and (looking-at (caar l)) (> (match-end 0) end))
	  (setq end (match-end 0))
	  (setq token
		(hopjs-regexp-to-token
		 (vector (cdar l) (match-beginning 0) (match-end 0)))))
	(setq i (+ i 1))
	(setq l (cdr l)))
      token)))
  
;*---------------------------------------------------------------------*/
;*    hopjs-parse-line ...                                             */
;*    -------------------------------------------------------------    */
;*    Returns the list of tokens found on the line                     */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-line (pos &optional rev)
  (interactive "d")
  (hopjs-no-debug 1 "hopjs-parse-line pos=%s" pos)
  (save-excursion
    (let ((tokens '()))
      (goto-char pos)
      (beginning-of-line)
      (while (< (point) pos)
	(let ((tok (looking-at-token)))
	  (cond
	   (tok
	    (hopjs-no-debug 0 "hopjs-parse-line pos=%s point=%s tok=%s"
			    pos (point) tok)
	    (if (eq (hopjs-parse-token-type tok) 'ohtml)
		;; ohtml must be split in two parts: the tag and the attr
		(progn
		  (goto-char (match-end 1))
		  (aset tok 2 (match-end 1))
		  (setq tokens (cons tok tokens)))
	      (progn
		(goto-char (hopjs-parse-token-end tok))
		(setq tokens (cons tok tokens)))))
	   ((looking-at "[^ \t\n;]+")
	    (let ((tok (hopjs-parse-token
			'text (match-beginning 0) (match-end 0))))
	      (setq tokens (cons tok tokens))
	      (goto-char (match-end 0))))
	   (t
	    (setq tokens
		  (cons (hopjs-parse-token 'blank (point) (point))
			tokens))
	    (forward-char 1)))))
      (let ((r (cond
		((nullp tokens) (list (hopjs-parse-token 'blank pos pos)))
		(rev (reverse tokens))
		(t tokens))))
	(hopjs-no-debug -1 "hopjs-parse-line pos=%s -> %s" pos r)
	r))))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-start ...                                            */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-start (pos)
  (cond
   ((and (consp hopjs-parse-tokens)
	 (= (hopjs-parse-token-end (car (last hopjs-parse-tokens))) pos))
    (setq hopjs-parse-tokens (last hopjs-parse-tokens)))
   (t
    (setq hopjs-parse-tokens '())
    (while (nullp hopjs-parse-tokens)
      (setq hopjs-parse-tokens (hopjs-parse-line pos))
      (when (nullp hopjs-parse-tokens)
	(if (= (point) (point-min))
	    (setq hopjs-parse-tokens (list (hopjs-parse-token 'bof 0 0)))
	  (progn
	    (forward-line -1)
	    (end-of-line)
	    (setq pos (point)))))))))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-push-token ...                                       */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-push-token (tok)
  (setq hopjs-parse-tokens (cons tok hopjs-parse-tokens))
  tok)

;*---------------------------------------------------------------------*/
;*    hopjs-parse-peek-token-blank ...                                 */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-peek-token-blank ()
  (hopjs-no-debug 1 "parse-peek-token-blank %s %s" (point) hopjs-parse-tokens)
  (cond
   ((nullp hopjs-parse-tokens)
    (hopjs-no-debug -1 "parse-peek-token-blank.1 %s BOF" (point))
    (hopjs-parse-token 'bof 0 0))
   ((nullp (cdr hopjs-parse-tokens))
    (let* ((tok (car hopjs-parse-tokens))
	   (b (hopjs-parse-token-beginning tok)))
      (hopjs-no-debug 0 "parse-peek-token-blank.1 %s tok=%s" (point) tok)
      (if (= b (point-min))
	  (setq hopjs-parse-tokens (list tok (hopjs-parse-token 'bof 0 0)))
	(setq hopjs-parse-tokens (cons tok (hopjs-parse-line (- b 1)))))
      (hopjs-no-debug -1 "parse-peek-token-blank.2 %s %s" (point) hopjs-parse-tokens)
      tok))
   (t
    (hopjs-no-debug -1 "parse-peek-token-blank.3 %s %s" (point) hopjs-parse-tokens)
    (car hopjs-parse-tokens))))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-peek-token ...                                       */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-peek-token ()
  (hopjs-no-debug 1 "hopjs-parse-peek-token %s" (point))
  (let ((tok (hopjs-parse-peek-token-blank)))
    (while (eq (hopjs-parse-token-type tok) 'blank)
      (setq hopjs-parse-tokens (cdr hopjs-parse-tokens))
      (setq tok (hopjs-parse-peek-token-blank)))
    (hopjs-no-debug -1 "hopjs-parse-peek-token %s -> %s"
		    (point) (car hopjs-parse-tokens))
    (car hopjs-parse-tokens)))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-consume-and-peek-token ...                           */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-consume-and-peek-token ()
  (hopjs-parse-consume-token-any)
  (hopjs-parse-peek-token))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-peek-token-type ...                                  */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-peek-token-type ()
  (hopjs-parse-token-type (hopjs-parse-peek-token)))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-peek-token-string ...                                */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-peek-token-string ()
  (hopjs-parse-token-string (hopjs-parse-peek-token)))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-consume-token-any ...                                */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-consume-token-any ()
  (while (eq (hopjs-parse-token-type (hopjs-parse-peek-token)) 'blank)
    (setq hopjs-parse-tokens (cdr hopjs-parse-tokens)))
  (let ((tok (car hopjs-parse-tokens)))
    (setq hopjs-parse-tokens (cdr hopjs-parse-tokens))
    tok))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-consume-tokens ...                                   */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-consume-tokens (lst)
  (letn loop ((tok (hopjs-parse-consume-token-any)))
	(if (memq (hopjs-parse-peek-token-type) lst)
	    (funcall loop (hopjs-parse-consume-token-any))
	  tok)))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-consume-token ...                                    */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-consume-token (key)
  (while (eq (hopjs-parse-token-type (hopjs-parse-peek-token)) 'blank)
    (setq hopjs-parse-tokens (cdr hopjs-parse-tokens)))
  (let ((tok (car hopjs-parse-tokens)))
    (when (eq (hopjs-parse-token-type tok) key)
      (setq hopjs-parse-tokens (cdr hopjs-parse-tokens))
      tok)))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-backward-sexp ...                                    */
;*    -------------------------------------------------------------    */
;*    Jump backward one expression, if possible, and restart parsing   */
;*    on the first token composing the jumped expression.              */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-backward-sexp ()
  (with-debug
   "hopjs-parse-backward-sexp point=%s" (point)
   (condition-case nil
       (progn
	 (backward-sexp 1)
	 (hopjs-debug 0 "hopjs-parse-backward-sexp starting new %s" (point))
	 (let ((pos (+ 1 (point))))
	   (hopjs-parse-start pos)
	   pos))
     (error '()))))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-args ...                                             */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-args (tok)
  (save-excursion
    (when (eq (hopjs-parse-token-type tok) 'rparen)
      (hopjs-parse-goto-token tok 1)
      (when (hopjs-parse-backward-sexp)
	(hopjs-parse-consume-and-peek-token)))))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-expr ...                                             */
;*    -------------------------------------------------------------    */
;*    This function parses a complete expression (from right to left)  */
;*    and returns the last expression token (that is, the last token   */
;*    composing the expression). This token is consumed.               */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-expr (tok)
  (with-debug
   "hopjs-parse-expr tok=%s [%s] peek=%s [%s]"
   tok (hopjs-parse-token-string tok)
   (hopjs-parse-peek-token)
   (hopjs-parse-peek-token-string)
   (let ((etok (hopjs-parse-expr-simple tok)))
     (when etok
       (case (hopjs-parse-peek-token-type)
	 ((dot)
	  (let ((dtok (hopjs-parse-consume-token-any)))
	    (hopjs-debug 0 "hopjs-parse-expr.ident.dot dtok=%s peek=%s same=%s"
			 dtok (hopjs-parse-peek-token)
			 (hopjs-parse-same-linep (hopjs-parse-peek-token) dtok))
	    (if (hopjs-parse-same-linep (hopjs-parse-peek-token) dtok)
		(or (hopjs-parse-expr (hopjs-parse-peek-token)) tok)
	      dtok)))
	 ((binop = >)
	  (hopjs-parse-expr (hopjs-parse-consume-token-any)))
	 ((new)
	  (hopjs-parse-consume-token-any))
	 ((colon)
	  ;; check for EXPR ? EXPR : EXPR 
	  (let* ((save hopjs-parse-tokens)
		 (ctok (hopjs-parse-consume-token-any))
		 (etok (hopjs-parse-expr ctok)))
	    (if etok
		(if (eq (hopjs-parse-peek-token-type) 'qmark)
		    (let ((qtok (hopjs-parse-consume-token-any)))
		      (hopjs-parse-expr qtok))
		  (progn
		    (setq hopjs-parse-tokens save)
		    tok))
	      (progn
		(setq hopjs-parse-tokens save)
		tok))))
	 (t etok))))))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-expr-simple ...                                      */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-expr-simple (tok)
  (with-debug
   "hopjs-parse-expr-simple tok=%s [%s] peek=%s [%s]"
   tok (hopjs-parse-token-string tok)
   (hopjs-parse-peek-token)
   (hopjs-parse-peek-token-string)
   (save-excursion
     (hopjs-parse-goto-token tok)
     (case (hopjs-parse-peek-token-type)
       ((rbracket)
	(goto-char (hopjs-parse-token-end tok))
	(hopjs-debug 0 "hopjs-parse-expr-simple.rbracket point=%s" (point))
	(if (hopjs-parse-backward-sexp)
	    (let ((tok (hopjs-parse-consume-and-peek-token))
		  (etok (hopjs-parse-expr-simple tok)))
	      (hopjs-debug 0 "hopjs-parse-expr-simple.rbracket %s [%s]" tok
			   (hopjs-parse-token-string tok))
	      (or etok tok))))
       ((new)
	(hopjs-parse-consume-token-any))
       ((ident)
	(let ((tok (hopjs-parse-consume-token-any)))
	  (hopjs-debug 0 "hopjs-parse-expr-simple.ident %s [%s] peek=%s"
		       tok
		       (hopjs-parse-token-string tok)
		       (hopjs-parse-peek-token-type))
	  (case (hopjs-parse-peek-token-type)
;* 	    ((dot)                                                     */
;* 	     (let ((dtok (hopjs-parse-consume-token-any)))             */
;* 	       (hopjs-debug 0 "hopjs-parse-expr-simple.ident.dot dtok=%s peek=%s same=%s" */
;* 			    dtok (hopjs-parse-peek-token)              */
;* 			    (hopjs-parse-same-linep (hopjs-parse-peek-token) dtok)) */
;* 	       (if (hopjs-parse-same-linep (hopjs-parse-peek-token) dtok) */
;* 		   (or (hopjs-parse-expr (hopjs-parse-peek-token)) tok) */
;* 		 dtok)))                                               */
;* 	    ((binop = >)                                               */
;* 	     (hopjs-parse-expr (hopjs-parse-consume-token-any)))       */
;* 	    ((new)                                                     */
;* 	     (hopjs-parse-consume-token-any))                          */
;* 	    ((colon)                                                   */
;* 	     (let* ((save hopjs-parse-tokens)                          */
;* 		    (ctok (hopjs-parse-consume-token-any))             */
;* 		    (etok (hopjs-parse-expr ctok)))                    */
;* 	       (if etok                                                */
;* 		   (if (eq (hopjs-parse-peek-token-type) 'qmark)       */
;* 		       (let ((qtok (hopjs-parse-consume-token-any)))   */
;* 			 (hopjs-parse-expr qtok))                      */
;* 		     (progn                                            */
;* 		       (setq hopjs-parse-tokens save)                  */
;* 		       tok))                                           */
;* 		 (progn                                                */
;* 		   (setq hopjs-parse-tokens save)                      */
;* 		   tok))))                                             */
	    (t
	     tok))))
       ((dot)
	(let ((dtok (hopjs-parse-consume-token-any)))
	  (hopjs-debug 0 "hopjs-parse-expr-simple.ident.dot dtok=%s peek=%s same=%s"
		       dtok (hopjs-parse-peek-token)
		       (hopjs-parse-same-linep (hopjs-parse-peek-token) dtok))
	  (if (hopjs-parse-same-linep (hopjs-parse-peek-token) dtok)
	      (or (hopjs-parse-expr (hopjs-parse-peek-token)) tok)
	    dtok)))
       ((=>)
	(let ((tok (hopjs-parse-consume-token-any)))
	  (hopjs-debug 0 "hopjs-parse-expr-simple.=> %s peek=%s [%s]"
		       tok
		       (hopjs-parse-peek-token)
		       (hopjs-parse-token-string (hopjs-parse-peek-token)))
	  (case (hopjs-parse-peek-token-type)
	    ((ident)
	     (hopjs-parse-consume-token-any))
	    ((rparen)
	     (hopjs-parse-args (hopjs-parse-consume-token-any))
	     (hopjs-parse-peek-token))
	    (t
	     tok))))
       ((function function* service)
	(hopjs-parse-consume-tokens '(function function* service ident)))
       ((binop >)
	(let ((tok (hopjs-parse-consume-token-any)))
	  (hopjs-debug 0 "hopjs-parse-expr-simple.binop %s [%s] peek=%s"
		       tok
		       (hopjs-parse-token-string tok)
		       (hopjs-parse-peek-token-type))
	  (hopjs-parse-expr (hopjs-parse-consume-token-any))))
       ((number string)
	(let ((tok (hopjs-parse-consume-token-any)))
	  (case (hopjs-parse-peek-token-type)
	    ((binop = >)
	     (hopjs-debug 0 "hopjs-parse-expr-simple.literal %s"
			  (hopjs-parse-peek-token-type))
	     (or (hopjs-parse-lhs (hopjs-parse-consume-token-any)) tok))
	    (t
	     tok))))
       ((prefix)
	(let ((tok (hopjs-parse-consume-token-any)))
	  (or (hopjs-parse-lhs tok) tok)))
       ((rparen)
	(goto-char (hopjs-parse-token-end tok))
	(hopjs-debug 0 "hopjs-parse-expr-simple.rparen.1 point=%s" (point))
	(if (hopjs-parse-backward-sexp)
	    (let* ((tok (hopjs-parse-consume-and-peek-token))
		   (etok (hopjs-parse-expr tok)))
	      (hopjs-debug 0 "hopjs-parse-expr-simple.rparen.2 %s [%s] -> %s [%s] peek=%s" tok
			   (hopjs-parse-token-string tok)
			   etok
			   (and etok (hopjs-parse-token-string etok))
			   (hopjs-parse-peek-token-type))
	      ;; ident ( expr )
	      (cond
	       ((eq (hopjs-parse-peek-token-type) '=>)
		(let ((tok (hopjs-parse-consume-token-any)))
		  (if (eq (hopjs-parse-peek-token-type) 'ident)
		      (hopjs-parse-consume-token-any)
		    (hopjs-parse-args))))
	       ((not etok)
		tok)
	       ((memq (hopjs-parse-token-type etok) '(ident dollar))
		etok)
	       (t
		tok)))
	  '()))
       ((rbrace)
	(goto-char (hopjs-parse-token-end tok))
	(hopjs-debug 0 "hopjs-parse-expr-simple.rbrace.0 %s [%s]" tok
		     (hopjs-parse-token-string tok))
	(mcond
	 ((hopjs-parse-backward-sexp)
	  =>
	  #'(lambda (pos)
	      (let ((tok (hopjs-parse-consume-token-any)))
		(hopjs-debug 0 "hopjs-parse-expr-simple.rbrace.1 %s [%s] -> peek=%s [%s]" tok
			     (hopjs-parse-token-string tok)
			     (hopjs-parse-peek-token)
			     (hopjs-parse-token-string
			      (hopjs-parse-peek-token)))
		(case (hopjs-parse-peek-token-type)
		  ((=> new rparen)
		   (hopjs-parse-expr (hopjs-parse-peek-token)))
		  (t
		   tok)))))))
       ((ctag)
	(goto-char (hopjs-parse-token-end tok))
	(if (hopjs-parse-backward-sexp)
	    (let ((tok (hopjs-parse-consume-and-peek-token)))
	      (hopjs-debug 0 "hopjs-parse-expr-simple.ctag point=%s %s [%s]"
			   (point) tok (hopjs-parse-token-string tok))
	      tok)
	  '()))
       ((=)
	(hopjs-parse-goto-token (hopjs-parse-consume-token-any))
	(hopjs-debug 0 "hopjs-parse-expr-simple-= %s" (point))
	(if (hopjs-parse-backward-sexp)
	    (progn
	      (hopjs-debug 0 "hopjs-parse-expr-simple.1= %s" (point))
	      (let ((tok (hopjs-parse-consume-and-peek-token)))
		(hopjs-debug 0 "hopjs-parse-expr-simple.2= %s" (point))
		(hopjs-debug 0 "hopjs-parse-expr-simple.= %s [%s]" tok
			     (hopjs-parse-token-string tok))
		tok))
	  '()))
       (t '())))))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-lhs ...                                              */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-lhs (tok)
  (hopjs-parse-expr tok))

;*---------------------------------------------------------------------*/
;*    hopjs-parse-same-linep ...                                       */
;*---------------------------------------------------------------------*/
(defun hopjs-parse-same-linep (left right)
  (save-excursion
    (goto-char (hopjs-parse-token-end left))
    (end-of-line)
    (<= (hopjs-parse-token-end right) (point))))
 
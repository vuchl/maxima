(defun replace-substring (in-string old new) 
  (let ((result ""))
    (do ((begin 0)
	 (end (search old in-string) 
	      (search old in-string :start2 begin)))
	((>= begin (length in-string)) 'done)
      (if end
	  (progn (setf result (concatenate 'string result 
					   (subseq in-string begin end)
					   new))
		 (setf begin (+ end (length old))))
	  (progn (setf result (concatenate 'string result 
					   (subseq in-string begin
						   (length in-string))))
		 (setf begin (length in-string)))))
    result))

(defun process-file (in-filename out-filename substitutions)
  (with-open-file (in in-filename :direction :input)
    (with-open-file (out out-filename :direction :output
			 :if-exists :supersede)
      (do ((line (read-line in nil 'eof)
		 (read-line in nil 'eof)))
	  ((eql line 'eof))
	(mapc #'(lambda (pair)
		  (setf line (replace-substring line 
						(first pair)
						(rest pair))))
	      substitutions)
	(format out "~a~%" line)))))

(defun read-with-default (prompt default)
  (format t "~a [~a]: " prompt default)
  (terpri)
  (let ((response (read-line)))
    (if (string= response "") default response)))


;;; This function (only) modified from CLOCC http://clocc.sourceforge.net
(defun default-directory-string ()
  (string-right-trim 
   "\\" (string-right-trim 
	 "/"
	 (namestring  
	  #+allegro (excl:current-directory)
	  #+clisp (#+lisp=cl ext:default-directory 
			     #-lisp=cl lisp:default-directory)
	  #+cmu (ext:default-directory)
	  #+cormanlisp (ccl:get-current-directory)
	  #+lispworks (hcl:get-working-directory)
	  #+lucid (lcl:working-directory)
	  #-(or allegro clisp cmu cormanlisp lispworks lucid) 
	  (truename ".")))))
  
(defun get-version ()
  (let ((version ""))
    (with-open-file (in "configure.in" :direction :input)
      (do ((line (read-line in nil 'eof)
		 (read-line in nil 'eof)))
	  ((eql line 'eof))
	(if (search "AM_INIT_AUTOMAKE" line)
	    (progn 
	      (setf version 
		    (replace-substring line "AM_INIT_AUTOMAKE(maxima," ""))
	      (setf version
		    (replace-substring version ")" ""))))))
    version))
  
(defvar *maxima-lispname* #+clisp "clisp"
	#+cmu "cmucl"
	#+sbcl "sbcl"
	#+gcl "gcl"
	#+allegro "acl6"
	#+openmcl "openmcl"
	#-(or clisp cmu sbcl gcl allegro openmcl) "unknownlisp")

(defun configure (&key (interactive t) (verbose nil)
		  is-win32 
		  maxima-directory 
		  posix-shell
		  clisp-name
		  cmucl-name
		  acl6-name
		  openmcl-name
		  sbcl-name)
  (let ((prefix (if maxima-directory 
		    maxima-directory
		    (default-directory-string)))
	(win32-string (if is-win32 "true" "false"))
	(shell (if posix-shell posix-shell "/bin/sh"))
	(clisp (if clisp-name clisp-name "clisp"))
	(cmucl (if cmucl-name cmucl-name "lisp"))
	(acl6 (if acl6-name acl6-name "acl"))
	(openmcl (if openmcl-name openmcl-name "mcl"))
	(sbcl (if sbcl-name sbcl-name "sbcl"))
	(files (list "maxima-local.in" "src/maxima.in" "src/maxima.bat.in"
		     "src/autoconf-variables.lisp.in"))
	(substitutions))
    (if interactive
	(progn
	  (setf prefix (read-with-default "Enter the Maxima directory" prefix))
	  (setf win32-string 
		(read-with-default "Is this a Windows system? (true/false)" 
				   win32-string))
	  (setf shell (read-with-default "Posix shell (optional)" shell))
	  (setf clisp 
		(read-with-default "Name of the Clisp executable (optional)"
				   clisp))
	  (setf cmucl 
		(read-with-default "Name of the CMUCL executable (optional)"
				   cmucl))
	  (setf acl6 
		(read-with-default "Name of the Allegro executable (optional)"
				   acl6))
	  (setf openmcl 
		(read-with-default "Name of the OpenMCL executable (optional)"
				   openmcl))
	  (setf sbcl 
		(read-with-default "Name of the SBCL executable (optional)"
				   sbcl))))
    (setf substitutions (list (cons "@prefix@" 
				    (replace-substring prefix "\\" "\\\\"))
			      (cons "@PACKAGE@" "maxima")
			      (cons "@VERSION@" (get-version))
			      (cons "@win32@" win32-string)
			      (cons "@default_layout_autotools@" "false")
			      (cons "@POSIX_SHELL@" "/bin/sh")
			      (cons "@expanded_top_srcdir@" 
				    (replace-substring prefix "\\" "\\\\"))
			      (cons "@DEFAULTLISP@" *maxima-lispname*)
			      (cons "@CLISP_NAME@" clisp)
			      (cons "@CMUCL_NAME@" cmucl)
			      (cons "@ACL6_NAME@" acl6)
			      (cons "@OPENMCL_NAME@" openmcl)
			      (cons "@SBCL_NAME@" sbcl)))
    (if verbose
	(mapc #'(lambda (pair) (format t "~a=~a~%" (first pair) (rest pair)))
	      substitutions))
    (mapc #'(lambda (filename)
	      (let ((out-filename (replace-substring filename ".in" "")))
		(process-file filename out-filename substitutions)
		(format t "Created ~a~%" out-filename)))
	  files)))

;; to run the tests, with emacs > 24:
;; emacs -q -L . -l test.el --batch
;; with earlier emacs versions:
;; emacs -q -L . -L /path/to/dir/where/ert/resides -l test.el --batch

(require 'abl-mode)
(require 'ert)
(require 'cl)

(defun write-to-file (file-path string)
  (with-temp-buffer (insert string)
		    (write-region (point-min) (point-max) file-path)))

(defun read-from-file (file-path)
  (with-temp-buffer
    (insert-file-contents file-path)
    (buffer-string)))

(defvar project-subdir "aproject")
(defvar test-file-name "project_tests.py")
(defvar output-file-path "/tmp/tc.txt")
(defvar proof-file-name "out.txt")
(defvar test-file-content
  (concat "import unittest\n"
	  "\n"
	  "class AblTest(unittest.TestCase):\n"
	  "#marker\n"
	  "    def test_abl_mode(self):\n"
	  "        f = open('OUTPUTPATH', 'w')\n"
	  "        f.write('TXTOUTPUT')\n"
	  "        f.flush()\n"
	  "        f.close()"
	  "\n"
	  "    def test_other_thing(self):\n"
	  "        pass"))

(defvar setup-content
  (concat "from setuptools import setup\n"
	  "setup(name='test')\n"))


(defun makedir (dir)
  (if (not (file-exists-p dir))
      (make-directory dir)))

(cl-defstruct (testenv
	       (:constructor new-testenv
			     (base-dir
			      &optional
			      (project-dir (abl-mode-concat-paths base-dir project-subdir))
			      (proof-dir (abl-mode-concat-paths base-dir "_proof"))
			      (setup-py-path (abl-mode-concat-paths base-dir "setup.py"))
			      (test-file-path (abl-mode-concat-paths project-dir test-file-name))
			      (init-file-path (abl-mode-concat-paths project-dir "__init__.py")))))
  base-dir project-dir proof-dir setup-py-path test-file-path init-file-path)

(defun random-testenv ()
  (new-testenv (make-temp-file "abltest" 't)))

(defun testenv-init (env)
  ;;create git repo with setup.py and a test file. the folder
  ;;structure will look something like this (the temp directory name
  ;;starting with abltest will be different):
  ;; /tmp
  ;;   |
  ;;   - abltest18945
  ;;        |
  ;;        - .git
  ;;        - setup.py
  ;;        - _proof (dir)
  ;;        - aproject
  ;;             |
  ;;             - project_tests.py (contents: test-file-content)
  ;;             - __init__.py (contents: #nothing)
    (makedir (testenv-base-dir env))
    (assert (abl-mode-index-of "Initialized empty Git repository"
		      (shell-command-to-string
		       (concat "git init " (testenv-base-dir env)))))
    (makedir (testenv-project-dir env))
    (makedir (testenv-proof-dir env))
    (write-to-file (testenv-setup-py-path env) setup-content)
    (write-to-file (testenv-test-file-path env) test-file-content)
    (write-to-file (testenv-init-file-path env) "#nothing")
    (shell-command-to-string
     (format
      "cd %s && git add setup.py && git add %s && git commit -am 'haha'"
      (testenv-base-dir env)
      (abl-mode-concat-paths project-subdir test-file-name)))
    env)

(defun testenv-project-name (env)
  (abl-mode-last-path-comp (testenv-project-dir env)))

(defun testenv-base-dirname (env)
  (abl-mode-last-path-comp (directory-file-name (testenv-base-dir env))))

(defun testenv-proof-file (env)
  (abl-mode-concat-paths (testenv-proof-dir env) "out.txt"))

(defun testenv-branch-git (env branch-name)
  (shell-command-to-string (format
			    "cd %s && git branch %s && git checkout %s"
			    (testenv-base-dir env) branch-name branch-name)))

(defun cleanup (path)
  ;; rm -rf's a folder which begins with /tmp. you shouldn't put
  ;; important stuff into /tmp.
  (unless (or (abl-mode-starts-with path "/tmp") (abl-mode-starts-with path "/var/folders/"))
    (error
     (format "Tried to cleanup a path (%s) not in /tmp; refusing to do so."
	     path)))
  (shell-command-to-string
   (concat "rm -rf " path)))

(defmacro abl-git-test (&rest tests-etc)
  "Macro for tests. The first argument determines whether a dummy
vem is created."
  `(let* ((env (testenv-init (random-testenv)))
	  ;; (vem-proof-file-path (format "%s/_proof/proveit.txt" base-dir))
	  ;; (test-proof-file-path (format "%s/_proof/prove_test.txt" base-dir))
	  ;; (run-proof-file-path (format "%s/_proof/prove_run.txt" base-dir))
	  )
     (unwind-protect
	 (progn
	   ,@tests-etc)
	 ;;(cleanup base-dir)
	 )))

(defun abl-values-for-path (path)
  (let ((buffer (find-file path)))
    (list
     (buffer-local-value 'abl-mode buffer)
     (buffer-local-value 'abl-mode-branch buffer)
     (buffer-local-value 'abl-mode-branch-base buffer)
     (buffer-local-value 'abl-mode-project-name buffer)
     (buffer-local-value 'abl-mode-vem-name buffer)
     (buffer-local-value 'abl-mode-shell-name buffer))))

;; -----------------------------------------------------------------------------------------
;; Tests start here

(ert-deftest test-abl-utils ()
  (should (string-equal (abl-mode-concat-paths "/tmp/blah" "yada" "etc")
			"/tmp/blah/yada/etc"))
  (should (equal (abl-mode-remove-last '(1 2 3 4)) '(1 2 3)))
  (should (equal (abl-mode-remove-last '(1)) '()))
  (should (string-equal (abl-mode-higher-dir "/home/username/temp") "/home/username"))
  (should (string-equal (abl-mode-higher-dir "/home/username/") "/home"))
  (should (string-equal (abl-mode-higher-dir "/home") "/"))
  (should (not(abl-mode-higher-dir "/")))
  (should (string-equal (abl-mode-remove-last-slash "/hehe/haha") "/hehe/haha"))
  (should (string-equal (abl-mode-remove-last-slash "/hehe/haha/") "/hehe/haha"))
  (should (string-equal (abl-mode-remove-last-slash "") ""))
  (should (string-equal (abl-mode-last-path-comp "/hehe/haha") "haha"))
  (should (string-equal (abl-mode-last-path-comp "/hehe/haha/") "haha"))
  (should (string-equal (abl-mode-last-path-comp "/hehe/haha.py") "haha.py"))
  (should (not (abl-mode-last-path-comp ""))))

(ert-deftest test-cvs-utils ()
  (let* ((git-dir (make-temp-file "" 't))
	 (git-deeper (abl-mode-concat-paths git-dir "blah"))
	 (svn-dir (make-temp-file "" 't))
	 (svn-deeper (abl-mode-concat-paths svn-dir "yada"))
	 (empty-dir (make-temp-file "" 't)))
    (mapc #'make-directory (list (abl-mode-concat-paths git-dir ".git")
				 (abl-mode-concat-paths svn-dir ".svn")
				 git-deeper svn-deeper))
    (should (string-equal (abl-mode-git-or-svn git-dir) "git"))
    (should (string-equal (abl-mode-git-or-svn git-deeper) "git"))
    (should (string-equal (abl-mode-git-or-svn svn-dir) "svn"))
    (should (string-equal (abl-mode-git-or-svn svn-deeper) "svn"))
    (should (not (abl-mode-git-or-svn empty-dir)))))


(ert-deftest test-project-name-etc ()
  (should (string-equal (abl-mode-branch-name "/home") "home"))
  (let* ((env (testenv-init (random-testenv)))
    (should (string-equal (abl-mode-branch-name (testenv-project-dir env)) "master"))
    (should (string-equal (abl-mode-get-project-name (testenv-project-dir env))
			  (testenv-project-name env)))

    (should (string-equal (abl-mode-get-ve-name "master" "project")
     			  "project_master"))

    (cleanup (abl-mode-concat-paths (testenv-project-dir env) ".git"))
    (make-directory (abl-mode-concat-paths (testenv-project-dir env) ".svn"))
    (should (string-equal (abl-mode-branch-name (testenv-project-dir env))
     			  (testenv-project-name env)))
    (should (string-equal (abl-mode-get-project-name (testenv-project-dir env))
     			  (testenv-base-dirname env)))
 )))


(ert-deftest test-empty-git-abl ()
  (abl-git-test
   (cleanup (abl-mode-concat-paths (testenv-base-dir env) ".git"))
   (let ((test-buffer (find-file (testenv-test-file-path env))))
     (should (buffer-local-value 'abl-mode test-buffer))
     (should (string-equal (buffer-local-value 'abl-mode-branch test-buffer)
			   (testenv-base-dirname env)))
     (should (string-equal (buffer-local-value 'abl-mode-branch-base test-buffer)
			   (testenv-base-dir env)))
     (should (string-equal (buffer-local-value 'abl-mode-project-name test-buffer)
			   (testenv-base-dirname env)))
     (should (string-equal (buffer-local-value 'abl-mode-ve-name test-buffer)
			   (concat (testenv-base-dirname env) "_" (testenv-base-dirname env))))
)))


(ert-deftest test-git-abl ()
  (abl-git-test
   (let ((test-buffer (find-file (testenv-test-file-path env))))
     (should (buffer-local-value 'abl-mode test-buffer))
     (should (string-equal (buffer-local-value 'abl-mode-branch test-buffer)
			   "master"))
     (should (string-equal (buffer-local-value 'abl-mode-branch-base test-buffer)
			   (testenv-base-dir env)))
     (should (string-equal (testenv-base-dirname env)
			   (buffer-local-value 'abl-mode-project-name test-buffer)))
      (should (string-equal (buffer-local-value 'abl-mode-ve-name test-buffer)
			    (concat (testenv-base-dirname env) "_master")))
)))


(ert-deftest test-branched-git-abl ()
  (abl-git-test
   (testenv-branch-git env "gitbranch")
   (let ((test-buffer (find-file (testenv-test-file-path env))))
     (should (buffer-local-value 'abl-mode test-buffer))
     (should (string-equal (buffer-local-value 'abl-mode-branch test-buffer)
			   "gitbranch"))
     (should (string-equal (buffer-local-value 'abl-mode-branch-base test-buffer)
			   (testenv-base-dir env)))
     (should (string-equal (testenv-base-dirname env)
			   (buffer-local-value 'abl-mode-project-name test-buffer)))
      (should (string-equal (buffer-local-value 'abl-mode-ve-name test-buffer)
			    (concat (testenv-base-dirname env) "_gitbranch")))
)))

(ert-deftest test-test-at-point ()
  (abl-git-test
   (find-file (testenv-test-file-path env))
   (goto-char (point-min))
   (should (string-equal (abl-mode-get-test-entity)
			 "aproject.project_tests"))
   (search-forward "marker")
   (should (string-equal (abl-mode-get-test-entity)
			 "aproject.project_tests.AblTest"))
   (search-forward "f.write")
   (should (string-equal (abl-mode-get-test-entity)
			 "aproject.project_tests.AblTest.test_abl_mode"))
   (search-forward "pass")
   (should (string-equal (abl-mode-get-test-entity)
			 "aproject.project_tests.AblTest.test_other_thing"))
))

(ert-deftest test-ve-check-and-activation ()
  (let ((collected-msgs '())
	(output-dir (make-temp-file "testout" 't)))
    (flet ((read-from-minibuffer
	    (msg)
	    (setq collected-msgs (append collected-msgs (list msg)))
	    (if (= (length collected-msgs) 1)
		"test-ve"
	      "y")))
    (abl-git-test
     (find-file (testenv-test-file-path env))
     (setq abl-mode-ve-create-command (concat "cd " output-dir " && touch %s"))
     (abl-mode-exec-command "ls")
     (file-exists-p (abl-mode-concat-paths output-dir "test-ve"))))))


(ert-deftest test-running-tests ()
  (abl-git-test
   (find-file (testenv-test-file-path env))
   (goto-char (point-min))
   (replace-string "OUTPUTPATH" (testenv-proof-file env))
   (replace-string "TXTOUTPUT" "blah blah")
   (save-buffer)
   (setq abl-mode-check-and-activate-ve nil)
   (abl-mode-run-test-at-point)
   (sleep-for 1)
   (should (file-exists-p (testenv-proof-file env)))
   (should (string-equal (read-from-file (testenv-proof-file env))
			 "blah blah"))))

;; (ert-deftest test-replacement-vem ()
;;   (abl-git-test
;;     (commit-git base-dir)
;;     (let* ((abl-values (abl-values-for-path test-file-path))
;; 	   (master-vemname (nth 4 abl-values))
;; 	   (new-branch "gitbranch")
;; 	   (branch-vemname (concat project-name "_" new-branch))
;; 	   (test-buff (find-file test-file-path)))
;;       (goto-char (point-max))
;;       (setq abl-mode-vems-base-dir (make-temp-file "vems" 't))
;;       (shell-command-to-string (format "virtualenv %s"
;; 				       (abl-mode-concat-paths abl-mode-vems-base-dir master-vemname)))
;;       (should (= 0 (length abl-mode-replacement-vems)))

;;       (branch-git base-dir new-branch)
;;       (setq abl-mode-replacement-vems (list (cons branch-vemname master-vemname)))
;;       (setq abl-mode-vem-activate-command (concat "echo '%s' > " vem-proof-file-path))

;;       (revert-buffer test-buff t nil)
;;       (goto-char (point-max))
;;       (abl-mode-run-test-at-point)
;;       (sleep-for 1)
;;       (should (file-exists-p vem-proof-file-path))
;;       (save-excursion
;; 	(find-file vem-proof-file-path)
;; 	(should (string= (buffer-substring (point-min) (- (point-max) 1))
;; 			 master-vemname)))

;;       (cleanup abl-mode-vems-base-dir)
;;       )))


(add-hook 'find-file-hooks 'abl-mode-hook)
(ert t)

;;; jedi.el --- a Python auto-completion for Emacs

;; Copyright (C) 2012 Takafumi Arakaki

;; Author: Takafumi Arakaki <aka.tkf at gmail.com>

;; This file is NOT part of GNU Emacs.

;; jedi.el is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; jedi.el is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with jedi.el.
;; If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(require 'epc)
(require 'auto-complete)

(defvar jedi:source-dir (if load-file-name
                            (file-name-directory load-file-name)
                          default-directory))

(defvar jedi:epc nil)

(defun jedi:start-epc ()
  (if jedi:epc
      (message "Jedi server is already started!")
    (let ((default-directory jedi:source-dir))
      (setq jedi:epc (epc:start-epc "make" '("serve"))))))

(defun jedi:stop-epc ()
  (interactive)
  (if jedi:epc
      (epc:stop-epc jedi:epc)
    (message "Jedi server is already killed."))
  (setq jedi:epc nil))

(defun jedi:get-epc ()
  (or jedi:epc (jedi:start-epc)))


;;; Completion

(defvar jedi:ac-direct-matches nil
  "Variable to store completion candidates for `auto-completion'.")

(defvar jedi:complete-request-point nil
  "The point where `jedi:complete-request' is called.")

(defun* jedi:complete-request
    (&optional
     (source      (buffer-substring-no-properties (point-min) (point-max)))
     (line        (count-lines (point-min) (point)))
     (column      (current-column))
     (source-path buffer-file-name)
     (point       (point)))
  "Request ``Script(...).complete`` and return a deferred object.
`jedi:ac-direct-matches' is set to the completions sent from the
server."
  (setq jedi:complete-request-point point)
  (deferred:nextc (epc:call-deferred (jedi:get-epc)
                                     'complete
                                     (list source line column source-path))
    (lambda (completions)
      (setq jedi:ac-direct-matches completions))))

(defun jedi:complete ()
  "Complete code at point."
  (interactive)
  (deferred:nextc (jedi:complete-request)
    (lambda () (auto-complete '(ac-source-jedi-direct)))))


;;; AC source

(defun jedi:ac-direct-prefix ()
  (or (ac-prefix-default)
      (when (= jedi:complete-request-point (point))
        jedi:complete-request-point)))

;; (makunbound 'ac-source-jedi-direct)
(ac-define-source jedi-direct
  '((candidates . jedi:ac-direct-matches)
    (prefix jedi:ac-direct-prefix)
    (init . jedi:complete-request)
    (requires . -1)
    (symbol . "s")))


(provide 'jedi)

;;; jedi.el ends here

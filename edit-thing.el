;;; edit-thing.el --- narrow-to-region on steroids

;; Copyright (C) 2012  Mike Spindel

;; Author: Mike Spindel <mike@spindel.is>
;; Version: 0.1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(defvar edit-thing--buffer-prefix "")
(make-variable-buffer-local 'edit-thing--buffer-prefix)
(put 'edit-thing--buffer-prefix 'permanent-local t)

(defvar edit-thing--buffer-changed nil)
(make-variable-buffer-local 'edit-thing--buffer-changed)
(put 'edit-thing--buffer-changed 'permanent-local t)

(defvar edit-thing--source-overlay nil)
(make-variable-buffer-local 'edit-thing--source-overlay)
(put 'edit-thing--source-overlay 'permanent-local t)

(defvar edit-thing--buffer-list '())
(setq edit-thing--buffer-list '())


(defun edit-thing-edit-region (&optional edit-mode)
  (interactive)
  (unless edit-mode
    (setq edit-mode major-mode))

  (let* ((overlay (make-overlay (region-beginning) (region-end)))
         (buffer (edit-thing--temp-buffer overlay edit-mode)))

    (popwin:popup-buffer buffer)
    (edit-thing--track-buffer buffer)))


(defun edit-thing--install (overlay)
  (insert (edit-thing--overlay-body overlay))

  ;; buffer local vars
  (setq edit-thing--buffer-prefix (edit-thing--detect-prefix (point-min) (point-max))
        edit-thing--source-overlay overlay
        edit-thing--buffer-changed nil)

  (edit-thing--delete-prefix
   edit-thing--buffer-prefix (point-min) (point-max))

  ;; global hooks
  (add-hook 'window-configuration-change-hook 'edit-thing--window-change-hook)
  (add-hook 'after-change-functions 'edit-thing--buffer-changed)

  ;; buffer local hooks
  (add-hook 'kill-buffer-hook 'edit-thing--kill-buffer-hook nil t))


(defun edit-thing--temp-buffer (overlay mode)
  (let ((buffer (get-buffer-create "*Narrowed*")))
    (with-current-buffer buffer
      (edit-thing--install overlay)
      (when mode (funcall mode)))
    buffer))


(defun edit-thing--prefix-intersect (str1 str2)
  (if (and str1 str2)
      (let ((diff (compare-strings str1 nil nil str2 nil nil)))
        (cond
         ((eq diff t) str1)
         ((>= diff 0) (substring str1 0 (- diff 1)))
         (t (substring str1 0 (- -1 diff)))))
    (or str1 str2)))


(defun edit-thing--detect-prefix (begin end)
  (save-excursion
    (goto-char begin)
    (loop
     with prefix = nil
     while (re-search-forward "^\\s *" end t nil)
     if (not (eolp))
     do (setq prefix (edit-thing--prefix-intersect prefix (match-string-no-properties 0)))
     if (>= (point) end) return prefix
     else do (forward-char))))


(defun edit-thing--delete-prefix (prefix begin end)
  (let ((prefix-re (concat "^" (regexp-quote prefix))))
    (save-excursion
      (goto-char begin)
      (loop
       while (re-search-forward prefix-re end t nil)
       do (replace-match "")
       if (>= (point) end) return t
       else do (forward-char)))))


(defun edit-thing--insert-prefix (prefix begin end)
  (save-excursion
    (goto-char begin)
    (loop
     while (re-search-forward "^" end t nil)
     do (insert prefix)
     if (>= (point) end) return t
     else do (forward-char))))


(defun edit-thing--sync-buffer (buffer)
  (setq edit-thing--buffer-changed nil)

  (when (and (overlayp edit-thing--source-overlay)
             (overlay-buffer edit-thing--source-overlay))
    (edit-thing--sync-buffer-1 edit-thing--source-overlay
                               edit-thing--buffer-prefix)))


(defun edit-thing--sync-buffer-1 (overlay prefix)
  (edit-thing--replace-overlay overlay
                               (buffer-substring-no-properties
                                (point-min) (point-max)))
  (with-current-buffer (overlay-buffer overlay)
    (save-excursion
      (edit-thing--insert-prefix
       prefix
       (overlay-start overlay)
       (overlay-end overlay)))))


(defun edit-thing--kill-buffer (buffer)
  (edit-thing--untrack-buffer buffer)
  (kill-buffer buffer))


(defun edit-thing--track-buffer (buffer)
  (push buffer edit-thing--buffer-list))


(defun edit-thing--untrack-buffer (buffer)
  (setq edit-thing--buffer-list
        (delq buffer edit-thing--buffer-list))

  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (let ((overlay edit-thing--source-overlay))
        (when overlay
          (edit-thing--sync-buffer buffer)
          (delete-overlay overlay))))))


(defun edit-thing--buffer-changed (begin end len)
  (when (and (overlayp edit-thing--source-overlay)
             (overlay-buffer edit-thing--source-overlay)
             (null edit-thing--buffer-changed))
    (setq edit-thing--buffer-changed
          (run-with-idle-timer 0 nil 'edit-thing--idle-func (current-buffer)))))


(defun edit-thing--window-change-hook ()
  (mapc (lambda (buffer)
          (unless (get-buffer-window buffer nil)
            (edit-thing--kill-buffer buffer)))
        edit-thing--buffer-list))


(defun edit-thing--kill-buffer-hook ()
  (edit-thing--sync-buffer (current-buffer)))


(defun edit-thing--idle-func (buffer)
  (edit-thing--sync-buffer buffer))


(defun edit-thing--overlay-body (overlay)
  (with-current-buffer (overlay-buffer overlay)
    (buffer-substring-no-properties
     (overlay-start overlay)
     (overlay-end overlay))))


(defun edit-thing--replace-overlay (overlay body)
  (with-current-buffer (overlay-buffer overlay)
    (let ((inhibit-modification-hooks t)
          (start (overlay-start overlay)))
      (save-excursion
        (delete-region start (overlay-end overlay))
        (goto-char start)
        (insert body)
        (move-overlay overlay start (point))))))


(provide 'edit-thing)
;;; edit-thing.el ends here

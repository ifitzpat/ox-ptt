;;; test-title-extraction.el --- Test title extraction

(add-to-list 'load-path "/home/user/ox-ptt")
(require 'ox-ppt)

(with-temp-buffer
  (insert-file-contents "/home/user/ox-ptt/test/formatting-test.org")
  (org-mode)
  (let* ((info (org-combine-plists
                (org-export--get-export-attributes 'ppt)
                (org-export--get-buffer-attributes)
                (org-export-get-environment 'ppt)))
         (title (plist-get info :title))
         (subtitle (plist-get info :subtitle))
         (author (plist-get info :author)))
    (message "Raw title: %S" title)
    (message "Raw subtitle: %S" subtitle)
    (message "Raw author: %S" author)
    (message "Interpreted title: %S" (org-element-interpret-data title))
    (message "Interpreted subtitle: %S" (org-element-interpret-data subtitle))
    (message "Interpreted author: %S" (org-element-interpret-data author))))

;;; ox-ppt-utils.el --- Utility functions for ox-ppt -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;;; Commentary:

;; Utility functions for ox-ppt, including:
;; - EMU (English Metric Units) conversions
;; - Common helper functions
;; - String and formatting utilities

;;; Code:

(require 'cl-lib)

;;; Constants

(defconst org-ppt-emu-per-inch 914400
  "Number of EMUs (English Metric Units) in one inch.")

(defconst org-ppt-emu-per-point 12700
  "Number of EMUs in one point.")

(defconst org-ppt-emu-per-cm 360000
  "Number of EMUs in one centimeter.")

;;; EMU Conversion Functions

(defun org-ppt--inches-to-emu (inches)
  "Convert INCHES to EMUs."
  (* inches org-ppt-emu-per-inch))

(defun org-ppt--points-to-emu (points)
  "Convert POINTS to EMUs."
  (* points org-ppt-emu-per-point))

(defun org-ppt--cm-to-emu (cm)
  "Convert CM (centimeters) to EMUs."
  (* cm org-ppt-emu-per-cm))

(defun org-ppt--emu-to-inches (emu)
  "Convert EMU to inches."
  (/ (float emu) org-ppt-emu-per-inch))

(defun org-ppt--emu-to-points (emu)
  "Convert EMU to points."
  (/ (float emu) org-ppt-emu-per-point))

;;; String Utilities

(defun org-ppt--escape-xml (text)
  "Escape XML special characters in TEXT.
Also strips text properties to ensure clean XML generation."
  (let* ((clean-text (if (stringp text)
                         (substring-no-properties text)
                       text))
         (replacements '(("&" . "&amp;")
                        ("<" . "&lt;")
                        (">" . "&gt;")
                        ("\"" . "&quot;")
                        ("'" . "&apos;"))))
    (cl-reduce (lambda (str pair)
                 (replace-regexp-in-string
                  (car pair) (cdr pair) str t t))
               replacements
               :initial-value clean-text)))

(defun org-ppt--generate-id ()
  "Generate a unique ID for PPTX elements."
  (format "%d" (abs (random))))

(defun org-ppt--sanitize-filename (filename)
  "Sanitize FILENAME for use in PPTX archive."
  (replace-regexp-in-string "[^a-zA-Z0-9._-]" "_" filename))

;;; Property Access Helpers

(defun org-ppt--extract-plain-text (data)
  "Extract plain text from DATA (an org element or secondary string).
This bypasses our custom transcoders and returns plain text only."
  (when data
    (let ((text (org-export-data data '(ppt (:translate-alist . ((plain-text . (lambda (text _info) text))))))))
      (substring-no-properties text))))

(defun org-ppt--get-title (info)
  "Get document title from INFO plist."
  (let ((title (plist-get info :title)))
    (if title
        (org-ppt--extract-plain-text title)
      "Untitled")))

(defun org-ppt--get-subtitle (info)
  "Get document subtitle from INFO plist."
  (let ((subtitle (plist-get info :subtitle)))
    (when subtitle
      (org-ppt--extract-plain-text subtitle))))

(defun org-ppt--get-author (info)
  "Get document author from INFO plist."
  (let ((author (plist-get info :author)))
    (when author
      (org-ppt--extract-plain-text author))))

(defun org-ppt--get-date (info)
  "Get document date from INFO plist."
  (let ((date (plist-get info :date)))
    (when date
      (substring-no-properties (org-export-data date info)))))

;;; List Processing Helpers

(defun org-ppt--collect-headlines (tree level)
  "Collect headlines at LEVEL from TREE."
  (org-element-map tree 'headline
    (lambda (hl)
      (when (= (org-element-property :level hl) level)
        hl))))

(defun org-ppt--headline-title (headline)
  "Extract title from HEADLINE element."
  (org-element-property :raw-value headline))

(defun org-ppt--headline-level (headline)
  "Extract level from HEADLINE element."
  (org-element-property :level headline))

;;; File System Helpers

(defun org-ppt--ensure-directory (dir)
  "Ensure directory DIR exists, create if necessary."
  (unless (file-exists-p dir)
    (make-directory dir t)))

(defun org-ppt--write-file (path content)
  "Write CONTENT to file at PATH.
Creates parent directories if necessary."
  (let ((dir (file-name-directory path)))
    (org-ppt--ensure-directory dir))
  (with-temp-file path
    (insert content)))

(defun org-ppt--write-xml-file (path esxml-tree)
  "Write ESXML-TREE as XML to file at PATH."
  (org-ppt--write-file path
                       (concat "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                               (esxml-to-xml esxml-tree))))

(provide 'ox-ppt-utils)
;;; ox-ppt-utils.el ends here

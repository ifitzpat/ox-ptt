;;; ox-ppt.el --- Export Org-mode documents to PowerPoint PPTX -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;; Author: ox-ppt contributors
;; Keywords: org, export, powerpoint, pptx
;; Version: 0.1.0
;; Package-Requires: ((emacs "26.1") (org "9.0") (esxml "0.3.4"))

;; This file is not part of GNU Emacs.

;;; Commentary:

;; This package provides an Org-mode export backend for Microsoft
;; PowerPoint PPTX format.  It converts Org-mode documents to
;; PowerPoint presentations using the Office Open XML PresentationML
;; specification.
;;
;; Usage:
;;   (require 'ox-ppt)
;;   M-x org-ppt-export-to-pptx
;;
;; The exporter uses:
;; - Level 1 headlines become slides
;; - #+TITLE, #+SUBTITLE, etc. create the title slide
;; - Level 2+ headlines become headings within slides

;;; Code:

(require 'ox)
(require 'cl-lib)
(require 'esxml)
(require 'ox-ppt-utils)
(require 'ox-ppt-templates)
(require 'ox-ppt-shapes)

;;; Configuration Variables

(defgroup org-export-ppt nil
  "Options for exporting Org-mode to PowerPoint."
  :tag "Org PowerPoint"
  :group 'org-export)

(defcustom org-ppt-slide-level 1
  "Headline level that defines individual slides.
Level 1 means each level-1 headline becomes a new slide.
Headlines below this level become headings within the slide."
  :type 'integer
  :group 'org-export-ppt)

(defcustom org-ppt-title-slide-enabled t
  "Whether to generate a title slide from document properties.
If non-nil, creates a title slide from #+TITLE, #+SUBTITLE, etc."
  :type 'boolean
  :group 'org-export-ppt)

(defcustom org-ppt-default-theme "default"
  "Default PowerPoint theme."
  :type 'string
  :group 'org-export-ppt)

(defcustom org-ppt-slide-width 9144000
  "Slide width in EMUs (default: 10 inches)."
  :type 'integer
  :group 'org-export-ppt)

(defcustom org-ppt-slide-height 6858000
  "Slide height in EMUs (default: 7.5 inches)."
  :type 'integer
  :group 'org-export-ppt)

(defcustom org-ppt-zip-program "zip"
  "Path to the zip program for creating PPTX archives."
  :type 'string
  :group 'org-export-ppt)

;;; Backend Definition

(org-export-define-backend 'ppt
  '((bold . org-ppt-bold)
    (code . org-ppt-code)
    (headline . org-ppt-headline)
    (italic . org-ppt-italic)
    (item . org-ppt-item)
    (link . org-ppt-link)
    (paragraph . org-ppt-paragraph)
    (plain-list . org-ppt-plain-list)
    (plain-text . org-ppt-plain-text)
    (section . org-ppt-section)
    (src-block . org-ppt-src-block)
    (table . org-ppt-table)
    (template . org-ppt-template)
    (underline . org-ppt-underline)
    (verbatim . org-ppt-verbatim))
  :menu-entry
  '(?p "Export to PowerPoint"
       ((?P "As PPTX file" org-ppt-export-to-pptx)
        (?o "As PPTX file and open" org-ppt-export-to-pptx-and-open))))

;;; Transcoder Functions

(defun org-ppt-template (contents info)
  "Main template function for PPTX export.
CONTENTS is the transcoded contents string.
INFO is a plist holding export options."
  (let* ((output-file (org-export-output-file-name ".pptx"))
         (temp-dir (make-temp-file "ox-ppt-" t)))
    (unwind-protect
        (progn
          (org-ppt--write-pptx-structure temp-dir info)
          (org-ppt--create-pptx-archive temp-dir output-file)
          output-file)
      (when (file-exists-p temp-dir)
        (delete-directory temp-dir t)))))

(defun org-ppt-headline (headline contents info)
  "Transcode HEADLINE element to esxml.
CONTENTS is the headline contents.
INFO is a plist holding export options."
  (let ((level (org-element-property :level headline)))
    (if (= level org-ppt-slide-level)
        ;; Level 1 headlines are handled by template function
        ;; Store slide data in info plist
        nil
      ;; Level 2+ headlines become content within slides
      contents)))

(defun org-ppt-section (section contents info)
  "Transcode SECTION element to esxml.
CONTENTS is the section contents.
INFO is a plist holding export options."
  contents)

(defun org-ppt-paragraph (paragraph contents info)
  "Transcode PARAGRAPH element to esxml.
CONTENTS is the paragraph contents.
INFO is a plist holding export options."
  (when contents
    (concat contents "\n")))

(defun org-ppt-plain-text (text info)
  "Transcode plain TEXT.
INFO is a plist holding export options."
  text)

(defun org-ppt-bold (bold contents info)
  "Transcode BOLD element.
CONTENTS is the text with bold markup.
INFO is a plist holding export options."
  (format "*BOLD:%s*" contents))

(defun org-ppt-italic (italic contents info)
  "Transcode ITALIC element.
CONTENTS is the text with italic markup.
INFO is a plist holding export options."
  (format "*ITALIC:%s*" contents))

(defun org-ppt-code (code _contents info)
  "Transcode CODE element.
INFO is a plist holding export options."
  (format "*CODE:%s*" (org-element-property :value code)))

(defun org-ppt-underline (underline contents info)
  "Transcode UNDERLINE element.
CONTENTS is the underlined text.
INFO is a plist holding export options."
  (format "*UNDERLINE:%s*" contents))

(defun org-ppt-verbatim (verbatim _contents info)
  "Transcode VERBATIM element.
INFO is a plist holding export options."
  (format "*VERBATIM:%s*" (org-element-property :value verbatim)))

(defun org-ppt-plain-list (plain-list contents info)
  "Transcode PLAIN-LIST element.
CONTENTS is the list contents.
INFO is a plist holding export options."
  contents)

(defun org-ppt-item (item contents info)
  "Transcode ITEM element.
CONTENTS is the item contents.
INFO is a plist holding export options."
  (concat "- " contents))

(defun org-ppt-link (link desc info)
  "Transcode LINK element.
DESC is the link description.
INFO is a plist holding export options."
  (or desc (org-element-property :raw-link link)))

(defun org-ppt-src-block (src-block _contents info)
  "Transcode SRC-BLOCK element.
INFO is a plist holding export options."
  (org-element-property :value src-block))

(defun org-ppt-table (table contents info)
  "Transcode TABLE element.
CONTENTS is the table contents.
INFO is a plist holding export options."
  contents)

;;; Internal Functions - PPTX Generation

(defun org-ppt--write-pptx-structure (temp-dir info)
  "Write PPTX file structure to TEMP-DIR.
INFO is a plist holding export options."
  (let* ((tree (plist-get info :parse-tree))
         (headlines (org-ppt--collect-headlines tree org-ppt-slide-level))
         (num-slides (+ (if org-ppt-title-slide-enabled 1 0)
                       (length headlines))))
    (org-ppt--write-static-files temp-dir num-slides)
    (org-ppt--write-slide-files temp-dir info headlines)))

(defun org-ppt--write-static-files (temp-dir num-slides)
  "Write static PPTX files to TEMP-DIR for NUM-SLIDES slides."
  (org-ppt--write-xml-file
   (expand-file-name "[Content_Types].xml" temp-dir)
   (org-ppt--content-types-xml num-slides))
  (org-ppt--write-xml-file
   (expand-file-name "_rels/.rels" temp-dir)
   (org-ppt--package-rels-xml))
  (org-ppt--write-xml-file
   (expand-file-name "ppt/presentation.xml" temp-dir)
   (org-ppt--presentation-xml num-slides))
  (org-ppt--write-xml-file
   (expand-file-name "ppt/_rels/presentation.xml.rels" temp-dir)
   (org-ppt--presentation-rels-xml num-slides))
  (org-ppt--write-master-and-layout temp-dir))

(defun org-ppt--write-master-and-layout (temp-dir)
  "Write master slide and layout files to TEMP-DIR."
  (org-ppt--write-xml-file
   (expand-file-name "ppt/slideMasters/slideMaster1.xml" temp-dir)
   (org-ppt--slide-master-xml))
  (org-ppt--write-xml-file
   (expand-file-name "ppt/slideMasters/_rels/slideMaster1.xml.rels" temp-dir)
   (org-ppt--slide-master-rels-xml))
  (org-ppt--write-xml-file
   (expand-file-name "ppt/slideLayouts/slideLayout1.xml" temp-dir)
   (org-ppt--slide-layout-xml))
  (org-ppt--write-xml-file
   (expand-file-name "ppt/slideLayouts/_rels/slideLayout1.xml.rels" temp-dir)
   (org-ppt--slide-layout-rels-xml))
  (org-ppt--write-xml-file
   (expand-file-name "ppt/theme/theme1.xml" temp-dir)
   (org-ppt--theme-xml)))

(defun org-ppt--write-slide-files (temp-dir info headlines)
  "Write slide files to TEMP-DIR for HEADLINES using INFO."
  (let ((slide-num 1))
    (when org-ppt-title-slide-enabled
      (org-ppt--write-single-slide temp-dir slide-num
                                    (org-ppt--make-title-slide info))
      (setq slide-num (1+ slide-num)))
    (mapc (lambda (hl)
            (org-ppt--write-single-slide temp-dir slide-num
                                          (org-ppt--make-content-slide hl info))
            (setq slide-num (1+ slide-num)))
          headlines)))

(defun org-ppt--write-single-slide (temp-dir slide-num slide-xml)
  "Write slide SLIDE-NUM with SLIDE-XML to TEMP-DIR."
  (org-ppt--write-xml-file
   (expand-file-name (format "ppt/slides/slide%d.xml" slide-num) temp-dir)
   slide-xml)
  (org-ppt--write-xml-file
   (expand-file-name (format "ppt/slides/_rels/slide%d.xml.rels" slide-num) temp-dir)
   (org-ppt--make-slide-rels-xml slide-num)))

(defun org-ppt--create-pptx-archive (temp-dir output-file)
  "Create PPTX archive from TEMP-DIR to OUTPUT-FILE."
  (let ((default-directory temp-dir))
    (when (file-exists-p output-file)
      (delete-file output-file))
    (apply #'call-process org-ppt-zip-program nil nil nil
           "-r" "-q" (expand-file-name output-file)
           (org-ppt--get-archive-files temp-dir)))
  output-file)

(defun org-ppt--get-archive-files (temp-dir)
  "Get list of files to include in archive from TEMP-DIR."
  (let ((default-directory temp-dir))
    (split-string
     (shell-command-to-string "find . -type f | sed 's|^./||'")
     "\n" t)))

;;; Export Functions

(defun org-ppt-export-to-pptx (&optional async subtreep visible-only)
  "Export current buffer to a PPTX file.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting file should be accessible through
the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

Return output file name."
  (interactive)
  (let ((outfile (org-export-output-file-name ".pptx" subtreep)))
    (org-export-to-file 'ppt outfile
      async subtreep visible-only)))

(defun org-ppt-export-to-pptx-and-open (&optional async subtreep visible-only)
  "Export to PPTX and open the resulting file.

ASYNC, SUBTREEP, and VISIBLE-ONLY are passed to
`org-ppt-export-to-pptx'."
  (interactive)
  (let ((outfile (org-ppt-export-to-pptx async subtreep visible-only)))
    (when outfile
      (org-open-file outfile))))

(provide 'ox-ppt)
;;; ox-ppt.el ends here

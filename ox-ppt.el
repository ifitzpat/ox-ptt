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

;;; Text Run Helpers

(defun org-ppt--flatten-runs (contents)
  "Flatten CONTENTS to a list of text runs.
CONTENTS can be a single run, a list of runs, or nested lists."
  (cond
   ((null contents) nil)
   ((and (listp contents)
         (eq (car contents) 'a:r))
    ;; Single run
    (list contents))
   ((listp contents)
    ;; List of runs or nested lists
    (apply #'append (mapcar #'org-ppt--flatten-runs contents)))
   (t nil)))

(defun org-ppt--add-run-formatting (runs properties)
  "Add formatting PROPERTIES to all RUNS.
PROPERTIES is an alist like ((b . "1") (i . "1"))."
  (mapcar
   (lambda (run)
     (let* ((rpr (nth 1 run))  ; (a:rPr ...)
            (existing-attrs (nth 1 rpr))  ; existing attributes
            (new-attrs (append properties existing-attrs))  ; prepend new attrs
            (rpr-children (nthcdr 2 rpr)))  ; children after attributes
       ;; Rebuild the run with updated rPr
       `(a:r ()
          (a:rPr ,new-attrs ,@rpr-children)
          ,@(nthcdr 2 run))))  ; keep a:t and other children
   runs))

;;; Transcoder Functions

(defun org-ppt-template (contents info)
  "Main template function for PPTX export.
CONTENTS is the transcoded contents string.
INFO is a plist holding export options.
Creates PPTX file in temp location."
  (let* ((temp-pptx (plist-get info :ppt-temp-file))
         (temp-dir (make-temp-file "ox-ppt-" t)))
    (when temp-pptx
      (unwind-protect
          (progn
            (org-ppt--write-pptx-structure temp-dir info)
            (org-ppt--create-pptx-archive temp-dir temp-pptx))
        (when (file-exists-p temp-dir)
          (delete-directory temp-dir t)))))
  ;; Return empty string to minimize text file size
  "")

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
  "Transcode PARAGRAPH element.
CONTENTS is a list of text runs or a string.
INFO is a plist holding export options."
  (if (plist-get info :ppt-custom-transcode)
      ;; Custom transcoder mode: return esxml paragraph
      (when contents
        (let ((runs (org-ppt--flatten-runs contents)))
          (list
           `(a:p ()
              (a:pPr ())
              ,@runs
              (a:endParaRPr ((lang . "en-US")))))))
    ;; Framework mode: return empty string
    ""))

(defun org-ppt-plain-text (text info)
  "Transcode plain TEXT.
INFO is a plist holding export options."
  ;; When called by org-export framework, return empty string
  ;; When called by our custom transcoder, return esxml
  (if (plist-get info :ppt-custom-transcode)
      ;; Custom transcoder mode: return esxml
      (list
       `(a:r ()
          (a:rPr ((lang . "en-US")))
          (a:t () ,(org-ppt--escape-xml text))))
    ;; Framework mode: return empty string
    ""))

(defun org-ppt-bold (bold contents info)
  "Transcode BOLD element.
CONTENTS is a list of text runs or a string.
INFO is a plist holding export options."
  (if (plist-get info :ppt-custom-transcode)
      ;; Custom transcoder mode: return esxml with bold formatting
      (let ((runs (org-ppt--flatten-runs contents)))
        (org-ppt--add-run-formatting runs '((b . "1"))))
    ;; Framework mode: return empty string
    ""))

(defun org-ppt-italic (italic contents info)
  "Transcode ITALIC element.
CONTENTS is a list of text runs or a string.
INFO is a plist holding export options."
  (if (plist-get info :ppt-custom-transcode)
      ;; Custom transcoder mode: return esxml with italic formatting
      (let ((runs (org-ppt--flatten-runs contents)))
        (org-ppt--add-run-formatting runs '((i . "1"))))
    ;; Framework mode: return empty string
    ""))

(defun org-ppt-code (code _contents info)
  "Transcode CODE element.
INFO is a plist holding export options."
  (if (plist-get info :ppt-custom-transcode)
      ;; Custom transcoder mode: return esxml with code formatting
      (let ((text (org-element-property :value code)))
        (list
         `(a:r ()
            (a:rPr ((lang . "en-US"))
              (a:latin ((typeface . "Courier New"))))
            (a:t () ,(org-ppt--escape-xml text)))))
    ;; Framework mode: return empty string
    ""))

(defun org-ppt-underline (underline contents info)
  "Transcode UNDERLINE element.
CONTENTS is a list of text runs or a string.
INFO is a plist holding export options."
  (if (plist-get info :ppt-custom-transcode)
      ;; Custom transcoder mode: return esxml with underline formatting
      (let ((runs (org-ppt--flatten-runs contents)))
        (org-ppt--add-run-formatting runs '((u . "sng"))))
    ;; Framework mode: return empty string
    ""))

(defun org-ppt-verbatim (verbatim _contents info)
  "Transcode VERBATIM element.
INFO is a plist holding export options."
  (if (plist-get info :ppt-custom-transcode)
      ;; Custom transcoder mode: return esxml with verbatim formatting
      (let ((text (org-element-property :value verbatim)))
        (list
         `(a:r ()
            (a:rPr ((lang . "en-US"))
              (a:latin ((typeface . "Courier New"))))
            (a:t () ,(org-ppt--escape-xml text)))))
    ;; Framework mode: return empty string
    ""))

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
   (expand-file-name "docProps/core.xml" temp-dir)
   (org-ppt--core-properties-xml))
  (org-ppt--write-xml-file
   (expand-file-name "docProps/app.xml" temp-dir)
   (org-ppt--app-properties-xml num-slides))
  (org-ppt--write-xml-file
   (expand-file-name "ppt/presentation.xml" temp-dir)
   (org-ppt--presentation-xml num-slides))
  (org-ppt--write-xml-file
   (expand-file-name "ppt/_rels/presentation.xml.rels" temp-dir)
   (org-ppt--presentation-rels-xml num-slides))
  (org-ppt--write-xml-file
   (expand-file-name "ppt/presProps.xml" temp-dir)
   (org-ppt--pres-props-xml))
  (org-ppt--write-xml-file
   (expand-file-name "ppt/viewProps.xml" temp-dir)
   (org-ppt--view-props-xml))
  (org-ppt--write-xml-file
   (expand-file-name "ppt/tableStyles.xml" temp-dir)
   (org-ppt--table-styles-xml))
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
  (let* ((outfile (org-export-output-file-name ".pptx" subtreep))
         (temp-pptx (make-temp-file "ox-ppt-output-" nil ".pptx")))
    (org-export-to-file 'ppt outfile
      async subtreep visible-only
      nil
      `(:ppt-temp-file ,temp-pptx)
      (lambda (file)
        ;; Post-process: replace text file with binary PPTX
        (when (file-exists-p temp-pptx)
          ;; Delete the text file created by org-export
          (when (file-exists-p file)
            (delete-file file))
          ;; Move the binary PPTX to final location
          (rename-file temp-pptx file t))
        file))))

(defun org-ppt-export-to-pptx-and-open (&optional async subtreep visible-only)
  "Export to PPTX and open the resulting file.

ASYNC, SUBTREEP, and VISIBLE-ONLY are passed to
`org-ppt-export-to-pptx'."
  (interactive)
  (let ((outfile (org-ppt-export-to-pptx async subtreep visible-only)))
    (when outfile
      (org-open-file outfile))))

;;; Custom Tree Transcoder

(defun org-ppt--transcode-contents (contents info)
  "Transcode CONTENTS using our transcoders without string concatenation.
CONTENTS is a list of org elements, INFO is the export plist."
  (when contents
    ;; Set flag to indicate we're using custom transcoding
    (let ((info (plist-put (copy-sequence info) :ppt-custom-transcode t)))
      (mapcar (lambda (element)
                (org-ppt--transcode-element element info))
              contents))))

(defun org-ppt--transcode-element (element info)
  "Transcode a single ELEMENT using INFO."
  (let ((type (org-element-type element)))
    (cond
     ;; Strings (plain text)
     ((stringp element)
      (org-ppt-plain-text element info))
     
     ;; Elements
     ((eq type 'paragraph)
      (let ((contents (org-ppt--transcode-contents
                       (org-element-contents element)
                       info)))
        (org-ppt-paragraph element contents info)))
     
     ((eq type 'bold)
      (let ((contents (org-ppt--transcode-contents
                       (org-element-contents element)
                       info)))
        (org-ppt-bold element contents info)))
     
     ((eq type 'italic)
      (let ((contents (org-ppt--transcode-contents
                       (org-element-contents element)
                       info)))
        (org-ppt-italic element contents info)))
     
     ((eq type 'underline)
      (let ((contents (org-ppt--transcode-contents
                       (org-element-contents element)
                       info)))
        (org-ppt-underline element contents info)))
     
     ((eq type 'code)
      (org-ppt-code element nil info))
     
     ((eq type 'verbatim)
      (org-ppt-verbatim element nil info))
     
     ((eq type 'plain-list)
      (let ((contents (org-ppt--transcode-contents
                       (org-element-contents element)
                       info)))
        (org-ppt-plain-list element contents info)))
     
     ((eq type 'item)
      (let ((contents (org-ppt--transcode-contents
                       (org-element-contents element)
                       info)))
        (org-ppt-item element contents info)))
     
     ((eq type 'section)
      (let ((contents (org-ppt--transcode-contents
                       (org-element-contents element)
                       info)))
        (org-ppt-section element contents info)))
     
     ;; Unsupported types - return nil
     (t nil))))

(provide 'ox-ppt)
;;; ox-ppt.el ends here


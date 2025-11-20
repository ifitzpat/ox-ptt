;;; ox-ppt-shapes.el --- Shape and slide generation for ox-ppt -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;;; Commentary:

;; Functions to generate PPTX slides and shapes:
;; - Title slides
;; - Content slides
;; - Text boxes
;; - DrawingML shapes

;;; Code:

(require 'esxml)
(require 'ox-ppt-utils)

;;; Slide Generation

(defun org-ppt--make-title-slide (info)
  "Create title slide from INFO plist."
  (let ((title (org-ppt--get-title info))
        (subtitle (org-ppt--get-subtitle info))
        (author (org-ppt--get-author info)))
    (org-ppt--make-slide-xml
     (org-ppt--make-title-shapes title subtitle author))))

(defun org-ppt--make-content-slide (headline info)
  "Create content slide from HEADLINE and INFO."
  (let ((title (org-ppt--headline-title headline))
        (content (org-export-data
                  (org-element-contents headline)
                  info)))
    (org-ppt--make-slide-xml
     (org-ppt--make-content-shapes title content))))

;;; Slide XML Structure

(defun org-ppt--make-slide-xml (shapes)
  "Create slide XML with SHAPES."
  `(p:sld ((xmlns:a . "http://schemas.openxmlformats.org/drawingml/2006/main")
           (xmlns:r . "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
           (xmlns:p . "http://schemas.openxmlformats.org/presentationml/2006/main"))
     (p:cSld ()
       (p:spTree ()
         (p:nvGrpSpPr ()
           (p:cNvPr ((id . "1") (name . "")))
           (p:cNvGrpSpPr ())
           (p:nvPr ()))
         (p:grpSpPr ()
           (a:xfrm ()
             (a:off ((x . "0") (y . "0")))
             (a:ext ((cx . "0") (cy . "0")))
             (a:chOff ((x . "0") (y . "0")))
             (a:chExt ((cx . "0") (cy . "0")))))
         ,@shapes))
     (p:clrMapOvr ()
       (a:masterClrMapping ()))))

(defun org-ppt--make-slide-rels-xml (slide-num)
  "Create slide relationships XML for slide SLIDE-NUM."
  `(Relationships ((xmlns . "http://schemas.openxmlformats.org/package/2006/relationships"))
     (Relationship ((Id . "rId1")
                    (Type . "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout")
                    (Target . "../slideLayouts/slideLayout1.xml")))))

;;; Shape Generation

(defun org-ppt--make-title-shapes (title subtitle author)
  "Create shapes for title slide with TITLE, SUBTITLE, and AUTHOR."
  (list
   (org-ppt--make-text-box
    2 914400 914400 7315200 1828800
    title 44)
   (when subtitle
     (org-ppt--make-text-box
      3 914400 2743200 7315200 914400
      subtitle 32))
   (when author
     (org-ppt--make-text-box
      4 914400 5486400 7315200 914400
      author 20))))

(defun org-ppt--make-content-shapes (title content)
  "Create shapes for content slide with TITLE and CONTENT."
  (list
   (org-ppt--make-text-box
    2 914400 457200 7315200 914400
    title 32)
   (org-ppt--make-text-box
    3 914400 1600200 7315200 4572000
    content 18)))

;;; Text Box Generation

(defun org-ppt--make-text-box (id x y cx cy text size)
  "Create text box shape.
ID is shape ID, X Y are position, CX CY are dimensions.
TEXT is content, SIZE is font size in points."
  `(p:sp ()
     ,(org-ppt--make-shape-nvprops id (format "TextBox %d" id))
     ,(org-ppt--make-shape-props x y cx cy)
     ,(org-ppt--make-text-body text size)))

(defun org-ppt--make-shape-nvprops (id name)
  "Create non-visual shape properties with ID and NAME."
  `(p:nvSpPr ()
     (p:cNvPr ((id . ,(format "%d" id))
               (name . ,name)))
     (p:cNvSpPr ((txBox . "1")))
     (p:nvPr ())))

(defun org-ppt--make-shape-props (x y cx cy)
  "Create shape properties with position X Y and size CX CY."
  `(p:spPr ()
     (a:xfrm ()
       (a:off ((x . ,(format "%d" x))
               (y . ,(format "%d" y))))
       (a:ext ((cx . ,(format "%d" cx))
               (cy . ,(format "%d" cy)))))
     (a:prstGeom ((prst . "rect"))
       (a:avLst ()))))

(defun org-ppt--make-text-body (text size)
  "Create text body with TEXT at font SIZE (points)."
  `(p:txBody ()
     (a:bodyPr ((wrap . "square")
                (rtlCol . "0")))
     (a:lstStyle ())
     (a:p ()
       ,(org-ppt--make-paragraph-props)
       ,(org-ppt--make-text-run text size)
       (a:endParaRPr ((lang . "en-US"))))))

(defun org-ppt--make-paragraph-props ()
  "Create paragraph properties."
  `(a:pPr ((algn . "ctr"))))

(defun org-ppt--make-text-run (text size)
  "Create text run with TEXT at SIZE points."
  (let ((size-emu (* size 100)))
    `(a:r ()
       (a:rPr ((lang . "en-US")
               (sz . ,(format "%d" size-emu)))
         (a:solidFill ()
           (a:srgbClr ((val . "000000")))))
       (a:t ,(org-ppt--escape-xml text)))))

(provide 'ox-ppt-shapes)
;;; ox-ppt-shapes.el ends here

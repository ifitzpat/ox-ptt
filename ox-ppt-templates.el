;;; ox-ppt-templates.el --- PPTX static file templates -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;;; Commentary:

;; Functions to generate static PPTX XML files including:
;; - [Content_Types].xml
;; - Relationship files (.rels)
;; - Presentation structure
;; - Master slides and layouts
;; - Theme definitions

;;; Code:

(require 'esxml)

;;; [Content_Types].xml

(defun org-ppt--content-types-xml (num-slides)
  "Generate [Content_Types].xml for NUM-SLIDES slides."
  `(Types ((xmlns . "http://schemas.openxmlformats.org/package/2006/content-types"))
     (Default ((Extension . "rels")
               (ContentType . "application/vnd.openxmlformats-package.relationships+xml")))
     (Default ((Extension . "xml")
               (ContentType . "application/xml")))
     (Override ((PartName . "/ppt/presentation.xml")
                (ContentType . "application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml")))
     (Override ((PartName . "/ppt/slideMasters/slideMaster1.xml")
                (ContentType . "application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml")))
     (Override ((PartName . "/ppt/slideLayouts/slideLayout1.xml")
                (ContentType . "application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml")))
     (Override ((PartName . "/ppt/theme/theme1.xml")
                (ContentType . "application/vnd.openxmlformats-officedocument.theme+xml")))
     ,@(mapcar (lambda (n)
                 `(Override ((PartName . ,(format "/ppt/slides/slide%d.xml" n))
                            (ContentType . "application/vnd.openxmlformats-officedocument.presentationml.slide+xml"))))
               (number-sequence 1 num-slides))))

;;; Package Relationships

(defun org-ppt--package-rels-xml ()
  "Generate _rels/.rels file."
  `(Relationships ((xmlns . "http://schemas.openxmlformats.org/package/2006/relationships"))
     (Relationship ((Id . "rId1")
                    (Type . "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument")
                    (Target . "ppt/presentation.xml")))))

;;; Presentation XML

(defun org-ppt--presentation-xml (num-slides)
  "Generate ppt/presentation.xml for NUM-SLIDES slides."
  `(p:presentation ((xmlns:a . "http://schemas.openxmlformats.org/drawingml/2006/main")
                    (xmlns:r . "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
                    (xmlns:p . "http://schemas.openxmlformats.org/presentationml/2006/main"))
     (p:sldMasterIdLst ()
       (p:sldMasterId ((id . "2147483648")
                       (r:id . "rId1"))))
     (p:sldIdLst ()
       ,@(mapcar (lambda (n)
                   `(p:sldId ((id . ,(format "%d" (+ 256 n)))
                             (r:id . ,(format "rId%d" (+ 1 n))))))
                 (number-sequence 1 num-slides)))
     (p:sldSz ((cx . "9144000")
               (cy . "6858000")))
     (p:notesSz ((cx . "6858000")
                 (cy . "9144000")))))

;;; Presentation Relationships

(defun org-ppt--presentation-rels-xml (num-slides)
  "Generate ppt/_rels/presentation.xml.rels for NUM-SLIDES slides."
  `(Relationships ((xmlns . "http://schemas.openxmlformats.org/package/2006/relationships"))
     (Relationship ((Id . "rId1")
                    (Type . "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster")
                    (Target . "slideMasters/slideMaster1.xml")))
     ,@(mapcar (lambda (n)
                 `(Relationship ((Id . ,(format "rId%d" (+ 1 n)))
                                (Type . "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide")
                                (Target . ,(format "slides/slide%d.xml" n)))))
               (number-sequence 1 num-slides))))

;;; Slide Master

(defun org-ppt--slide-master-xml ()
  "Generate ppt/slideMasters/slideMaster1.xml."
  `(p:sldMaster ((xmlns:a . "http://schemas.openxmlformats.org/drawingml/2006/main")
                 (xmlns:r . "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
                 (xmlns:p . "http://schemas.openxmlformats.org/presentationml/2006/main"))
     (p:cSld ((name . "Office Theme"))
       (p:bg ()
         (p:bgRef ((idx . "1001"))
           (a:schemeClr ((val . "bg1")))))
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
             (a:chExt ((cx . "0") (cy . "0")))))))
     (p:clrMap ((bg1 . "lt1")
                (tx1 . "dk1")
                (bg2 . "lt2")
                (tx2 . "dk2")
                (accent1 . "accent1")
                (accent2 . "accent2")
                (accent3 . "accent3")
                (accent4 . "accent4")
                (accent5 . "accent5")
                (accent6 . "accent6")
                (hlink . "hlink")
                (folHlink . "folHlink")))
     (p:sldLayoutIdLst ()
       (p:sldLayoutId ((id . "2147483649")
                       (r:id . "rId1"))))))

(defun org-ppt--slide-master-rels-xml ()
  "Generate ppt/slideMasters/_rels/slideMaster1.xml.rels."
  `(Relationships ((xmlns . "http://schemas.openxmlformats.org/package/2006/relationships"))
     (Relationship ((Id . "rId1")
                    (Type . "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout")
                    (Target . "../slideLayouts/slideLayout1.xml")))
     (Relationship ((Id . "rId2")
                    (Type . "http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme")
                    (Target . "../theme/theme1.xml")))))

;;; Slide Layout

(defun org-ppt--slide-layout-xml ()
  "Generate ppt/slideLayouts/slideLayout1.xml."
  `(p:sldLayout ((xmlns:a . "http://schemas.openxmlformats.org/drawingml/2006/main")
                 (xmlns:r . "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
                 (xmlns:p . "http://schemas.openxmlformats.org/presentationml/2006/main")
                 (type . "blank")
                 (preserve . "1"))
     (p:cSld ((name . "Blank"))
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
             (a:chExt ((cx . "0") (cy . "0")))))))
     (p:clrMapOvr ()
       (a:masterClrMapping ()))))

(defun org-ppt--slide-layout-rels-xml ()
  "Generate ppt/slideLayouts/_rels/slideLayout1.xml.rels."
  `(Relationships ((xmlns . "http://schemas.openxmlformats.org/package/2006/relationships"))
     (Relationship ((Id . "rId1")
                    (Type . "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster")
                    (Target . "../slideMasters/slideMaster1.xml")))))

;;; Theme

(defun org-ppt--theme-xml ()
  "Generate ppt/theme/theme1.xml with minimal theme."
  `(a:theme ((xmlns:a . "http://schemas.openxmlformats.org/drawingml/2006/main")
             (name . "Office Theme"))
     (a:themeElements ()
       (a:clrScheme ((name . "Office"))
         (a:dk1 () (a:sysClr ((val . "windowText") (lastClr . "000000"))))
         (a:lt1 () (a:sysClr ((val . "window") (lastClr . "FFFFFF"))))
         (a:dk2 () (a:srgbClr ((val . "44546A"))))
         (a:lt2 () (a:srgbClr ((val . "E7E6E6"))))
         (a:accent1 () (a:srgbClr ((val . "4472C4"))))
         (a:accent2 () (a:srgbClr ((val . "ED7D31"))))
         (a:accent3 () (a:srgbClr ((val . "A5A5A5"))))
         (a:accent4 () (a:srgbClr ((val . "FFC000"))))
         (a:accent5 () (a:srgbClr ((val . "5B9BD5"))))
         (a:accent6 () (a:srgbClr ((val . "70AD47"))))
         (a:hlink () (a:srgbClr ((val . "0563C1"))))
         (a:folHlink () (a:srgbClr ((val . "954F72")))))
       (a:fontScheme ((name . "Office"))
         (a:majorFont ()
           (a:latin ((typeface . "Calibri Light") (panose . "020F0302020204030204")))
           (a:ea ((typeface . "")))
           (a:cs ((typeface . ""))))
         (a:minorFont ()
           (a:latin ((typeface . "Calibri") (panose . "020F0502020204030204")))
           (a:ea ((typeface . "")))
           (a:cs ((typeface . "")))))
       (a:fmtScheme ((name . "Office"))
         (a:fillStyleLst ()
           (a:solidFill () (a:schemeClr ((val . "phClr"))))
           (a:gradFill ((rotWithShape . "1"))
             (a:gsLst ()
               (a:gs ((pos . "0")) (a:schemeClr ((val . "phClr")) (a:lumMod ((val . "110000"))) (a:satMod ((val . "105000"))) (a:tint ((val . "67000")))))
               (a:gs ((pos . "50000")) (a:schemeClr ((val . "phClr")) (a:lumMod ((val . "105000"))) (a:satMod ((val . "103000"))) (a:tint ((val . "73000")))))
               (a:gs ((pos . "100000")) (a:schemeClr ((val . "phClr")) (a:lumMod ((val . "105000"))) (a:satMod ((val . "109000"))) (a:tint ((val . "81000"))))))
           (a:lin ((ang . "5400000") (scaled . "0"))))
           (a:gradFill ((rotWithShape . "1"))
             (a:gsLst ()
               (a:gs ((pos . "0")) (a:schemeClr ((val . "phClr")) (a:satMod ((val . "103000"))) (a:lumMod ((val . "102000"))) (a:tint ((val . "94000")))))
               (a:gs ((pos . "50000")) (a:schemeClr ((val . "phClr")) (a:satMod ((val . "110000"))) (a:lumMod ((val . "100000"))) (a:shade ((val . "100000")))))
               (a:gs ((pos . "100000")) (a:schemeClr ((val . "phClr")) (a:lumMod ((val . "99000"))) (a:satMod ((val . "120000"))) (a:shade ((val . "78000"))))))
             (a:lin ((ang . "5400000") (scaled . "0")))))
         (a:lnStyleLst ()
           (a:ln ((w . "6350") (cap . "flat") (cmpd . "sng") (algn . "ctr"))
             (a:solidFill () (a:schemeClr ((val . "phClr"))))
             (a:prstDash ((val . "solid")))
             (a:miter ((lim . "800000"))))
           (a:ln ((w . "12700") (cap . "flat") (cmpd . "sng") (algn . "ctr"))
             (a:solidFill () (a:schemeClr ((val . "phClr"))))
             (a:prstDash ((val . "solid")))
             (a:miter ((lim . "800000"))))
           (a:ln ((w . "19050") (cap . "flat") (cmpd . "sng") (algn . "ctr"))
             (a:solidFill () (a:schemeClr ((val . "phClr"))))
             (a:prstDash ((val . "solid")))
             (a:miter ((lim . "800000")))))
         (a:effectStyleLst ()
           (a:effectStyle ())
           (a:effectStyle ())
           (a:effectStyle ()))
         (a:bgFillStyleLst ()
           (a:solidFill () (a:schemeClr ((val . "phClr"))))
           (a:solidFill () (a:schemeClr ((val . "phClr")) (a:tint ((val . "95000"))) (a:satMod ((val . "170000")))))
           (a:gradFill ((rotWithShape . "1"))
             (a:gsLst ()
               (a:gs ((pos . "0")) (a:schemeClr ((val . "phClr")) (a:tint ((val . "93000"))) (a:satMod ((val . "150000"))) (a:shade ((val . "98000"))) (a:lumMod ((val . "102000")))))
               (a:gs ((pos . "50000")) (a:schemeClr ((val . "phClr")) (a:tint ((val . "98000"))) (a:satMod ((val . "130000"))) (a:shade ((val . "90000"))) (a:lumMod ((val . "103000")))))
               (a:gs ((pos . "100000")) (a:schemeClr ((val . "phClr")) (a:shade ((val . "63000"))) (a:satMod ((val . "120000"))))))
             (a:lin ((ang . "5400000") (scaled . "0")))))))
     (a:objectDefaults ())
     (a:extraClrSchemeLst ())))))

(provide 'ox-ppt-templates)
;;; ox-ppt-templates.el ends here

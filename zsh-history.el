;;; zsh-history.el --- Zsh history file encoder/decoder  -*- lexical-binding: t; -*-

;; Filename: zsh-history.el
;; Description: Zsh history file encoder/decoder.
;; Author: KAWABATA, Taichi <kawabata.taichi_at_gmail.com>
;; Created: 2010-01-01
;; Version: 1.231122
;; Keywords: i18n
;; Human-Keywords: Zsh
;; URL: https://github.com/kawabata/emacs-zsh-history
;; Package-Requires: ((emacs "24.1"))

;;; Commentary:

;; This is a tiny tool to encode/decode Z-shell history file.
;;
;; In zsh history file, some functional bytes are escaped with meta
;; character. As of it, non-ascii texts in history file are sometimes
;; undecipherable.
;;
;; According to `init.c' of zsh, followings are meta characters.
;;
;; - 0x00, 0x83(Meta), 0x84(Pound)-0x9d(Nularg), 0xa0(Marker)
;;
;; For these bytes, 0x83(Meta) is preceded and target byte is `xor'ed
;; with 0x20.
;;
;; This file provides encoder and decoder for these bytes, so that
;; UTF-8 string in history file can be handled in Emacs.

;;; Code:

(defvar zsh-history-coding-system 'utf-8
  "Base coding system of zsh history file.")

(define-ccl-program zsh-history--meta-decoder
  '(1 ((loop
        (read-if (r0 == #x83)
                 ((read r0) (r0 ^= #x20)))
        ;; write back bytes, so you need to (actually) decode them later.
        (write r0)
        (repeat))))
  "The CCL program for stripping Meta escape characters from zsh_history.")

(define-ccl-program zsh-history--meta-encoder
  '(2 ((loop
        ;; it reads raw bytes, so you need to encode characters beforehand.
        (read r0)
        (r1 = (r0 < #x9e))
        (r2 = (r0 == #xa0))
        (if (((r0 > #x82) & r1) | r2)
            ((write #x83) (write (r0 ^ #x20)))
          (write r0))
        (repeat))))
  "The CCL program for encoding Meta escape characters in zsh_history.")

;; Workaround multibyte conversion for high-8-bit ASCII characters
(let ((table
       (make-translation-table-from-vector (vconcat (number-sequence 0 127) (number-sequence (+ 128 #x3FFF00) (+ 255 #x3FFF00))))))
  (define-translation-table 'zsh-history--raw-byte-encode table)
  (define-translation-table 'zsh-history--raw-byte-revert (char-table-extra-slot table 0)))

(defun zsh-history--post-meta-decode (len)
  "Decode region as speicified coding system from current point to LEN.
This is intended to be used after the CCL program done the meta processing."
  (decode-coding-region (point) (+ (point) len) zsh-history-coding-system))

(defun zsh-history--pre-meta-encode (_ignore _ignore2)
  "Encode buffer before the CCL program. _IGNORE ad _IGNORE2 are ignored."
  (encode-coding-region (point-min) (point-max) zsh-history-coding-system)
  ;; Restore `last-coding-system-used' so that `basic-save-buffer' does not
  ;; override `buffer-file-coding-system' accidentally.
  (setq last-coding-system-used 'zsh-history))

(define-coding-system 'zsh-history
  "The coding system used by zsh_history files.

ZSH will escape characters considered META internally. The
zsh_history file is also written with its internal coding.

The following are all META characters:
 0x00, 0x83(Meta), 0x84(Pound)-0x9d(Nularg), 0xa0(Marker)
For these bytes, 0x83(Meta) is preceded and target byte is
`logxor'ed with 0x20."
  :coding-type 'ccl
  :charset-list '(unicode)
  :mnemonic ?Z :ascii-compatible-p 't
  :eol-type 'unix
  :ccl-decoder 'zsh-history--meta-decoder
  :decode-translation-table 'zsh-history--raw-byte-encode
  :post-read-conversion 'zsh-history--post-meta-decode
  :ccl-encoder 'zsh-history--meta-encoder
  :encode-translation-table 'zsh-history--raw-byte-revert
  :pre-write-conversion 'zsh-history--pre-meta-encode)

;; declare to use this encoder/decoder for zsh_history file.
(modify-coding-system-alist 'file "zsh_history" 'zsh-history)

(provide 'zsh-history)

;;; zsh-history.el ends here

;; Local Variables:
;; time-stamp-pattern: "10/Version:\\\\?[ \t]+1.%02y%02m%02d\\\\?\n"
;; End:

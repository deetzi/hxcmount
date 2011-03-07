
; charinfo
                    rsset   0
_char_pixAddr:      rs.l    1
_char_w:            rs.w    1
_char_h             rs.w    1
_char_xoffset:      rs.w    1
_char_yoffset:      rs.w    1
_char_xadvance:     rs.w    1
_char_kernNb:       rs.w    1
_char_kernAddr:     rs.l    1
_char_rsLength:     rs.l    0

; fontinfo
                    rsset   0
_font_nameAddr:     rs.l    1
_font_isBold:       rs.b    1
_font_isItalic      rs.b    1
_font_size:         rs.w    1
_font_lineHeight:   rs.w    1
_font_lineBase:     rs.w    1
_font_rsLength:     rs.l    0


; targetinfo
                    rsset   0
_tar_addr:          rs.l    1
_tar_x:             rs.w    1
_tar_y:             rs.w    1
_tar_bitplanes:     rs.w    1
_tar_lineLen:       rs.w    1
_tar_boxX:          rs.w    1
_tar_boxY:          rs.w    1
_tar_boxW:          rs.w    1
_tar_boxH:          rs.w    1
_tar_fScroll        rs.b    1                               ;can scroll
                    rseven
_tar_rsLength:      rs.l    0


;
;  Speed-optimized LZSA decompressor by spke (v.1 23-24/04/2019, 134 bytes)
;
;  The data must be comressed using the command line compressor by Emmanuel Marty
;  The compression is done as follows:
;
;  lzsa.exe -r <sourcefile> <outfile>
;
;  where option -r asks for the generation of raw (frame-less) data.
;
;  The decompression is done in the standard way:
;
;  ld hl,CompressedData
;  ld de,WhereToDecompress
;  call DecompressLZSA
;
;  Of course, LZSA compression algorithm is (c) 2019 Emmanuel Marty,
;  see https://github.com/emmanuel-marty/lzsa for more information
;
;  Drop me an email if you have any comments/ideas/suggestions: zxintrospec@gmail.com
;
;
;  This software is provided 'as-is', without any express or implied
;  warranty.  In no event will the authors be held liable for any damages
;  arising from the use of this software.
;
;  Permission is granted to anyone to use this software for any purpose,
;  including commercial applications, and to alter it and redistribute it
;  freely, subject to the following restrictions:
;
;  1. The origin of this software must not be misrepresented; you must not
;     claim that you wrote the original software. If you use this software
;     in a product, an acknowledgment in the product documentation would be
;     appreciated but is not required.
;  2. Altered source versions must be plainly marked as such, and must not be
;     misrepresented as being the original software.
;  3. This notice may not be removed or altered from any source distribution.
;

@DecompressLZSA:
		ld b,0 : jr ReadToken

MoreLiterals:	; there are three possible situations here
		xor (hl) : inc hl : exa
		ld a,7 : add (hl) : inc hl : jr c,ManyLiterals

CopyLiterals:	ld c,a
.UseC		ldir

		push de : ld e,(hl) : inc hl : exa : jp m,LongOffset
		ld d,#FF : add 3 : cp 15+3 : jp c,CopyMatch
		jr LongerMatch

ManyLiterals:
.code1		ld b,a : ld c,(hl) : inc hl : jr nz,CopyLiterals.UseC
.code0		ld b,(hl) : inc hl : jr CopyLiterals.UseC
		
NoLiterals:	xor (hl) : inc hl
		push de : ld e,(hl) : inc hl : jp m,LongOffset
		ld d,#FF : add 3 : cp 15+3 : jr nc,LongerMatch

		; placed here this saves a JP per iteration
CopyMatch:	ld c,a
.UseC		ex (sp),hl : push hl						; BC = len, DE = offset, HL = dest, SP ->[dest,src]
		add hl,de : pop de						; BC = len, DE = dest, HL = dest-offset, SP->[src]
		ldir : pop hl							; BC = 0, DE = dest, HL = src
	
ReadToken:	; first a byte token "O|LLL|MMMM" is read from the stream,
		; where LLL is the number of literals and MMMM is
		; a length of the match that follows after the literals
		ld a,(hl) : and #70 : jr z,NoLiterals

		cp #70 : jr z,MoreLiterals					; LLL=7 means 7+ literals...
		rrca : rrca : rrca : rrca					; LLL<7 means 0..6 literals...

		ld c,a : ld a,(hl) : inc hl
		ldir

		; next we read the first byte of the offset
		push de : ld e,(hl) : inc hl
		; the top bit of token is set if the offset contains two bytes
		and #8F : jp m,LongOffset

ShortOffset:	ld d,#FF

		; short matches have length 0+3..14+3
ReadMatchLen:	add 3 : cp 15+3 : jp c,CopyMatch

		; MMMM=15 indicates a multi-byte number of literals
LongerMatch:	add (hl) : inc hl : jr nc,CopyMatch

		; the codes are designed to overflow;
		; the overflow value 1 means read 1 extra byte
		; and overflow value 0 means read 2 extra bytes
.code1		ld b,a : ld c,(hl) : inc hl : jr nz,CopyMatch.UseC
.code0		ld b,(hl) : inc hl

		; the two-byte match length equal to zero
		; designates the end-of-data marker
		ld a,b : or c : jr nz,CopyMatch.UseC
		pop de : ret

LongOffset:	; read second byte of the offset
		ld d,(hl) : inc hl
		add -128+3 : cp 15+3 : jp c,CopyMatch
		add (hl) : inc hl : jr nc,CopyMatch
		jr LongerMatch.code1



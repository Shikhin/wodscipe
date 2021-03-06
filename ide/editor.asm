; The editor.
; IN:
;	BX -> 0x8000.
;	AX -> 2
;	DI -> 0
editor:
	.loadsource:
		lea bp, [bx + 2] ; Current start-of-line
		mov dx, bp
		add dx, [bx]

	.rw_source:
		push bx
		.writeloop:
			call rwsector

			inc ax
			add bx, 0x200
			cmp bx, dx
			jb .writeloop

		pop bx

	.mainloop:
		; Input buffer.
		mov di, 0x504
		; 80 characters (most probably width of current mode's line, mode 03)
		mov cx, 0x50
		call getline

		cmp al, 1
		jb .cmdnext
		je .checkcmd

		.gotoline:
			mov si, di
			xor ax, ax

			.atoi:
				lodsb
				test al, al
				jz .gotosetup

				sub al, '0'
				cmp al, 9
				ja .error

				aad
				xchg ah, al
				jmp .atoi

			.gotosetup:
				mov bp, 0x8002

				movzx cx, ah
				jcxz .error
				dec cx
			.gotoloop:
				jcxz .cmdprint
				call next_newline
				mov bp, si
				dec cx
				jmp .gotoloop

	.error:
		mov si, .errormsg
		call puts
		jmp .mainloop

	.errormsg: db '?', 10, 0

		.checkcmd:
			mov al, [di]

		.insert:
			cmp al, 'i'
			jne .append
			; Insert
			.cmdinsert:
				; cx & di already set above
				call getline
				inc ax

				push di

				; Get bytes following bp = last "address" - bp.
				mov cx, dx
				sub cx, bp

				; Copy from BP to (BP + AX), but reversed (as overlap).
				mov si, bp
				add si, cx
				mov di, si
				add di, ax

				inc cx

				std
				rep movsb
				cld

				; Copy from input buffer to BP, the new line.
				pop si
				mov di, bp
				mov cx, ax

				rep movsb

				; Update file length.
				add [bx], ax
				add dx, ax

				mov byte [di - 1], 10
				xor al, al

		.append:
			cmp al, 'a'
			jne .delete
			; Append
			.cmdappend:
				; Go to next line, and insert before that.
				call next_newline
				mov bp, si
				jmp .cmdinsert

		.delete:
			cmp al, 'd'
			jne .print
			; Delete
			.cmddelete:
				; Find next newline.
				call next_newline

				; Get number of bytes from next line to end.
				mov cx, dx
				sub cx, si

				; Remove size of current line from [bx].
				sub [bx], si
				add [bx], bp
				sub dx, si
				add dx, bp

				mov di, bp
				rep movsb

				call prev_newline
				xor al, al

		.print:
			cmp al, 'p'
			jne .write
			; Print
			.cmdprint:
				; Get next line.
				call next_newline

				; Put a null-terminator at beginning of next line.
				xor al, al
				xchg [si], al

				; Print.
				xchg si, bp
				call puts

				; Restore character.
				xchg si, bp
				xchg [si], al

		.write:
			cmp al, 'w'
			jne .next
			; Write
			.cmdwrite:
				mov ax, 2
				mov di, 1 << 8
				jmp .rw_source

		.next:
			cmp al, '+'
			jne .last
			; Next
			.cmdnext:
				call next_newline
				cmp dx, si
				jz .error

				mov bp, si
				jmp .cmdprint

		.last:
			cmp al, '$'
			jne .previous
			; Last
			.cmdlast:
				; Find the previous line from EOF.
				mov bp, dx
				jmp .cmdprevious

		.previous:
			cmp al, '-'
			jne .list
			; Previous
			.cmdprevious:
				cmp bp, 0x8002
				je .error

				call prev_newline
				jmp .cmdprint

		.list:
			cmp al, 'l'
			jne .run
			; List
			.cmdlist:
				lea si, [bx + 2]
				mov cx, [bx]
				jcxz .listed

				.loop:
					lodsb
					call putchar
					loop .loop

				.listed:
					xor al, al

		.run:
			cmp al, 'r'
			jne .nomatch
			; Run
			.cmdrun:
				call interpreter

		.nomatch:
			test al, al
			jnz .gotoline
			jmp .mainloop

; Find previous line.
; IN:
;	BP -> buffer
; OUT:
;	BP -> previous line, or start of buffer
;	Trashes CX.
prev_newline:
	mov cx, bp
	mov bp, 0x8002

	.find_nextline:
		call next_newline
		cmp si, cx
		jae .ret

		mov bp, si
		jmp .find_nextline

	.ret:
		ret

; Find next line.
; IN:
;	BP -> buffer
; OUT:
;	SI -> next/previous line, or end/start of buffer
next_newline:
	mov si, bp
	.loop:
		; If reached start/end of buffer
		cmp dx, si
		jbe .end

		lodsb
		cmp al, 10
		jne .loop

	.end:
		ret

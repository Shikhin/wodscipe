%include "wodscipe.inc"
org 0x7E00

; Uncomment following line to enable NorttiSoft singlestepping BF debugger deluxe
;%define enable_debugger

free_space EQU 0x504

%macro debugger 0
	; Current IP
	mov ax, si
	call hexprint16
	mov al, ' '
	call putchar

	; Current command
	mov al, [si]
	call putchar
	mov al, ' '
	call putchar

	; Current tape pointer
	mov ax, bp
	call hexprint16
	mov al, ' '
	call putchar

	; Current tabe symbol
	mov al, [es:bp]
	call hexprint8
	mov al, 10
	call putchar

	; Wait for keypress
	call getch
%endmacro

start:
	pusha
	push es

	mov [free_space], sp
	mov ax, 0x2000
	mov ss, ax
	xor sp, sp

	; Tape & tape pointer
	mov ax, 0x1000
	mov es, ax
	xor bp, bp

	; Zero tape
	xor di, di
	mov cx, 0xFFFF
	xor al, al
	rep stosb

	; SI points to source, DI to end.
	lea si, [bx + 2]
	mov di, si
	add di, [bx]

	call interpret

	xor ax, ax
	mov ss, ax
	mov sp, [free_space]

	pop es
	popa
	xor al, al
	ret

interpret:
	cmp si, di
	je .end

	%ifdef enable_debugger
		debugger
	%endif

	lodsb

	.inc:
		cmp al, '+'
		jne .dec

		inc byte [es:bp]

		jmp interpret
	.dec:
		cmp al, '-'
		jne .next

		dec byte [es:bp]

		jmp interpret
	.next:
		cmp al, '>'
		jne .prev

		inc bp

		jmp interpret
	.prev:
		cmp al, '<'
		jne .putchar

		dec bp

		jmp interpret
	.putchar:
		cmp al, '.'
		jne .getchar

		mov al, [es:bp]
		call putchar

		jmp interpret
	.getchar:
		cmp al, ','
		jne .while

		call getch
		call putchar
		cmp al, 04
		jne .not_eof

		.eof:
			xor al, al
		.not_eof:
			mov [es:bp], al

		jmp interpret
	.while:
		cmp al, '['
		jne .wend

		; Handle loop nesting by recursion inside a loop
		.loop:
			cmp byte [es:bp], 0
			je .skip

			push si
			call interpret
			pop si

			jmp .loop
		.skip:
			; Skip after the loop(s). Needed because si is returned to same point where it left
			mov cx, 1

			.skiploop:
				lodsb

				cmp al, ']'
				je .shallower
				cmp al, '['
				je .deeper

				jmp .skiploop

				.deeper:
					inc cx
					jmp .skiploop
				.shallower:
					dec cx
					jnz .skiploop

			jmp interpret

	.wend:
		cmp al, ']'
		jne interpret

		; Fall through.
	.end:
		ret

%ifdef enable_debugger
	%include "hexprint.inc"
%endif

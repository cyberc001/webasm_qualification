# Modified:	2021 Jan 3 10:55
# Author:	cyberc001
# Description:
# Test program for securing qualification for a collaborative "web assembly and debugger" project.
# Gets reasonably large amount of strings as input (amount of characters in a text is limited to stack space,
# amount of characters in a single line is limited to internal buffer size, which is buf_sz, or 256 ascii characters).
# Another limitation is line and column numbers and line lengths (all numbers are limited to 6 digits).
# The program also works for texts which lines have variable length, and treats absence of a symbol as a '0' character (can be easily changed).

.bss

.set  		 buf_sz, 		256		#input data buffer size (bytes)
.set		 zero_beg_buf_sz,	2048		#zero line indexes buffer (qwords)
 buf: 		.skip buf_sz 				#input data buffer
 arr_sz:	.skip 8					#string array size (count of subarrays)
 zero_buf:	.skip buf_sz				#buffer of zeroes that were presented in previous lines
 zero_beg_buf:	.skip zero_beg_buf_sz			#buffer of line indexes of zeroes

.data

 line_msg:	.ascii "line:000000 col:000000 length:000000\n\0"	#line information message for usage in print_line_info function
 line_msg_end:	line_msg_ln = (line_msg_end - line_msg)			#line information length in bytes


.text

.global _start

_start:

	mov	$arr_sz,	%rdi
	movq	$0,		(%rdi)		#this variable will store the count of subarrays
	mov	%rsp,		%rbp		#setting a stack base pointer

	input:
	# input of another array
	mov 	$0,   		%rax		#sysread()
	mov 	$0,   		%rdi		#stdin
	mov 	$buf, 		%rsi		#buffer address
	mov 	$buf_sz, 	%rdx		#buffer size
	syscall

	# testing for EOF
	cmp 	$0, 		%rax 		#if bytes read == 0
	je 	process				#go to data processing stage

	# writing input buffer contents on stack
	subq	$8,		%rsp		#expanding stack by 8 bytes (qword)
	movq	%rax,		(%rsp)		#writing subarray size on stack
	sub	%rax,		%rsp		#expanding stack by amount of bytes read
	xor	%rbx,		%rbx		#rbx is used as a byte counter and buffer index
						#cl is used as a temporary byte buffer
	movq	$buf,		%rdx		#rdx is used as a temporary address buffer, for memory addressing
	stack_loop:
		movb	(%rdx,%rbx),	%cl			#storing a byte in register cl
		movb	%cl,		(%rsp,%rbx)		#writing a byte on stack
		incq	%rbx					#incrementing index
		cmp	%rax,		%rbx			#if index < buffer size
		jb	stack_loop				#continue writing

	mov	$arr_sz,	%rdi
	incq	(%rdi)				#incrementing subarray count by 1


	jmp	input				#get another input portion

	# processing data
	process:
						#rax is used as subarray size
	xor	%rcx,		%rcx		#rcx is used as array index (line, or subarray number)
	mov	%rbp,		%rsi		#rsi now points to stack base and thus to 1st array's size
	xor	%rdx,		%rdx		#rdx now keeps track of column number (and character)
	process_loop: # general processing loop
		subq	$8,		%rsi	#rsi now points to current subarray size
		mov	(%rsi),		%rax	#getting array size
		subq	%rax,		%rsi	#rsi now is points to current subarray's 1st element

		process_loop__find_zero: # looking for a zero
			mov	$zero_buf,	%rdi		#rdi now points to 1st zero buffer's element
			cmpb 	$0,		(%rdi, %rdx)	#if zero_buf[rdx] == 0 (was NOT zero)
			je 	wasnotzero

			waszero:
			cmpb	$48,		(%rsi, %rdx)	#if array[rbx] == '0'
			je waszero_foundzero
			waszero_notfoundzero:
			#end of a line: printing out
			mov	%rcx,		%rbx		#calculating line length and storing it in rbx
			mov	$zero_beg_buf,	%rdi
			sub	(%rdi, %rdx, 8),%rbx

			push	%rcx				#saving rcx to fill it with line's beginning line number

			movq	(%rdi, %rdx, 8),%rcx		#retrieving line no. from array

			call	print_line_info
			pop	%rcx				#restoring rcx

			mov	$zero_buf,	%rdi
			movb	$0,		(%rdi, %rdx)	#zero_buf[rdx] := 0 (was not zero)
			waszero_foundzero:
			# the number was zero and is zero now; skip
			jmp process_loop__find_zero__inc


			wasnotzero:
			cmpb	$48,		(%rsi, %rdx)	#if array[rdx] == '0'
			je	wasnotzero_foundzero
			wasnotzero_notfoundzero:
			# the number was not zero and is not zero now; skip
			jmp process_loop__find_zero__inc
			wasnotzero_foundzero:
			movb	$1,		(%rdi, %rdx)	#zero_buf[rdx] := 1 (was zero)
			mov	$zero_beg_buf,	%rdi		#rdi now points to 1st zero line index buffer's element
			movq	%rcx,		(%rdi, %rdx, 8)	#zero_beg_buf[rbx] := rcx (line/subarray number)

		process_loop__find_zero__inc:
			inc	%rdx				#rdx now shows next column number
			cmpb	$10,		(%rsi, %rdx)	#if array[rdx] != '\n' (if this character is not '\n')
			jne	process_loop__find_zero		#to next character
								# !!!else
			jmp 	process_loop__inc		#continuing with main loop

	process_loop__inc:
		inc	%rcx			#rcx now indexes the next subarray
		xor	%rdx,		%rdx	#rdx now shows 1st column
		mov 	$arr_sz,	%rdi	#rdi now points to array size
		cmp	(%rdi),		%rcx	#if rcx < array size
		jb	process_loop		#continue with the loop

	# looking to end any zero lines left
	xor	%rdx,			%rdx	#rdx starts indexing from 0
	cleanup_loop:
		mov	$zero_buf,	%rdi
		cmpb	$0,		(%rdi, %rdx)	#if zero_buf[rdx] == 0 (was NOT zero)
		je	cleanup_loop__inc		#continue with the loop
							# !!!else
		#printing line info
		mov	%rcx,		%rbx		#calculating line length
		mov	$zero_beg_buf,	%rdi
		sub	(%rdi, %rdx, 8),%rbx

		push	%rcx				#saving rcx to fill it with line number

		movq	(%rdi, %rdx, 8),%rcx		#retrieving line no. from array

		call 	print_line_info
		pop	%rcx

	cleanup_loop__inc:
		inc	%rdx				#indexing next zero buffer entry
		cmp	$buf_sz,	%rdx		#if rdx < buf_sz
		jb	cleanup_loop			#continue with the loop

	exit:
	# normal exit
	mov 	$60,		%rax		#exit()
	xor 	%rdi,		%rdi		#exit code 0
	syscall


# Function name: print_line_info
# Purpose: print information about a vertical line: line no., column no., and length.
# Arguments:
#	%rcx	line no.
#	%rdx	column no.
#	%rbx	line length
# Saved registers:
# 	%rax, %rbx, %rcx, %rdx, %rdi, %rsi
# Modified registers:
#	All of the above

print_line_info:
	push	%rax
	push	%rbx
	push	%rdi
	push	%rsi
	push	%rdx

	#modifying printed string

	#writing line number
	mov	$6,		%rbx
	mov	$line_msg,	%rdi
	xor	%rdx,		%rdx		#zeroing higher qword for division
	mov	%rcx,		%rax
	.lprint_loop__line:
		mov	$10,	%rsi		#diving line no. by 10
		idiv	%rsi
		addb	$48,	%dl
		movb	%dl,	4(%rdi, %rbx)	#writing quotent as a digit

		#setting next divider to current quotent
		xor	%rdx,	%rdx

		dec	%rbx
		cmp	$0,	%rbx
		jne	.lprint_loop__line

	#writing column number
	mov	$6,		%rbx
	xor	%rdx,		%rdx		#zeroing higher qword for division
	movq	(%rsp),		%rax		#restoring column no.
	.lprint_loop__col:
		mov	$10,	%rsi
		idiv	%rsi
		addb	$48,	%dl
		movb	%dl,	15(%rdi, %rbx)

		xor	%rdx,	%rdx

		dec	%rbx
		cmp	$0,	%rbx
		jne	.lprint_loop__col

	#writing line length
	mov	$6,		%rbx
	xor	%rdx,		%rdx		#zeroing higher qword for division
	movq	24(%rsp),	%rax		#restoring line length
	.lprint_loop__len:
		mov	$10,	%rsi
		idiv	%rsi
		addb	$48,	%dl
		movb	%dl,	29(%rdi, %rbx)

		xor	%rdx,	%rdx

		dec	%rbx
		cmp	$0,	%rbx
		jne	.lprint_loop__len


	mov	$1,		%rax	#syswrite()
	mov	$1,		%rdi	#stdout
	mov	$line_msg,	%rsi
	mov	$line_msg_ln,	%rdx
	syscall

	pop	%rdx
	pop	%rsi
	pop	%rdi
	pop	%rbx
	pop	%rax
	ret

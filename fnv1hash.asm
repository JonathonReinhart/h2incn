;
; FNV1HASH.ASM : FNV-1 Hash algorithm
; Author       : Rob Neff
;
; Copyright (C)2010 Piranha Designs, LLC - All rights reserved.
; Source code is licensed under the new/simplified 2-clause BSD OSI license.
;
; This function implements the FNV-1 hash algorithm.
; This source file is formatted for Nasm compatibility although it
; is small enough to be easily converted into another assembler format.
;
; Example C/C++ call:
;
; #ifdef __cplusplus
; extern "C" {
; #endif
;
; unsigned int FNV1Hash(char *buffer, unsigned int len, unsigned int offset_basis);
;
; #ifdef __cplusplus
; }
; #endif
;
; int hash;
;
; /* obtain 32-bit FNV1 hash */
; hash = FNV1Hash(buffer, len, 2166136261);
;
; /* if desired - convert from a 32-bit to 16-bit hash */
; hash = ((hash >> 16) ^ (hash & 0xFFFF));
;
; uncomment the following line to get FNV1A behavior

%define FNV1A 1

[section .text]

%ifidni __BITS__,32

;
; 32-bit C calling convention
;

%define buffer [ebp+8]
%define len [ebp+12]
%define offset_basis [ebp+16]

global _FNV1Hash

_FNV1Hash:
   push ebp                    ; set up stack frame
   mov  ebp, esp
   push esi                    ; save registers used
   push edi
   push ebx

   mov  esi, buffer            ; esi = ptr to buffer
   mov  ecx, len               ; ecx = length of buffer (counter)
   mov  eax, offset_basis      ; set to 2166136261 for FNV-1
   mov  edi, 1000193h          ; FNV_32_PRIME = 16777619
   xor  ebx, ebx               ; ebx = 0
nextbyte:
%ifdef FNV1A
   mov  bl, byte[esi]          ; bl = byte from esi
   xor  eax, ebx               ; al = al xor bl
   mul  edi                    ; eax = eax * FNV_32_PRIME
%else
   mul  edi                    ; eax = eax * FNV_32_PRIME
   mov  bl, byte[esi]          ; bl = byte from esi
   xor  eax, ebx               ; al = al xor bl
%endif
   inc  esi                    ; esi = esi + 1 (buffer pos)
   dec  ecx                    ; ecx = ecx - 1 (counter)
   jnz  nextbyte               ; if ecx != 0, jmp to nextbyte

   pop  ebx                    ; restore registers
   pop  edi
   pop  esi
   mov  esp, ebp               ; restore stack frame
   pop  ebp
   ret                         ; eax = fnv1 hash

%elifidni __BITS__,64

;
; 64-bit function
;

%ifidni __OUTPUT_FORMAT__,win64

;
; 64-bit Windows fastcall convention:
;    ints/longs/ptrs: RCX, RDX, R8, R9
;     floats/doubles: XMM0 to XMM3
;

global FNV1Hash

FNV1Hash:
   xchg rcx, rdx               ; rcx = length of buffer
   xchg r8, rdx                ; r8 = ptr to buffer

%elifidni __OUTPUT_FORMAT__,elf64

;
; 64-bit Linux fastcall convention
;    ints/longs/ptrs: RDI, RSI, RDX, RCX, R8, R9
;     floats/doubles: XMM0 to XMM7

global _FNV1Hash

_FNV1Hash:
   mov  rcx, rsi
   mov  r8, rdi

%endif

   mov  rax, rdx               ; rax = offset_basis - set to 14695981039346656037 for FNV-1
   mov  r9, 100000001B3h       ; r9 = FNV_64_PRIME = 1099511628211
   mov  r10, rbx               ; r10 = saved copy of rbx
   xor  rbx, rbx               ; rbx = 0
nextbyte:
%ifdef FNV1A
   mov  bl, byte[r8]           ; bl = byte from r8
   xor  rax, rbx               ; al = al xor bl
   mul  r9                     ; rax = rax * FNV_64_PRIME
%else
   mul  r9                     ; rax = rax * FNV_64_PRIME
   mov  bl, byte[r8]           ; bl = byte from r8
   xor  rax, rbx               ; al = al xor bl
%endif
   inc  r8                     ; inc buffer pos
   dec  rcx                    ; rcx = rcx - 1 (counter)
   jnz  nextbyte               ; if rcx != 0, jmp to nextbyte
   mov  rbx, r10               ; restore rbx
   ret                         ; rax = fnv1 hash

%endif

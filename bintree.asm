;
; bintree.asm : Binary Tree implementation
; Author      : Rob Neff
;
; Copyright (C)2010 Piranha Designs, LLC - All rights reserved.
; Source code licensed under the new/simplified BSD OSI license.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following
; conditions are met:
;
; * Redistributions of source code must retain the above copyright
;   notice, this list of conditions and the following disclaimer.
; * Redistributions in binary form must reproduce the above
;   copyright notice, this list of conditions and the following
;   disclaimer in the documentation and/or other materials provided
;   with the distribution.
;   
;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
;   CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
;   INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
;   MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;   DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
;   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
;   NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
;   LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
;   HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
;   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
;   OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
;   EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
; Implementation Notes:
;
; This file contains assembly source code that implements
; a binary tree. It is capable of being assembled for both
; 32-bit and 64-bit Intel CPUs and is compatible with
; Unix/Linux and Windows.
; The 32-bit code uses the C language calling convention while the
; 64-bit code makes use of the fastcall calling convention of
; the target operating system.
;
; This implementation does not support duplicate node keys.
; If inserting a node into a tree that already contains an
; identical key the existing key and associated data value is
; replaced with the new node and then freed.
;
; Do not use the free() routine on any node pointers returned by
; any functions; Instead, use binarytree_delete_node() to delete
; a single node containing the key, or binarytree_delete_tree()
; to delete the entire tree.
;
; To assemble this code using Nasm use one of the following commands.
;
; For 32-bit Unix/Linux:
;     nasm -f elf32 bintree.asm -o bintree.o
;
; For 64-bit Unix/Linux:
;     nasm -f elf64 bintree.asm -o bintree.o
;
; To assemble this code using Nasm for use with Windows:
;
; For 32-bit Windows:
;     nasm -f win32 bintree.asm -o bintree.obj
;
; For 64-bit Windows:
;     nasm -f win64 bintree.asm -o bintree.obj

%include 'bintree.inc'

[section .text]

%ifidni __BITS__,32

;
; 32-bit C calling convention
;

extern _malloc
extern _memcmp
extern _memcpy
extern _free

global _binarytree_alloc_node
global _binarytree_find_node
global _binarytree_insert_node
global _binarytree_delete_node
global _binarytree_delete_tree

;
; Paramaters and Stack Local Variables (SLV)
;
%define param4 [ebp+20]
%define param3 [ebp+16]
%define param2 [ebp+12]
%define param1 [ebp+8]
%define slv_proot [ebp-4]
%define slv_pnode [ebp-8]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; struct _bst_node_t * binarytree_alloc_node(byte *key, unsigned klen, byte *value, unsigned vlen)
;
; Purpose
;    To allocate memory for a binary tree node structure and initialize with key/value pair
;
; Params
;    key = ptr to key
;   klen = length of key
;  value = ptr to data, if any
;   vlen = length of data
;
; Returns
;   eax
;       = struct _bst_node_t *
;       = null ptr if key ptr == null, key len < 1, or insufficient memory
;
; Notes
;    Params value and vlen may be null or zero
;
_binarytree_alloc_node:
   push ebp                    ; set up stack frame
   mov  ebp, esp
   push esi                    ; save registers used
   push edi
   push ebx

   xor  edi, edi               ; edi = null ptr

   mov  esi, dword param1      ; esi = ptr to key
   cmp  esi, 0
   je   BST_A_N_X              ; if key == 0 jmp to exit

   mov  ebx, dword param2      ; ebx = key length
   cmp  ebx, 0
   je   BST_A_N_X              ; if len == 0 jmp to exit

   mov  ecx, dword param4      ; ecx = value length
   mov  eax, _bst_node_t_size  ; eax = sizeof(_bst_node_t)
   add  eax, ebx               ;     + key length
   add  eax, ecx               ;     + value length
   push eax
   call _malloc
   add  esp, 4
   cmp  eax, 0
   je   BST_A_N_X              ; if eax == 0 jmp to exit

   mov  edi, eax               ; edi = ptr to node

   ;
   ; ensure all ptrs are properly initialized
   ;
   mov  dword[eax + _bst_node_t.parent], 0
   mov  dword[eax + _bst_node_t.left], 0
   mov  dword[eax + _bst_node_t.right], 0
   mov  dword[eax + _bst_node_t.value], 0
   mov  dword[eax + _bst_node_t.vlen], 0

   ;
   ;copy user key data to node key buffer
   ;
   add  eax, _bst_node_t_size  ; eax = ptr to node key buffer
   mov  dword[edi+_bst_node_t.key], eax
   mov  dword[edi+_bst_node_t.klen], ebx
   push ebx                    ; push params
   push esi
   push eax
   call _memcpy
   add  esp, 12

   ;
   ;copy user value, if any, to node value buffer
   ;
   mov  esi, dword param3      ; esi = ptr to user value buffer
   cmp  esi, 0
   je   BST_A_N_X              ; if value == null jmp to exit
   mov  ecx, dword param4      ; ecx = vlen
   cmp  ecx, 0
   je   BST_A_N_X              ; if vlen == 0 jmp to exit

   mov  eax, edi               ; eax = ptr to node
   add  eax, _bst_node_t_size  ; eax = ptr to node key buffer
   add  eax, ebx               ; eax = ptr to node value buffer
   mov  dword[edi+_bst_node_t.value],eax
   mov  dword[edi+_bst_node_t.vlen], ecx

   push ecx                    ; push params
   push esi
   push eax
   call _memcpy
   add  esp, 12

BST_A_N_X:
   mov  eax, edi               ; eax = struct _bst_node_t*

   pop  ebx                    ; restore registers used
   pop  edi
   pop  esi
   pop  ebp
   ret                         ; eax = struct _bst_node_t *

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; struct _bst_node_t * binarytree_find_node(struct _bst_node_t **root, void *key, unsigned int klen)
;
; Purpose
;    To find a node within the binary tree containing key
;
; Params
;    root = address of ptr to root of binary tree to search
;     key = ptr to key
;    klen = length of key
;
; Returns
;    eax
;       = ptr to found node
;       = null ptr if root == null, key == null, len == 0, or key not found
;
; Notes
;
_binarytree_find_node:
   push ebp                    ; set up stack frame
   mov  ebp, esp
   push esi                    ; save registers used
   push edi                    ;
   push ebx                    ;

   xor  eax, eax               ; eax = null ptr

   mov  edi, dword param1      ; edi = pptr to root
   cmp  edi, 0
   je   BST_F_N_X              ; if pptr == null jmp to exit

   mov  edi, [edi]             ; edi = ptr to root
   cmp  edi, 0
   je   BST_F_N_X              ; if root ptr == null jmp to exit

   mov  esi, dword param2      ; esi = key
   cmp  esi, 0
   je   BST_F_N_X              ; if key == 0 jmp to exit

   mov  ebx, dword param3      ; ebx = length
   cmp  ebx, 0
   je   BST_F_N_X              ; if klen == 0 jmp to exit

   ; get shortest key length
   mov  eax, dword[edi + _bst_node_t.klen]
   cmp  eax, ebx
   jle  BST_F_N_1

   mov  eax, ebx               ; eax = shortest key length

BST_F_N_1:

   ; compare user key to this nodes key
   push eax
   mov  eax, dword[edi + _bst_node_t.key]
   push eax
   push esi
   call _memcmp
   add  esp, 12
   cmp  eax, 0
   je   BST_F_N_5
   jg   BST_F_N_4

BST_F_N_2:
   ; assert: user key less than node key
   add  edi, _bst_node_t.left  ; esi = address of node.left
   mov  eax, dword[edi]
   cmp  eax, 0
   je   BST_F_N_X              ; if left ptr == null jmp to exit

BST_F_N_3:
   push ebx
   push esi
   push edi
   call _binarytree_find_node
   add  esp, 12
   jmp  BST_F_N_X

BST_F_N_4:
   ; assert: user key greater than node key
   add  edi, _bst_node_t.right ; esi = address of node.right
   mov  eax, dword[edi]
   cmp  eax, 0
   je   BST_F_N_X              ; if right ptr == null jmp to exit
   jmp  BST_F_N_3

BST_F_N_5:
   ; assert: since keys are equal check lengths
   mov  eax, dword[edi + _bst_node_t.klen]
   cmp  ebx, eax
   jl   BST_F_N_2
   jg   BST_F_N_4

   ; assert: keys are identical
   mov  eax, edi

BST_F_N_X:
   pop  ebx                    ; restore registers used
   pop  edi
   pop  esi
   pop  ebp
   ret                         ; eax = struct _bst_node_t *

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; int binarytree_insert_node(struct _bst_node_t **root, struct _bst_node_t *node)
;
; Purpose
;    To insert a node into the binary tree
;
; Params
;    root = address of ptr to binary tree root node
;    node = ptr to node to insert into binary tree
;
; Returns
;   eax
;       = 0 if successful
;       = 1 if parameter error
;
; Notes
;    Any node contained within the binary tree (including the root node)
;    that compares to the node param key is replaced with the new node
;    and the old node is deleted.  Duplicate nodes are not supported.
;
_binarytree_insert_node:
   push ebp                    ; set up stack frame
   mov  ebp, esp
   push esi                    ; save registers used
   push edi                    ;
   push ebx                    ;

   ; validate parameters to ensure tree integrity
   mov  edi, dword param1      ; edi = pptr to root
   cmp  edi, 0
   je   BST_I_N_RET_1          ; if pptr == 0 return param error

   mov  esi, dword param2      ; esi = ptr to node
   cmp  esi, 0
   je   BST_I_N_RET_1          ; if pnode == 0 return param error

   mov  eax, dword[edi]        ; eax = ptr to root node
   cmp  eax, 0
   jne  BST_I_N_1              ; if proot != 0 then find insert point

   ; assert: null root, make node new root
   mov  dword[edi], esi
   jmp  BST_I_N_RET_0

BST_I_N_1:

   mov  edi, eax               ; edi = ptr to root node

   ; get shortest key length
   mov  eax, dword[edi + _bst_node_t.klen]
   mov  ecx, dword[esi + _bst_node_t.klen]
   cmp  eax, ecx
   jle  BST_I_N_2

   mov  eax, ecx               ; eax = shortest key length

BST_I_N_2:

   ; compare user key to this nodes key
   push eax
   mov  eax, dword[edi + _bst_node_t.key]
   push eax
   mov  eax, dword[esi + _bst_node_t.key]
   push eax
   call _memcmp
   add  esp, 12
   cmp  eax, 0
   je   BST_I_N_8
   jg   BST_I_N_5

BST_I_N_3:
   ; assert: user key less than node key
   mov  eax, dword[edi + _bst_node_t.left]
   cmp  eax, 0
   je   BST_I_N_6

   add  edi, _bst_node_t.left  ; edi = address of node.left

BST_I_N_4:
   push esi
   push edi
   call _binarytree_insert_node
   add  esp, 8
   jmp  BST_I_N_X

BST_I_N_5:
   ; assert: user key greater than node key
   mov  eax, dword[edi + _bst_node_t.right]
   cmp  eax, 0
   je   BST_I_N_7

   add  edi, _bst_node_t.right ; edi = address of node.right
   jmp  BST_I_N_4

BST_I_N_6:
   ; insert into left child ptr
   mov  dword[edi + _bst_node_t.left], esi
   ; update user node parent
   mov  dword[esi + _bst_node_t.parent], edi
   jmp  BST_I_N_RET_0

BST_I_N_7:
   ; insert into right child ptr
   mov  dword[edi + _bst_node_t.right], esi
   ; update user node parent
   mov  dword[esi + _bst_node_t.parent], edi
   jmp  BST_I_N_RET_0

BST_I_N_8:
   ; assert: since keys are equal check lengths
   mov  eax, dword[edi + _bst_node_t.klen]
   mov  ecx, dword[esi + _bst_node_t.klen]
   cmp  ecx, eax
   jl   BST_I_N_3
   jg   BST_I_N_5

   ; assert: keys are identical, prepare for node swap
   mov  eax, dword[edi + _bst_node_t.left]
   mov  dword[esi + _bst_node_t.left], eax
   mov  eax, dword[edi + _bst_node_t.right]
   mov  dword[esi + _bst_node_t.right], eax
   mov  ecx, dword[edi + _bst_node_t.parent]
   mov  dword[esi + _bst_node_t.parent], ecx

   cmp  ecx, 0
   je   BST_I_N_11             ; if root ptr

   ; assert: not root node, update ptr
   mov  eax, dword[ecx + _bst_node_t.left]
   cmp  eax, edi
   je   BST_I_N_9

   mov  eax, dword[ecx + _bst_node_t.right]
   cmp  eax, edi
   je   BST_I_N_10

   ; neither ptr comparing is a serious integrity error
   jmp  BST_I_N_RET_1

BST_I_N_9:
   ; assert: swapping parent left node
   mov  dword[ecx + _bst_node_t.left], esi
   jmp  BST_I_N_12

BST_I_N_10:
   ; assert: swapping parent right node
   mov  dword[ecx + _bst_node_t.right], esi
   jmp  BST_I_N_12

BST_I_N_11:
   ; assert: swapping out root node
   mov  eax, dword param1      ; eax = address of root ptr
   mov  dword[eax], esi        ; store new root node ptr

BST_I_N_12:
   ; safe to free old node in edi
   push edi
   call _free
   pop  eax
   jmp  BST_I_N_RET_0

BST_I_N_RET_1:
   mov  eax, 1                 ; eax = param error
   jmp  BST_I_N_X

BST_I_N_RET_0:
   xor  eax, eax               ; eax = 0 ( success )

BST_I_N_X:
   pop  ecx
   pop  edi
   pop  esi
   pop  ebp
   ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; int binarytree_delete_node(struct _bst_node_t **root, void *key, unsigned int klen)
;
; Purpose
;    To delete a node from the binary search tree
;
; Params
;    root = address of ptr to binary search tree root node
;     key = ptr to key to find and delete
;    klen = length of key
;
; Returns
;    eax
;       = 0 if successful, otherwise err code
;       = 1 if parameter error
;
; Notes
;    If the only node in the tree is the root node and it compares
;    to the key param it is deleted and will be set to null
;
_binarytree_delete_node:
   push ebp
   mov  ebp, esp

   ; TODO: recursively find node to delete
   mov  eax, 1

BST_D_N_X:
   pop  ebp
   ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; int binarytree_delete_tree(struct _bst_node_t **root)
;
; Purpose
;    To delete all nodes from the binary tree
;
; Params
;    root = address of ptr to binary tree root
;
; Returns
;    eax
;       = 0 if successful
;       = 1 if parameter error
;
; Notes
;    After all the nodes have been deleted from the
;    tree the root node ptr is deleted and set to null
;
_binarytree_delete_tree:
   push ebp
   mov  ebp, esp
   push edi                    ; save registers used

   mov  edi, dword param1      ; edi = pptr to root
   cmp  edi, 0
   je   BST_D_T_RET_1          ; if pptr == null jmp to exit

   mov  edi, dword[edi]        ; edi = ptr to root
   cmp  edi, 0
   je   BST_D_T_RET_1          ; if ptr == null jmp to exit

   add  edi, 4                 ; edi = ptr to _bst_node_t.left
   mov  eax, dword[edi]        ; eax = node.left
   cmp  eax, 0
   je   BST_D_T_1

   push edi
   call _binarytree_delete_tree
   pop  edi

BST_D_T_1:
   add  edi, 4                 ; edi = ptr to _bst_node_t.right
   mov  eax, dword[edi]        ; eax = node.right
   cmp  eax, 0
   je   BST_D_T_2

   push edi
   call _binarytree_delete_tree
   pop  eax

BST_D_T_2:
   mov  edi, dword param1      ; edi = pptr to root
   mov  eax, [edi]             ; eax = root ptr
   push eax
   call _free
   pop  eax

   mov  dword[edi], 0          ; pptr = null
   jmp  BST_D_T_RET_0

BST_D_T_RET_1:
   mov  eax, 1
   jmp  BST_D_T_X

BST_D_T_RET_0:
   xor  eax, eax

BST_D_T_X:
   pop  edi                    ; restore register
   pop  ebp
   ret

%elifidni __BITS__,64

;
; use 64-bit fastcall calling convention
;

%ifidni __OUTPUT_FORMAT__,elf64

;
; use 64-bit Linux fastcall convention
;    ints/longs/ptrs: RDI, RSI, RDX, RCX, R8, R9
;     floats/doubles: XMM0 to XMM7

%define slv_pptr  [rbp-8]
%define slv_proot [rbp-16]
%define slv_pnode [rbp-24]
%define slv_key   [rbp-32]
%define slv_klen  [rbp-40]
%define slv_value [rbp-48]
%define slv_vlen  [rbp-56]

extern _malloc
extern _memcmp
extern _memcpy
extern _free

global _binarytree_alloc_node
global _binarytree_find_node
global _binarytree_insert_node
global _binarytree_delete_node
global _binarytree_delete_tree

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; struct _bst_node_t * binarytree_alloc_node(byte *key, unsigned klen, byte *value, unsigned vlen)
;
; Purpose
;    To allocate memory for a binary tree node structure and initialize with key/value pair
;
; Params
;    key = ptr to key
;   klen = length of key
;  value = ptr to data, if any
;   vlen = length of data
;
; Returns
;   eax
;       = struct _bst_node_t *
;       = null ptr if key ptr == null, key len < 1, or insufficient memory
;
; Notes
;    Params value and vlen may be null/zero if using the binary tree for keys only
;
_binarytree_alloc_node:
   push rbp                    ; create stack frame
   mov  rbp, rsp
   sub  rsp, 64                ; create SLV

   xor  rax, rax               ; rax = null ptr

   ; rdi = key, rsi = klen, rdx = value, rcx = vlen
   cmp  rdi, 0
   je   BST_A_N_X              ; if key == 0 jmp to exit

   cmp  rsi, 0
   je   BST_A_N_X              ; if klen == 0 jmp to exit

   mov  qword slv_key, rdi     ; save register values
   mov  qword slv_klen, rsi    ;
   mov  qword slv_value, rdx   ;
   mov  qword slv_vlen, rcx    ;

   mov  rdi, _bst_node_t_size  ; rdi = sizeof(_bst_node_t)
   add  rdi, rsi               ;       + key length
   add  rdi, rcx               ;       + value length
   call _malloc
   cmp  rax, 0
   je   BST_A_N_X

   mov  qword slv_pnode, rax   ; save node ptr

   ;
   ; ensure all ptrs initialized
   ;
   mov  qword[rax + _bst_node_t.parent], 0
   mov  qword[rax + _bst_node_t.left], 0
   mov  qword[rax + _bst_node_t.right], 0
   mov  qword[rax + _bst_node_t.value], 0
   mov  dword[rax + _bst_node_t.vlen], 0

   ;
   ; copy user key data to node key buffer
   ;
   mov  r10, rax               ; r10 = ptr to node
   add  rax, _bst_node_t_size  ; rax = ptr to node key buffer
   mov  qword[r10+_bst_node_t.key],rax
   mov  rdi, rax               ; rdi = ptr to node key buffer
   mov  rsi, qword slv_key     ; rsi = ptr to user key buffer
   mov  rdx, qword slv_klen    ; rdx = key length
   mov  dword[r10+_bst_node_t.klen], edx
   call _memcpy

   mov  rax, qword slv_pnode   ; reload node ptr

   ;
   ; copy user value, if any, to node value buffer
   ;
   mov  rsi, qword slv_value   ; rsi = ptr to user value buffer
   cmp  rsi, 0
   je   BST_A_N_X
   mov  rdx, qword slv_vlen    ; rdx = value length
   cmp  edx, 0
   je   BST_A_N_X
   mov  rdi, rax               ; rdi = ptr to node
   add  rdi, _bst_node_t_size  ; rdi = ptr to node key buffer
   add  rdi, dword slv_klen    ; rdi = ptr to node value buffer
   mov  qword[rax+_bst_node_t.value],rdi
   mov  dword[rax+_bst_node_t.vlen], edx
   call _memcpy

   mov  rax, qword slv_pnode   ; reload node ptr

BST_A_N_X:
   add  rsp, 64
   pop  rbp
   ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; struct _bst_node_t * binarytree_find_node(struct _bst_node_t **root, void *key, unsigned int klen)
;
; Purpose
;    To find a node within the binary tree root containing key
;
; Params
;    root = address of ptr to root of binary tree to search
;     key = ptr to key
;    klen = length of key
;
; Returns
;    eax
;       = ptr to found node
;       = null ptr if root == null, key == null, len == 0, or key not found
;
; Notes
;
_binarytree_find_node:
   push rbp                    ; set up stack frame
   mov  rbp, rsp
   sub  rsp, 64                ; create SLV and RSS

   xor  rax, rax               ; rax = null ptr

   cmp  rdi, 0
   je   BST_F_N_X              ; if pptr == null jmp to exit

   cmp  rsi, 0
   je   BST_F_N_X              ; if key == null jmp to exit

   cmp  rdx, 0
   je   BST_F_N_X              ; if klen == 0 jmp to exit

   mov  rdi, [rdi]             ; rdi = ptr to root
   cmp  rdi, 0
   je   BST_F_N_X              ; if root ptr == null jmp to exit

   mov  qword slv_proot, rdi   ; save parameter values to SLV
   mov  qword slv_key, rsi     ;
   mov  qword slv_klen, rdx    ;

   ; get shortest key length
   mov  eax, dword[rdi + _bst_node_t.klen]
   cmp  edx, eax
   jle  BST_F_N_1

   mov  edx, eax               ; edx = shortest key length

BST_F_N_1:

   ; compare user key to this nodes key
   mov  rsi, qword[rdi + _bst_node_t.key]
   mov  rdi, qword slv_key
   call _memcmp
   mov  rdi, qword slv_pnode   ; rdi = root node ptr
   cmp  eax, 0
   je   BST_F_N_5
   jg   BST_F_N_4

BST_F_N_2:
   ; assert: user key less than node key
   mov  rax, qword[rdi + _bst_node_t.left]
   cmp  rax, 0
   je   BST_F_N_X              ; if left ptr == null then jmp to exit

   add  rdi, _bst_node_t.left  ; rdi = address of node.left

BST_F_N_3:
   mov  rsi, qword slv_key
   mov  rdx, qword slv_klen
   call _binarytree_find_node
   jmp  BST_F_N_X

BST_F_N_4:
   ; assert: user key greater than node key
   mov  rax, qword[rdi + _bst_node_t.right]
   cmp  rax, 0
   je   BST_F_N_X              ; if right ptr == null then jmp to exit

   add  rdi, _bst_node_t.right ; rdi = address of node.right
   jmp  BST_F_N_3

BST_F_N_5:
   ; assert: since keys are equal check lengths
   mov  eax, dword[rdi + _bst_node_t.klen]
   mov  rdx,  qword slv_klen   ; rdx = user key length
   cmp  edx, eax
   jl   BST_F_N_2
   jg   BST_F_N_4

   ; assert: keys are identical
   mov  rax, rdi

BST_F_N_X:
   add  rsp, 64                ; remove SLV
   pop  rbp
   ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; int binarytree_insert_node(struct _bst_node_t **root, struct _bst_node_t *node)
;
; Purpose
;    To insert a node into the binary tree
;
; Params
;    root = address of ptr to binary tree root node
;    node = ptr to node to insert into binary tree
;
; Returns
;   eax
;       = 0 if successful
;       = 1 if parameter error
;
; Notes
;    Any node contained within the binary tree (including the root node)
;    that compares to the node param key is replaced with the new node
;    and the old node is deleted.  Duplicate nodes are not supported.
;
_binarytree_insert_node:
   push rbp                    ; set up stack frame
   mov  rbp, rsp
   sub  rsp, 32                ; create SLV

   ; validate parameters to ensure tree integrity
   cmp  rdi, 0
   je   BST_I_N_RET_1          ; if pptr == 0 jmp to exit

   cmp  rsi, 0
   je   BST_I_N_RET_1          ; if pnode == 0 jmp to exit

   mov  rax, qword[rdi]        ; rax = root ptr
   cmp  rax, 0
   jne  BST_I_N_1              ; if proot != 0 then find insert point

   ; assert: null root, make node new root
   mov  qword[rdi], rsi
   jmp  BST_I_N_RET_0

BST_I_N_1:

   mov  qword slv_pptr, rdi    ; save register param values
   mov  qword slv_proot, rax   ; save root ptr
   mov  qword slv_pnode, rsi   ; save node ptr

   ; get shortest key length
   mov  edx, dword[rax + _bst_node_t.klen]
   mov  r8d, dword[rsi + _bst_node_t.klen]
   cmp  edx, r8d
   jle  BST_I_N_2

   mov  edx, r8d               ; edx = shortest key length

BST_I_N_2:

   ; compare user key to this nodes key
   mov  rdi, qword[rsi + _bst_node_t.key]
   mov  rsi, qword[rax + _bst_node_t.key]
   call _memcmp
   mov  rdi, qword slv_proot   ; rdi = root ptr
   mov  rsi, qword slv_pnode   ; rsi = node ptr
   cmp  eax, 0
   je   BST_I_N_8
   jg   BST_I_N_5

BST_I_N_3:
   ; assert: user key less than node key
   mov  rax, qword[rdi + _bst_node_t.left]
   cmp  rax, 0
   je   BST_I_N_6

   add  rdi, _bst_node_t.left  ; rdi = address of node.left

BST_I_N_4:
   call _binarytree_insert_node
   jmp  BST_I_N_X

BST_I_N_5:
   ; assert: user key greater than node key
   mov  rax, qword[rdi + _bst_node_t.right]
   cmp  rax, 0
   je   BST_I_N_7

   add  rdi, _bst_node_t.right ; rdi = address of node.right
   jmp  BST_I_N_4

BST_I_N_6:
   ; insert into left child ptr
   mov  qword[rdi + _bst_node_t.left], rsi
   ; update user node parent
   mov  qword[rsi + _bst_node_t.parent], rdi
   jmp  BST_I_N_RET_0

BST_I_N_7:
   ; insert into right child ptr
   mov  qword[rdi + _bst_node_t.right], rsi
   ; update user node parent
   mov  qword[rsi + _bst_node_t.parent], rdi
   jmp  BST_I_N_RET_0

BST_I_N_8:
   ; assert: since keys are equal check lengths
   xor  r8, r8
   mov  eax, dword[rdi + _bst_node_t.klen]
   mov  r8d, dword[rsi + _bst_node_t.klen]
   cmp  r8d, eax
   jl   BST_I_N_3
   jg   BST_I_N_5

   ; assert: keys are identical, prepare for node swap
   mov  rax, qword[rdi + _bst_node_t.left]
   mov  qword[rsi + _bst_node_t.left], rax
   mov  rax, qword[rdi + _bst_node_t.right]
   mov  qword[rsi + _bst_node_t.right], rax
   mov  r10, qword[rdi + _bst_node_t.parent]
   mov  qword[rsi + _bst_node_t.parent], r10

   cmp  r10, 0
   je   BST_I_N_11             ; if root ptr

   ; assert: not root node, update ptr
   mov  rax, qword[r10 + _bst_node_t.left]
   cmp  rax, rdi
   je   BST_I_N_9

   mov  rax, qword[r10 + _bst_node_t.right]
   cmp  rax, rdi
   je   BST_I_N_10

   ; neither ptr comparing is a serious integrity error
   jmp  BST_I_N_RET_1

BST_I_N_9:
   ; assert: swapping parent left node
   mov  qword[r10 + _bst_node_t.left], rsi
   jmp  BST_I_N_12

BST_I_N_10:
   ; assert: swapping parent right node
   mov  qword[r10 + _bst_node_t.right], rsi
   jmp  BST_I_N_12

BST_I_N_11:
   ; assert: swapping out root node
   mov  rax, qword slv_pptr    ; rax = address of root ptr
   mov  qword [rax], rsi       ; store new root node ptr

BST_I_N_12:
   ; safe to free old node in rdi
   call _free
   jmp  BST_I_N_RET_0

BST_I_N_RET_1:
   mov  rax, 1                 ; rax = param error
   jmp  BST_I_N_X

BST_I_N_RET_0:
   xor  rax, rax               ; rax = 0 ( success )

BST_I_N_X:
   add  rsp, 32
   pop  rbp
   ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; int binarytree_delete_node(struct _bst_node_t **root, void *key, unsigned int klen)
;
; Purpose
;    To delete a node from the binary tree
;
; Params
;    root = address of ptr to binary tree root node
;     key = ptr to key to find and delete
;    klen = length of key
;
; Returns
;    eax
;       = 0 if successful
;       = 1 if parameter error
;       = 3 if key not found
;
; Notes
;    If the only node in the tree is the root node and it compares
;    to the key param it is deleted and will be set to null
;
_binarytree_delete_node:
   push rbp                    ; set up stack frame
   mov  rbp, rsp
   sub  rsp, 32                ; create SLV

   ; TODO: recursively find node to delete
   mov  rax, 1

BST_D_N_X:
   add  rsp, 32                ; remove SLV
   pop  rbp
   ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; int binarytree_delete_tree(struct _bst_node_t **root)
;
; Purpose
;    To delete all nodes from the binary tree
;
; Params
;    root = address of ptr to binary tree root
;
; Returns
;    eax
;       = 0 if successful, otherwise err code
;       = 1 if parameter error
;
; Notes
;    After all the nodes have been deleted from the tree
;    the root node ptr is deleted and set to null
;
_binarytree_delete_tree:
   push rbp                    ; set up stack frame
   mov  rbp, rsp
   sub  rsp, 32                ; create SLV

   cmp  rdi, 0
   je   BST_D_T_RET_1          ; if pptr == null return param error

   mov  qword slv_pptr, rdi    ; save pptr to root

   mov  rdi, [rdi]             ; rdi = ptr to root node
   cmp  rdi, 0
   je   BST_D_T_RET_1          ; if ptr == null return param error

   mov  qword slv_proot, rdi   ; save ptr

   add  rdi, _bst_node_t.left
   mov  rax, qword[rdi]
   cmp  rax, 0
   je   BST_D_T_1

   call _binarytree_delete_tree

BST_D_T_1:
   mov  rdi, qword slv_proot   ; rdi = ptr to root
   add  rdi, _bst_node_t.right
   mov  rax, qword[rdi]
   cmp  rax, 0
   je   BST_D_T_2

   call _binarytree_delete_tree

BST_D_T_2:
   mov  rdi, qword slv_proot   ; rdi = ptr to node
   call _free                  ; free node ptr
   mov  rax, qword slv_pptr    ; rax = pptr to root
   mov  qword[rax],0           ; set ptr to null
   jmp  BST_D_T_RET_0

BST_D_T_RET_1:
   mov  rax, 1
   jmp  BST_D_T_X

BST_D_T_RET_0:
   xor  rax, rax

BST_D_T_X:
   add  rsp, 32
   pop  rbp
   ret

%elifidni __OUTPUT_FORMAT__,win64

;
; use 64-bit Windows fastcall convention:
;    ints/longs/ptrs: RCX, RDX, R8, R9
;     floats/doubles: XMM0 to XMM3
;

;
; external function calls used by this module
;
extern malloc
extern free
extern memcpy
extern memcmp

;
; binary search tree global functions
;
global binarytree_alloc_node
global binarytree_find_node
global binarytree_insert_node
global binarytree_delete_node
global binarytree_delete_tree

;
; define stack Register Shadow Storage (RSS) space
;
%define win64_rss4 [rbp+40]
%define win64_rss3 [rbp+32]
%define win64_rss2 [rbp+24]
%define win64_rss1 [rbp+16]

; define index into Stack Local Variables (SLV)
%define slv_pnode [rbp-8]
%define slv_proot [rbp-16]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; struct _bst_node_t * binarytree_alloc_node(byte *key, unsigned klen, byte *value, unsigned vlen)
;
; Purpose
;    To allocate memory for a binary search tree node structure and initialize with key/value pair
;
; Params
;      key = ptr to key
;     klen = length of key
;    value = ptr to data, if any
;     vlen = length of data
;
; Returns
;   eax
;       = struct _bst_node_t *
;       = null ptr if key == null, key len == 0, or insufficient memory
;
; Notes
;    Params value and vlen may be null/zero if using the search tree for keys only
;
binarytree_alloc_node:
   push rbp                    ; create stack frame
   mov  rbp, rsp
   sub  rsp, 48                ; create SLV and RSS

   xor  rax, rax               ; rax = null ptr

   ; rcx = key, rdx = klen, r8 = value, r9 = vlen
   cmp  rcx, 0
   je   BST_A_N_X              ; if key == null ptr jmp to exit

   cmp  rdx, 0
   je   BST_A_N_X              ; if klen == 0 jmp to exit

   mov  qword win64_rss1, rcx  ; save register param values to RSS
   mov  qword win64_rss2, rdx  ;
   mov  qword win64_rss3, r8   ;
   mov  qword win64_rss4, r9   ;

   mov  rcx, _bst_node_t_size  ; rcx = sizeof(_bst_node_t)
   add  rcx, rdx               ;       + key length
   add  rcx, r9                ;       + value length
   call malloc
   cmp  rax, 0
   je   BST_A_N_X

   mov  qword slv_pnode, rax   ; save node ptr

   ;
   ; ensure node ptrs are properly initialized
   ;
   mov  qword[rax + _bst_node_t.parent], 0
   mov  qword[rax + _bst_node_t.left], 0
   mov  qword[rax + _bst_node_t.right], 0
   mov  qword[rax + _bst_node_t.value], 0
   mov  dword[rax + _bst_node_t.vlen], 0

   ;
   ; copy user key to node key buffer
   ;
   mov  rcx, rax               ; rcx = ptr to node
   add  rcx, _bst_node_t_size  ; rcx = ptr to node key buffer
   mov  qword[rax+_bst_node_t.key], rcx
   mov  rdx, qword win64_rss1  ; rdx = ptr to user key buffer
   mov  r8, qword win64_rss2   ; r8 = key length
   mov  dword[rax+_bst_node_t.klen], r8d
   call memcpy

   mov  rax, qword slv_pnode   ; reload node ptr

   ;
   ; copy user value, if any, to node value buffer
   ;
   mov  rdx, qword win64_rss3  ; rdx = ptr to user value buffer
   cmp  rdx, 0
   je   BST_A_N_X              ; if value == nullptr then jmp to exit
   mov  r8, qword win64_rss4   ; r8 = value length
   cmp  r8d, 0
   je   BST_A_N_X              ; if vlen == 0 then jmp to exit
   mov  rcx, rax               ; rcx = ptr to node
   add  rcx, _bst_node_t_size  ; rcx = ptr to node key buffer
   add  rcx, qword win64_rss2  ; rcx = ptr to node value buffer
   mov  qword[rax+_bst_node_t.value],rcx
   mov  dword[rax+_bst_node_t.vlen], r8d
   call memcpy

   mov  rax, qword slv_pnode   ; return node ptr

BST_A_N_X:
   add  rsp, 48                ; remove SLV and RSS
   pop  rbp
   ret                         ; rax = node ptr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; struct _bst_node_t * binarytree_find_node(struct _bst_node_t **root, void *key, unsigned int klen)
;
; Purpose
;    To find a node within the binary tree containing key
;
; Params
;    root = address of binary tree root ptr
;     key = ptr to key
;    klen = length of key
;
; Returns
;    rax
;       = ptr to found node
;       = nullptr if root == null, key == null, len == 0, or key not found
;
; Notes
;
binarytree_find_node:
   push rbp                    ; set up stack frame
   mov  rbp, rsp
   sub  rsp, 48                ; create SLV and RSS

   xor  rax, rax               ; rax = null ptr

   cmp  rcx, 0
   je   BST_F_N_X              ; if pptr == null jmp to exit

   cmp  r8, 0
   je   BST_F_N_X              ; if klen == 0 jmp to exit

   mov  rcx, [rcx]             ; rcx = ptr to root
   cmp  rcx, 0
   je   BST_F_N_X              ; if root ptr == null jmp to exit

   mov  qword win64_rss1, rcx  ; save parameter values to RSS
   mov  qword win64_rss2, rdx  ;
   mov  qword win64_rss3, r8   ;

   ; get shortest key length
   mov  eax, dword[rcx + _bst_node_t.klen]
   cmp  r8d, eax
   jle  BST_F_N_1

   mov  r8d, eax               ; r8 = shortest key length

BST_F_N_1:

   ; compare user key to this nodes key
   mov  rdx, qword[rcx + _bst_node_t.key]
   mov  rcx, qword win64_rss2
   call memcmp
   mov  rcx, qword win64_rss1  ; rcx = root node ptr
   cmp  eax, 0
   je   BST_F_N_5
   jg   BST_F_N_4

BST_F_N_2:
   ; assert: user key less than node key
   mov  rax, qword[rcx + _bst_node_t.left]
   cmp  rax, 0
   je   BST_F_N_X              ; if left ptr == null then jmp to exit

   add  rcx, _bst_node_t.left  ; rcx = address of node.left

BST_F_N_3:
   mov  rdx, qword win64_rss2
   mov  r8, qword win64_rss3
   call binarytree_find_node
   jmp  BST_F_N_X

BST_F_N_4:
   ; assert: user key greater than node key
   mov  rax, qword[rcx + _bst_node_t.right]
   cmp  rax, 0
   je   BST_F_N_X              ; if right ptr == null then jmp to exit

   add  rcx, _bst_node_t.right ; rcx = address of node.right
   jmp  BST_F_N_3

BST_F_N_5:
   ; assert: since keys are equal check lengths
   mov  eax, dword[rcx + _bst_node_t.klen]
   mov  r8,  qword win64_rss3  ; r8 = user key length
   cmp  r8d, eax
   jl   BST_F_N_2
   jg   BST_F_N_4

   ; assert: keys are identical
   mov  rax, rcx

BST_F_N_X:
   add  rsp, 48                ; remove SLV and RSS
   pop  rbp
   ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; int binarytree_insert_node(struct _bst_node_t **root, struct _bst_node_t *node)
;
; Purpose
;    To insert a node into the binary search tree
;
; Params
;    root = address of ptr to binary tree root node
;    node = ptr to node to insert into binary tree
;
; Returns
;   eax
;       = 0 if successful
;       = 1 if parameter error
;
; Notes
;    Any node contained within the binary search tree (including the root node)
;    that compares to the node param key is replaced with the new node and the
;    old node is deleted.  Duplicate nodes are not supported.
;
binarytree_insert_node:
   push rbp                    ; set up stack frame
   mov  rbp, rsp
   sub  rsp, 48                ; create SLV and RSS

   ; validate parameters to ensure tree integrity
   cmp  rcx, 0
   je   BST_I_N_RET_1          ; if pptr == 0 then jmp to exit

   cmp  rdx, 0
   je   BST_I_N_RET_1          ; if node == 0 then jmp to exit

   mov  qword win64_rss1, rcx  ; save register param values
   mov  qword win64_rss2, rdx  ;

   mov  rcx, qword[rcx]        ; rcx = ptr to current node
   cmp  rcx, 0
   je   BST_I_N_8

   mov  qword slv_pnode, rcx   ; save ptr to current node

   ; get shortest key length
   mov  r8d, dword[rcx + _bst_node_t.klen]
   mov  r9d, dword[rdx + _bst_node_t.klen]
   cmp  r9d, 0
   je   BST_I_N_X              ; if r9d == 0 then jmp to exit

   cmp  r8d, r9d
   jle  BST_I_N_1

   mov  r8d, r9d               ; r8 = shortest key length

BST_I_N_1:

   ; compare this nodes key to user key
   mov  rcx, qword[rcx + _bst_node_t.key]
   mov  rdx, qword[rdx + _bst_node_t.key]
   call memcmp
   mov  rcx, qword slv_pnode   ; rcx = ptr to current node
   mov  rdx, qword win64_rss2  ; rdx = ptr to new node
   cmp  eax, 0
   je   BST_I_N_7
   jl   BST_I_N_4

BST_I_N_2:
   ; assert: user key less than node key
   mov  rax, qword[rcx + _bst_node_t.left]
   cmp  rax, 0
   je   BST_I_N_5

   add  rcx, _bst_node_t.left  ; rcx = address of node.left

BST_I_N_3:
   call binarytree_insert_node
   jmp  BST_I_N_X

BST_I_N_4:
   ; assert: user key greater than node key
   mov  rax, qword[rcx + _bst_node_t.right]
   cmp  rax, 0
   je   BST_I_N_6

   add  rcx, _bst_node_t.right ; rcx = address of node.right
   jmp  BST_I_N_3

BST_I_N_5:
   ; insert into left child ptr
   mov  qword[rcx + _bst_node_t.left], rdx
   ; update user node parent
   mov  qword[rdx + _bst_node_t.parent], rcx
   jmp  BST_I_N_RET_0

BST_I_N_6:
   ; insert into right child ptr
   mov  qword[rcx + _bst_node_t.right], rdx
   ; update user node parent
   mov  qword[rdx + _bst_node_t.parent], rcx
   jmp  BST_I_N_RET_0

BST_I_N_7:
   ; assert: since keys are equal check lengths
   xor  r8, r8
   mov  eax, dword[rcx + _bst_node_t.klen]
   mov  r8d, dword[rdx + _bst_node_t.klen]
   cmp  r8d, eax
   jl   BST_I_N_2
   jg   BST_I_N_4

   ; assert: keys are identical, prepare for node swap
   mov  rax, qword[rcx + _bst_node_t.left]
   mov  qword[rdx + _bst_node_t.left], rax
   mov  rax, qword[rcx + _bst_node_t.right]
   mov  qword[rdx + _bst_node_t.right], rax
   mov  rax, qword[rcx + _bst_node_t.parent]
   mov  qword[rdx + _bst_node_t.parent], rax

BST_I_N_8:
   mov  rax, qword win64_rss1  ; rax = address of ptr
   mov  qword [rax], rdx       ; store new node ptr
   cmp  rcx, 0                 ; check for null root
   je   BST_I_N_RET_0          ; if rcx == null jmp to exit
   call free                   ; free old node
   jmp  BST_I_N_RET_0

BST_I_N_RET_1:
   mov  rax, 1                 ; rax = 1 ( param error )
   jmp  BST_I_N_X

BST_I_N_RET_0:
   xor  rax, rax               ; rax = 0 ( success )

BST_I_N_X:
   add  rsp, 48
   pop  rbp
   ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; int binarytree_delete_node(struct _bst_node_t **root, void *key, unsigned int klen)
;
; Purpose
;    To delete a node from the binary tree
;
; Params
;    root = address of ptr to binary tree root node
;     key = ptr to key to find and delete
;    klen = length of key
;
; Returns
;    eax
;       = 0 if successful
;       = 1 if parameter error
;       = 2 if key not found
;
; Notes
;    If the only node remaining in the tree is the root node and it
;    compares to the key param it is deleted and will be set to null
;
binarytree_delete_node:
   push rbp                    ; set up stack frame
   mov  rbp, rsp
   sub  rsp, 48                ; create SLV and RSS

   cmp  rcx, 0
   je   BST_D_N_RET_1          ; if pptr == null return param error

   cmp  rdx, 0
   je   BST_D_N_RET_1          ; if key == null return param error

   cmp  r8, 0
   je   BST_D_N_RET_1          ; if len == 0 return param error

   mov  qword win64_rss1, rcx  ; save register param values to RSS
   mov  qword win64_rss2, rdx  ;
   mov  qword win64_rss3, r8   ;

   mov  rcx, [rcx]             ; get root ptr
   cmp  rcx, 0
   je   BST_D_N_RET_1          ; if rcx == 0 return param error

   mov  qword slv_pnode, rcx   ; save ptr to current node

   ; get shortest key length
   mov  eax, dword[rcx + _bst_node_t.klen]
   cmp  r8d, eax
   jle  BST_D_N_1

   mov  r8d, eax               ; r8 = shortest key length

BST_D_N_1:

   ; compare user key to this nodes key
   mov  rdx, qword[rcx + _bst_node_t.key]
   mov  rcx, qword win64_rss2
   call memcmp
   mov  rcx, qword slv_pnode   ; rcx = node ptr
   cmp  eax, 0
   je   BST_D_N_5
   jg   BST_D_N_4

BST_D_N_2:
   ; assert: user key less than node key
   add  rcx, _bst_node_t.left  ; rcx = ptr to node.left
   mov  rax, qword[rcx]
   cmp  rax, 0
   je   BST_D_N_RET_2          ; if left ptr == null return not found

BST_D_N_3:
   mov  rdx, qword win64_rss2
   mov  r8, qword win64_rss3
   call binarytree_delete_node
   jmp  BST_D_N_X              ; rax = error code

BST_D_N_4:
   ; assert: user key greater than node key
   add  rcx, _bst_node_t.right ; rcx = ptr to node.right
   mov  rax, qword[rcx]
   cmp  rax, 0
   je   BST_D_N_RET_2          ; if right ptr == null return not found
   jmp  BST_D_N_3

BST_D_N_5:
   ; assert: keys are equal, check lengths
   mov  eax, dword[rcx + _bst_node_t.klen]
   mov  r8,  qword win64_rss3  ; r8 = user key length
   cmp  r8d, eax
   jl   BST_D_N_2
   jg   BST_D_N_4

   ; assert: keys are identical
   mov  r9, rcx                ; r9 = node to delete
   mov  r8, qword[r9]          ; r8 = _bst_node_t.parent

   ; find replacement node, if any
   mov  rcx, qword[r9 + _bst_node_t.right]
   cmp  rcx, 0
   je   BST_D_N_9              ; if right ptr == null try left

   ; special case: check child node for valid left ptr
   mov  rax, qword[rcx + _bst_node_t.left]
   cmp  rax, 0
   jne  BST_D_N_7B

   ; assert: rcx = replacement node
   ; set node to delete right ptr to replacement node right ptr
   mov  rax, qword[rcx + _bst_node_t.right]
   mov  qword[r9 + _bst_node_t.right], rax
   jmp  BST_D_N_14A

BST_D_N_7A:
   ; find left-most node
   mov  rax, qword[rcx + _bst_node_t.left]
   cmp  rax, 0
   je   BST_D_N_8
BST_D_N_7B:
   mov  rcx, rax
   jmp  BST_D_N_7A

BST_D_N_8:
   ; assert: rcx = replacement node
   ; set left ptr of parent node to replacement nodes right ptr
   mov  rax, qword[rcx]        ; rax = _bst_node_t.parent
   mov  rdx, qword[rcx + _bst_node_t.right]
   mov  qword[rax + _bst_node_t.left], rdx
   ; set child node new parent
   cmp  rdx, 0
   je   BST_D_N_14A
   mov  qword[rdx], rax
   jmp  BST_D_N_14A

BST_D_N_9:
   ; replace with right-most child of left branch
   mov  rcx, qword[r9 + _bst_node_t.left]
   cmp  rcx, 0
   jne  BST_D_N_10

   ; assert: both child ptrs are null, update parent.
   ; This also handles special case of deleting last
   ; node from tree ( root )
   jmp  BST_D_N_15

BST_D_N_10:
   ; special case: check child node for valid right ptr
   mov  rax, qword[rcx + _bst_node_t.right]
   cmp  rax, 0
   jne  BST_D_N_12B

   ; assert: rcx = replacement node
   ; set node to delete left ptr to replacement node left ptr
   mov  rax, qword[rcx + _bst_node_t.left]
   mov  qword[r9 + _bst_node_t.left], rax
   jmp  BST_D_N_14A

BST_D_N_12A:
   ; find right-most node
   mov  rax, qword[rcx + _bst_node_t.right]
   cmp  rax, 0
   je   BST_D_N_13
BST_D_N_12B:
   mov  rcx, rax
   jmp  BST_D_N_12A

BST_D_N_13:
   ; assert: rcx = replacement node
   ; set right child of parent to replacement nodes left child
   mov  rax, qword[rcx + _bst_node_t.parent]
   mov  rdx, qword[rcx + _bst_node_t.left]
   mov  qword[rax + _bst_node_t.right], rdx
   ; set child node new parent
   cmp  rdx, 0
   je   BST_D_N_14A
   mov  qword[rdx], rax

BST_D_N_14A:
   ; copy node ptrs from r9 to rcx
   mov  rax, qword[r9+_bst_node_t.parent]
   mov  qword[rcx+_bst_node_t.parent], rax
   mov  rax, qword[r9+_bst_node_t.left]
   mov  qword[rcx+_bst_node_t.left], rax
   cmp  rax, 0
   je   BST_D_N_14B
   mov  qword[rax], rcx        ; set new parent
BST_D_N_14B:
   mov  rax, qword[r9+_bst_node_t.right]
   mov  qword[rcx+_bst_node_t.right], rax
   cmp  rax, 0
   je   BST_D_N_15
   mov  qword[rax], rcx        ; set new parent

BST_D_N_15:
   mov  rax, win64_rss1        ; rax = pptr to new node
   mov  qword[rax], rcx

BST_D_N_16:
   mov  rcx, r9                ; rcx = node to delete
   call free
   jmp  BST_D_N_RET_0

BST_D_N_RET_2:
   mov  rax, 2                 ; rax = 2 ( not found )
   jmp  BST_D_N_X

BST_D_N_RET_1:
   mov  rax, 1                 ; rax = 1 ( param error )
   jmp  BST_D_N_X

BST_D_N_RET_0:
   xor  rax, rax               ; rax = 0 ( no error )

BST_D_N_X:
   add  rsp, 48
   pop  rbp
   ret                         ; rax = error code


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; int binarytree_delete_tree(struct _bst_node_t **root)
;
; Purpose
;    To delete all nodes from the binary search tree
;
; Params
;    root = address of ptr to binary search tree root
;
; Returns
;    eax
;       = 0 if successful
;       = 1 if parameter error
;
; Notes
;    After all the nodes have been deleted from the tree
;    the root node ptr is deleted and set to null
;
binarytree_delete_tree:
   push rbp                    ; set up stack frame
   mov  rbp, rsp
   sub  rsp, 48                ; create SLV and RSS

   cmp  rcx, 0
   je   BST_D_T_RET_1          ; if pptr == null return param error

   mov  qword win64_rss1, rcx  ; save pptr to root

   mov  rcx, [rcx]             ; rcx = ptr to root node
   cmp  rcx, 0
   je   BST_D_T_RET_1          ; if ptr == null return param error

   mov  qword slv_proot, rcx   ; save ptr

   add  rcx, _bst_node_t.left
   mov  rax, qword[rcx]
   cmp  rax, 0
   je   BST_D_T_1

   call binarytree_delete_tree

BST_D_T_1:
   mov  rcx, qword slv_proot   ; rcx = ptr to root
   add  rcx, _bst_node_t.right
   mov  rax, qword[rcx]
   cmp  rax, 0
   je   BST_D_T_2

   call binarytree_delete_tree

BST_D_T_2:
   mov  rcx, qword slv_proot   ; rcx = ptr to node
   call free                   ; free node ptr
   mov  rax, win64_rss1        ; rax = pptr to root
   mov  qword[rax],0           ; set ptr to null
   jmp  BST_D_T_RET_0

BST_D_T_RET_1:
   mov  rax, 1
   jmp  BST_D_T_X

BST_D_T_RET_0:
   xor  rax, rax

BST_D_T_X:
   add  rsp, 48
   pop  rbp
   ret

%else
   %fatal unknown output format: __OUTPUT_FORMAT__
%endif

%else
   %fatal unknown bit size: __BITS__
%endif

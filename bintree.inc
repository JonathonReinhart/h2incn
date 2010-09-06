;
; bintree.inc
;
; Copyright (C)2010 Rob Neff
; Source code licensed under the new/simplified BSD OSI license.
;

%ifndef __BINTREE_INCLUDED__
%define __BINTREE_INCLUDED__

%ifidni __BITS__,32
struc _bst_node_t
   .parent resd 1
   .left   resd 1
   .right  resd 1
   .key    resd 1
   .value  resd 1
   .klen   resd 1
   .vlen   resd 1
endstruc
%elifidni __BITS__,64
struc _bst_node_t
   .parent resq 1
   .left   resq 1
   .right  resq 1
   .key    resq 1
   .value  resq 1
   .klen   resd 1
   .vlen   resd 1
endstruc
%endif

%endif  ; ifndef __BINTREE_INCLUDED__

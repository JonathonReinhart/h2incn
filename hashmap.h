/*

   hashmap.h : header defining hashmap operations

   Copyright (C)2010 Rob Neff - All rights reserved.
   Source code licensed under the new/simplified 2-clause BSD OSI license.

*/

#ifndef __HASHMAP_INCLUDED__
#define __HASHMAP_INCLUDED__

/* as defined in bintree.inc */
struct bst_node_t {
   struct bst_node_t *parent;
   struct bst_node_t *left;
   struct bst_node_t *right;
   void *key;
   void *value;
   unsigned int klen;
   unsigned int vlen;
};

typedef struct hash_map_t {
   unsigned int magic;
   unsigned int buckets;
};

/* contained in fnv1hash.asm */
unsigned int FNV1Hash(char *buffer, unsigned int len, unsigned int offset_basis);

/* contained in bintree.asm */
struct bst_node_t * binarytree_alloc_node(void *key, unsigned int klen, char *value, unsigned int vlen);
struct bst_node_t * binarytree_find_node(struct bst_node_t **root, void *key, unsigned int klen);
int binarytree_insert_node(struct bst_node_t **root, struct bst_node_t *node);
int binarytree_delete_node(struct bst_node_t **root, void *key, unsigned int klen);
int binarytree_delete_tree(struct bst_node_t **root);

/* contained in hashmap.c */
struct hash_map_t* hash_map_alloc(unsigned int buckets);
struct bst_node_t* hash_map_find(struct hash_map_t* map, void *key, unsigned int len);
int hash_map_insert(struct hash_map_t *map, void *key, unsigned int klen, void *value, unsigned int vlen);
int hash_map_delete(struct hash_map_t *map, void *key, unsigned int klen);
int hash_map_free(struct hash_map_t* map);

#endif  /* ifndef __HASHMAP_INCLUDED__ */

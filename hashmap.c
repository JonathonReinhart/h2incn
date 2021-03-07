/*
   hashmap.c : hash map routines

   Copyright (C)2010 Rob Neff - All rights reserved.
   Source code licensed under the new/simplified 2-clause BSD OSI license.

*/
#include <stdio.h>
#include <memory.h>
#include <malloc.h>
#include "hashmap.h"

#define HASH_MAP_MAGIC  0x6d686470  // 'pdhm'

/*

unsigned int hash16(unsigned char* p, unsigned int len)

Purpose
   To calculate a 16-bit hash of a buffer of memory

Params
   p - ptr to memory
   len - length of buffer to sum

Returns
   a 16-bit hash

Notes
   This is a modified version of the Fletcher hash algorithm

*/
static unsigned int hash16(unsigned char* buf, unsigned int len)
{
   register short int sum1;
   register unsigned int sum2;
   register unsigned char* p;

   sum2 = sum1 = 0;
   p = buf;
   while (len--)
   {
      sum1 += *p++;
      if (sum1 >= 255) sum1 -= 255;
      sum2 += sum1;
   }
   sum2 %= 255;
   return ( (sum2 << 8) | sum1 );
}

/***********************************************************

hash_map_t* hash_map_alloc(unsigned int buckets)

Purpose
   To allow memory for the hashmap

Params
   buckets - power of 2 number of buckets

Returns
   ptr to hashmap, null ptr if error

*/
struct hash_map_t* hash_map_alloc(unsigned int buckets)
{
   struct hash_map_t *pHashMap;
   unsigned int len;

   /* ensure correct buckets bitmask */
   if ( buckets == 0 )
      return (struct hash_map_t*)0;

   /* we don't support hashmaps > 32K */
   if ( buckets > 0x8000 )
      buckets = 0x8000;

   /* find uppermost bit */
   len = (1 << ((sizeof(int)*8) - 1));
   while ( (buckets & len) == 0 )
      len = len >> 1;
   len--;  /* create the mask */
   buckets = len;  /* assign bucket size / bit mask */

   /* alloc memory space */
   len = sizeof(struct hash_map_t);
   len += ((buckets + 1) * sizeof(void*));
   pHashMap = malloc(len);
   if ( pHashMap )
   {
      memset(pHashMap, 0, len);
      pHashMap->magic   = HASH_MAP_MAGIC;
      pHashMap->buckets = buckets;
   }
   return pHashMap;
}

/******************************************************************************************

struct bst_node_t* hash_map_find(struct hash_map_t* pHashMap, void *key, unsigned int klen)

Purpose
   To find a node within the hashmap containing key

Params
   pHashMap - ptr to hash map to search
   key - ptr to key to search for
   klen - length of key

Returns
   ptr to node if found, otherwise null

*/
struct bst_node_t* hash_map_find(struct hash_map_t* pHashMap, void *key, unsigned int klen)
{
   unsigned int hash;
   struct bst_node_t** root;

#if 0
   /* compute the 32-bit hash value of key */
   hash = FNV1Hash(key, klen, 2166136261);

   /* xor-fold into 16-bit value */
   hash = (((hash >> 16) ^ hash) & pHashMap->buckets);
#endif

   hash = hash16(key, klen) & pHashMap->buckets;

   root = (struct bst_node_t**)((char*)(((char*)pHashMap) + sizeof(struct hash_map_t)) + (hash * sizeof(void*)));

   return binarytree_find_node(root, key, klen);
}

/*************************************************************************************************************

int hash_map_insert(struct hash_map_t* pHashMap, void *key, unsigned int klen, char *value, unsigned int vlen)

Purpose
   To insert a node within the hashmap containing key/value pair

Params
   pHashMap - ptr to hash map to insert into
   key - ptr to key to insert
   klen - length of key
   value - data corresponding to key
   vlen - length of data value

Returns
   0 if successful, otherwise error code

Notes
   value may be null or vlen may be zero if using the hash map for keys only.
   Duplicate keys are not supported.

*/
int hash_map_insert(struct hash_map_t* pHashMap, void *key, unsigned int klen, void *value, unsigned int vlen)
{
   unsigned int hash;
   struct bst_node_t *node;
   struct bst_node_t **root;

#ifdef _DEBUG
   static int cCollisions = 0;
   static int cInserts = 0;
#endif

#if 0
   /* compute the 32-bit hash value of key */
   hash = FNV1Hash(key, klen, 2166136261);

   /* xor-fold into 16-bit value */
   hash = (((hash >> 16) ^ hash) & pHashMap->buckets);
#endif

   hash = hash16(key, klen) & pHashMap->buckets;

   node = binarytree_alloc_node(key, klen, value, vlen);
   if ( !node )
      return 2;  /* insufficient memory error */

#ifdef _DEBUG
   cInserts++;
   printf("Hash=0x%04x : Total of %d inserts\n", hash, cInserts);
#endif

   root = (struct bst_node_t**)((char*)(((char*)pHashMap) + sizeof(struct hash_map_t)) + (hash * sizeof(void*)));

   /* check for existing entry, if any */
   if ( *root == 0 )
   {
      /* assert: no collision, put new root node entry here */
      *root = node;
   }
   else
   {
#ifdef _DEBUG
      cCollisions++;
      printf("Hash=0x%04x : Total of %d collisions\n", hash, cCollisions);
#endif
      return binarytree_insert_node(root, node);
   }

   return 0;
}

/*****************************************************************************

int hash_map_delete(struct hash_map_t* pHashMap, void *key, unsigned int klen)

Purpose
   To delete a node from the hashmap containing key

Params
   pHashMap - ptr to hash map to insert into
   key - ptr to key to delete
   klen - length of key

Returns
   0 if successful, otherwise error code

Notes

*/
int hash_map_delete(struct hash_map_t* pHashMap, void *key, unsigned int klen)
{
   unsigned int hash;
   struct bst_node_t** root;

#if 0
   /* compute the 32-bit hash value of key */
   hash = FNV1Hash(key, klen, 2166136261);

   /* xor-fold into 16-bit value */
   hash = (((hash >> 16) ^ hash) & pHashMap->buckets);
#endif

   hash = hash16(key, klen) & pHashMap->buckets;

   root = (struct bst_node_t**)((char*)(((char*)pHashMap) + sizeof(struct hash_map_t)) + (hash * sizeof(void*)));

   return binarytree_delete_node(root, key, klen);

}

/*****************************************************************************

int hash_map_free(struct hash_map_t *pHashMap)

Purpose
   To delete all nodes from the hashmap

Params
   pHashMap - ptr to hash map to delete

Returns
   0 if successful, otherwise error code

Notes

*/
int hash_map_free(struct hash_map_t *pHashMap)
{
   unsigned int i;
   struct bst_node_t** root;

   if ( !pHashMap )
      return 1;  /* param error */

   if ( pHashMap->magic != HASH_MAP_MAGIC )
      return 1;  /* param error */

   for ( i = 0; i < pHashMap->buckets; i++ )
   {
      /* delete all binary trees */
      root = (struct bst_node_t**)((char*)(((char*)pHashMap) + sizeof(struct hash_map_t)) + (i * sizeof(void*)));
      if ( *root )
         binarytree_delete_tree(root);
   }

   pHashMap->magic = 0;

   free(pHashMap);

   return 0;
}


/*

   h2incn.c : Convert C header files to Nasm-compatible .inc files
   Author   : Rob Neff
   Copyright (C)2010 Piranha Designs, LLC - All rights reserved.
   Source code licensed under the new/simplified 2-clause BSD OSI license.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following
   conditions are met:

   * Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above
     copyright notice, this list of conditions and the following
     disclaimer in the documentation and/or other materials provided
     with the distribution.
   
   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
   CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
   INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
   DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
   NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
   LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
   HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
   OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
   EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <malloc.h>
#include "h2incn.h"
#include "hashmap.h"

int h2incn_parse(struct parser_t *parser);
int h2incn_read(struct parser_t *parser);

struct options_t options;

/* a maintained list of include filenames to prevent endless recursion */
struct hash_map_t *pHeadersMap;

/* used to map defines for quick access */
struct hash_map_t *pDefinesMap;

char* reserved_words[] = {
   "include",
   "define",
   "undef",
   "if",
   "ifdef",
   "ifndef",
   "else"
   "endif"
};

void print_copyright(void)
{
   printf("\nh2incn v%d.%d.%d\nCopyright (C)2010 Piranha Designs, LLC - All rights reserved.\n\n",
      __H2INCN_VERSION_MAJOR__,
      __H2INCN_VERSION_MINOR__,
      __H2INCN_VERSION_BUILD__);
}

void print_usage(void)
{
   printf(
      "usage: h2incn [options] file\n\n"
      "Options:\n"
      "  -c   convert and emit comments\n"
      "  -e   emit code as comments\n"
      "  -d   define macro (ie: -d FOO=1,BAR=1 )\n"
      "  -h   show help\n"
      "  -i   set additional include search path\n"
      "  -L   print license information\n"
      "  -m   emit C-like function call macros\n"
      "  -o   specify output file name\n"
      "  -p   preprocess files\n"
      "  -r   recursively convert files included with '#include \"file\"'\n"
      "  -v   verbose\n"
      "\n");
}

void print_license(void)
{
   printf(
      "Redistribution and use in source and binary forms, with or without\n"
      "modification, are permitted provided that the following\n"
      "conditions are met:\n\n");
   printf(
      "* Redistributions of source code must retain the above copyright\n"
      "  notice, this list of conditions and the following disclaimer.\n"
      "* Redistributions in binary form must reproduce the above\n"
      "  copyright notice, this list of conditions and the following\n"
      "  disclaimer in the documentation and/or other materials provided\n"
      "  with the distribution.\n\n");
   printf(
      "THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND\n"
      "CONTRIBUTORS \"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES,\n"
      "INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF\n"
      "MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE\n"
      "DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR\n"
      "CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,\n"
      "SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT\n"
      "NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;\n"
      "LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)\n"
      "HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN\n"
      "CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR\n"
      "OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,\n"
      "EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.\n");
}

void h2incn_print_err(struct parser_t *parser, char* funcname, char* errmsg)
{
   char *tail;

   tail = parser->pLine;
   while ( ( *tail != 0 ) && ( *tail != '\r' ) && ( *tail != '\n' ) ) tail++;
   *tail = 0;  /* safe to nul-terminate since we will end */

   printf("%s\n", parser->pLine);
   printf("(%s::%d) %s: %s\n", parser->pFileName, parser->iLineNum, funcname, errmsg);
}

void parse_cmdln(int argc, char **argv)
{
   int i, cmd;

   if (argc < 2)
   {
      print_usage();
      exit(1);
   }

   for ( i = 1; i < argc; i++)
   {
      if ( *argv[i] ==  '-' )
      {
         cmd = *(argv[i]+1);
         switch (cmd) {
            case 'C':
            case 'c':
               options.fComments = 1;
               break;
            case 'D':
            case 'd':
               options.pDefines = argv[++i];
               break;
            case 'E':
            case 'e':
               options.fCode = 1;
               break;
            case 'H':
            case 'h':
               print_usage();
               exit(1);
               break;
            case 'I':
            case 'i':
               options.pIncludePath = argv[++i];
               break;
            case 'L':
            case 'l':
               print_license();
               exit(1);
               break;
            case 'M':
            case 'm':
               options.fMacros = 1;
               break;
            case 'O':
            case 'o':
               options.pOutFileName = argv[++i];
               break;
            case 'P':
            case 'p':
               options.fPreprocess = 1;
               break;
            case 'R':
            case 'r':
               options.fRecurse = 1;
               break;
            case 'V':
            case 'v':
               options.fVerbose = 1;
               break;
            default:
               print_usage();
               exit(1);
               break;
         }
      }
      else
      {
         if ( options.pInFileName )
         {
            print_usage();
            exit(1);
         }
         options.pInFileName = argv[i];
      }
   }
}

int h2incn_parse_comment(struct parser_t *parser)
{
   char *head;
   char *tail;

   head = parser->pNextToken;
   if ( *head != '/' )
   {
      h2incn_print_err(parser, "h2incn_parse_comment", "comment expected");
      return 0;
   }
   tail = head;
   tail++;
   if ( *tail == '/' )
   {
      /* assert: single-line comment */
      while ( ( *tail != 0 ) && ( *tail != '\r' ) && ( *tail != '\n' ) ) tail++;
      while ( *(tail-1) == '\\' )
      {
         printf("(%s::%d) %s: %s\n", parser->pFileName, parser->iLineNum, "h2incn_parse_comment", "warning: continuation character found in single-line comment");
         if ( options.fComments )
         {
            fwrite(";", 1, 1, parser->pOutFile);
            fwrite(head, 1, tail-head, parser->pOutFile);
            fwrite("\n", 1, 1, parser->pOutFile);
         }
         if ( *tail == '\r' )
            tail++;
         if ( *tail == '\n' )
         {
            tail++;
            parser->pLine = tail;
            parser->pNextToken = tail;
            parser->iLineNum++;
         }
         head = tail;
         while ( ( *tail != 0 ) && ( *tail != '\r' ) && ( *tail != '\n' ) ) tail++;
      }

      if ( *tail == '\r' )
         tail++;
      if ( *tail == '\n' )
      {
         tail++;
         parser->iLineNum++;
         parser->pLine = tail;
      }
      if ( options.fComments )
      {
         fwrite(";", 1, 1, parser->pOutFile);
         fwrite(head, 1, tail-head, parser->pOutFile);
      }
   }
   else if ( *tail == '*' )
   {
      /* assert: multi-line comment */
      tail++;
      while ( *tail != 0 )
      {
         if ( *tail == '\n' )
         {
            tail++;
            parser->pLine = tail;
            parser->iLineNum++;
            if ( options.fComments )
            {
               fwrite(";", 1, 1, parser->pOutFile);
               fwrite(head, 1, tail-head, parser->pOutFile);
            }
            head = tail;
            continue;
         }
         if ( *tail == '*' )
         {
            tail++;
            if ( *tail == '/' )
               break;
         }
         else
         {
            tail++;
         }
      }
      if ( *tail != '/' )
      {
         h2incn_print_err(parser, "h2incn_parse_comment", "unterminated comment");
         return 0;
      }
      tail++;

      if ( options.fComments )
      {
         fwrite(";", 1, 1, parser->pOutFile);
         fwrite(head, 1, tail-head, parser->pOutFile);
         fwrite("\n", 1, 1, parser->pOutFile);
      }
      else
      {
         while ( ( *tail == ' ' ) || ( *tail == '\t' ) ) tail++;
         if ( *tail == '\r' )
            tail++;
         if ( *tail == '\n' )
         {
            tail++;  /* no need to print blank line */
            parser->iLineNum++;
            parser->pLine = tail;
         }
      }
   }
   else
   {
      h2incn_print_err(parser, "h2incn_parse_comment", "comment expected");
      return 0;
   }

   while ( (*tail == ' ') || (*tail == '\t') ) tail++;
   parser->pNextToken = tail;

   return 1;

}


int h2incn_parse_include(struct parser_t *parser)
{
   char *head;
   char *tail;
   struct parser_t *incparser;
   struct bst_node_t *node;
   int bSuccess;

   head = parser->pNextToken;

   while ( ( *head != 0 ) && ( *head != '<' ) && ( *head != '\"' ) && ( *head != '\n' ) ) head++;
   if ( options.fRecurse )
   {
      if ( ( *head != '<' ) && ( *head != '\"' ) )
      {
         h2incn_print_err(parser, "h2incn_parse_include", "syntax error");
         return 0;
      }
      head++;
      tail = head;
      while ( ( *tail != 0 ) && ( *tail != '>' ) && ( *tail != '\"' ) && ( *tail != '\n' ) ) tail++;
      if ( ( *tail != '\"' ) && ( *tail != '>' ) )
      {
         h2incn_print_err(parser, "h2incn_parse_include", "syntax error");
         return 0;
      }

      /* have we parsed this include header already? */
      node = hash_map_find(pHeadersMap, head, (unsigned int)(tail-head));
      if ( node )
         return 1;

      /* add this header to the HeadersMap */
      node = binarytree_alloc_node(head, (unsigned int)(tail-head), (void*)0, 0);
      if ( !node )
      {
         h2incn_print_err(parser, "h2incn_parse_include", "insufficient memory");
         return 0;
      }
      hash_map_insert(pHeadersMap, head, (unsigned int)(tail-head), (void*)0, 0);
#ifdef _DEBUG
      /* verify node insertion */
      if ( !hash_map_find(pHeadersMap, head, (unsigned int)(tail-head)) )
      {
         h2incn_print_err(parser, "h2incn_parse_include", "hash_map_find error!");
         return 0;
      }
#endif
      incparser = malloc(sizeof(struct parser_t));
      if ( !incparser )
      {
         h2incn_print_err(parser, "h2incn_parse_include", "insufficient memory");
         return 0;
      }
      memset(incparser, 0, sizeof(struct parser_t));
      incparser->pPrevParser = parser;
      incparser->pFileName = malloc(tail-head+2);
      if ( !incparser->pFileName )
      {
         h2incn_print_err(parser, "h2incn_parse_include", "insufficient memory");
         return 0;
      }
      memset(incparser->pFileName, 0, tail-head+2);
      strncpy(incparser->pFileName, head, tail-head);
      incparser->pOutFile = parser->pOutFile;

      bSuccess = h2incn_read(incparser);

      free(incparser->pFileName);
      free(incparser);

   }
   else
   {
      bSuccess = 1;
      tail = head;
   }

   while ( ( *tail != 0 ) && ( *tail != '\n' ) ) tail++;
   if ( *tail == '\n' )
   {
      tail++;  /* no need to print blank line */
      parser->iLineNum++;
   }

   parser->pNextToken = tail;

   return bSuccess;

}

int h2incn_parse_struct(struct parser_t *parser)
{
   char *head;
   char *tail;
   char *vhead;
   char *vtail;
   int braces;

   head = parser->pNextToken;
   fwrite(head, 1, 5, parser->pOutFile);
   fwrite(" ", 1, 1, parser->pOutFile);
   head += 6;

   while ( *head != 0 )
   {
      while ( ( *head == ' ' ) || ( *head == '\t' ) ) head++;
      if ( *head == '\r' )
         head++;
      if ( *head == '\n' )
      {
         head++;
         parser->iLineNum++;
         parser->pLine = head;
         parser->pNextToken = head;
      }
      if ( (*head != ' ') && (*head != '\t') && (*head != '\r') && (*head != '\n') )
         break;
   }

   if ( *head == '{' )
   {
      /* assert: no tagname given, obtain from end */
      braces = 1;
      head++;
      vhead = head;
      while ( *vhead != 0 )
      {
         while ( ( *vhead != 0 ) && ( *vhead != '{' ) && ( *vhead != '}' ) ) vhead++;
         if ( *vhead == '{' )
         {
            vhead++;
            braces++;
         }
         else if ( *vhead == '}' )
         {
            if ( !braces )
            {
               h2incn_print_err(parser, "h2incn_parse_struct", "brace mismatch");
               return 0;
            }
            vhead++;
            braces--;
            if ( !braces )
            {
               /* assert: we found end of struct */
               while ( ( *vhead == ' ') || ( *vhead == '\t' ) ) vhead++;
               if ( *vhead == ';' )
               {
                  h2incn_print_err(parser, "h2incn_parse_struct", "no struct tag defined");
                  return 0;
               }
               vtail = vhead;
               while ( ( *vtail != 0 ) && (*vtail != ' ') && (*vtail != '\t') && (*vtail != ',') && (*vtail != ';') && (*vtail != '\r') && (*vtail != '\n') ) vtail++;
               fwrite(vhead, 1, vtail - vhead, parser->pOutFile);
               break;
            }
         }
      }

      if ( braces )
      {
         h2incn_print_err(parser, "h2incn_parse_struct", "brace mismatch");
         return 0;
      }
   }
   else
   {
      /* assert: struct tag name available */
      tail = head;
      while ( ( *tail != 0 ) && ( *tail != ' ' ) && ( *tail != '\t' ) && ( *tail != ',' ) && ( *tail != '(' ) && ( *tail != ';' ) && ( *tail != '{' ) && ( *tail != '\r' ) && ( *tail != '\n' ) ) tail++;
      if ( tail > head )
      {
         fwrite(head, 1, tail-head, parser->pOutFile);
         fwrite("\n", 1, 1, parser->pOutFile);
      }
      else
      {
         h2incn_print_err(parser, "h2incn_parse_struct", "no struct tag defined");
         return 0;
      }

      head = tail;
      while ( *head != 0 )
      {
         while ( ( *head == ' ' ) || ( *head == '\t' ) ) head++;
         if ( *head == '\r' )
         {
            fwrite(head, 1, 1, parser->pOutFile);
            head++;
         }
         if ( *head == '\n' )
         {
            fwrite(head, 1, 1, parser->pOutFile);
            head++;
            parser->iLineNum++;
            parser->pLine = head;
            parser->pNextToken = head;
         }
         if ( (*head != ' ') && (*head != '\t') && (*head != '\r') && (*head != '\n') )
            break;
      }
   }

   parser->pNextToken = head;

   return 1;

}


int h2incn_parse_typedef(struct parser_t *parser)
{
   char *head;
   char *tail;
   char *vhead;
   char *vtail;
   int errcode;
#ifdef _DEBUG
   struct bst_node_t *node;
#endif

   vhead = parser->pNextToken;
   vhead += 7;
   while ( ( *vhead == ' ' ) || ( *vhead == '\t' ) ) vhead++;

   if ( !memcmp(vhead, "struct", 6) )
   {
      parser->pNextToken = vhead;
      return h2incn_parse_struct(parser);
   }

   /* assert: associate a define with the appropriate type */

   /* key comes after value */
   tail = vhead;
   while ( (*tail != 0) && (*tail != ';') && (*tail != '\n') ) tail++;
   if ( *tail != ';' )
   {
      h2incn_print_err(parser, "h2incn_parse_typedef", "expected ';'");
      return 0;
   }
   tail--;
   while ( ( tail > vhead ) && ( (*tail == ' ') || (*tail == '\t') ) ) tail--;
   head = tail;
   tail++;
   while ( ( head > vhead ) && (*head != ' ') && (*head != '\t') && (*head != ')') ) head--;
   if ( head == vhead )
   {
      h2incn_print_err(parser, "h2incn_parse_typedef", "syntax error");
      return 0;
   }

   if ( *head == ')' )
   {
      /* assert: function typedef, emit a commented line */
      while ( (*tail != 0) && (*tail != '\r') && (*tail != '\n') ) tail++;
      fwrite("; ", 1, 2, parser->pOutFile);
      fwrite(vhead, 1, tail-vhead, parser->pOutFile);
      parser->pNextToken = tail;
      return 1;
   }
   vtail = head;
   head++;
   while ( ( vtail > vhead ) && ( (*vtail == ' ') || (*vtail == '\t') ) ) vtail--;
   vtail++;

   fwrite("%define ", 1, 8, parser->pOutFile);
   fwrite(head, 1, tail-head, parser->pOutFile);
   fwrite(" ", 1, 1, parser->pOutFile);
   fwrite(vhead, 1, vtail-vhead, parser->pOutFile);

#if 0
   vtail = vhead;
   while (*vtail != 0)
   {
      while ( ( *vhead == ' ' ) || ( *vhead == '\t' ) ) vhead++;
      vtail = vhead;
      while ( ( *vtail != 0 ) && ( *vtail != ' ' ) && ( *vtail != '\t' ) && ( *vtail != '(' ) && ( *vtail != ';' ) && ( *vtail != '\r' ) && ( *vtail != '\n' ) ) vtail++;

      len = vtail - vhead;
      if ( (len == 6 ) && ( !memcmp(vhead, "static", len) ) )
      {
         vtail += 6;
         vhead = vtail;
         continue;
      }
      else if ( ( len == 8 ) && ( !memcmp(vhead, "unsigned",  8) )
      {
         vtail += 8;
         vhead = vtail;
         continue;
      }
   }

   fwrite(head, 1, tail-head, parser->pOutFile);
   fwrite(" ", 1, 1, parser->pOutFile);
   fwrite(vhead, 1, vtail-vhead, parser->pOutFile);

   vhead = tail;
   while ( ( *vhead == ' ' ) || ( *vhead == '\t' ) ) vhead++;
   if ( ( *vhead == '/' ) && ( ( *(vhead+1) == '/' ) || ( *(vhead+1) == '*' ) ) )
   {
      /* parse inline comment */
      parser->pNextToken = vhead;
      bSuccess = h2incn_parse_comment(parser);
      if ( !bSuccess )
         return bSuccess;
      vhead = parser->pNextToken;
   }
   vtail = vhead;

   while ( ( *vtail != 0 ) && ( *vtail != '\r' ) && ( *vtail != '\n' ) ) vtail++;
   if ( vtail > vhead )
   {
      fwrite(" ", 1, 1, parser->pOutFile);
      fwrite(vhead, 1, vtail - vhead, parser->pOutFile);
   }
#endif

   /* add this define to the DefinesMap */
   errcode = hash_map_insert(pDefinesMap, head, (unsigned int)(tail - head), vhead, (unsigned int)(vtail - vhead));
#ifdef _DEBUG
   node = hash_map_find(pDefinesMap, head, (unsigned int)(tail - head));
   if ( !node )
   {
      h2incn_print_err(parser, "h2incn_parse_define", "binary tree corrupt");
      return 0;
   }
#endif

   while ( (*tail != 0) && (*tail != ';') ) tail++;
   if (*tail == ';')
      tail++;

   parser->pNextToken = tail;

   return (errcode == 0 ? 1 : 0);

}


int h2incn_parse_define(struct parser_t *parser)
{
   char *head;
   char *tail;
   char *vhead;
   char *vtail;
   int bSuccess;
   int bComments;
   struct bst_node_t *node;

   head = parser->pNextToken;
   fwrite("%define ", 1, 8, parser->pOutFile);
   head += 8;
   while ( *head != 0 )
   {
      while ( ( *head == ' ' ) || ( *head == '\t' ) ) head++;
      if ( ( *head == '/' ) && ( ( *(head+1) == '/' ) || ( *(head+1) == '*' ) ) )
      {
         if ( ( *head == '/' ) && ( *(head+1) == '/' ) )
         {
            h2incn_print_err(parser, "h2incn_parse_define", "error: define syntax");
            return 0;
         }
         /* parse out inline comment */
         bComments = options.fComments;
         options.fComments = 0;
         parser->pNextToken = head;
         bSuccess = h2incn_parse_comment(parser);
         options.fComments = bComments;
         if ( !bSuccess )
            return bSuccess;
         head = parser->pNextToken;
      }
      else
      {
         break;
      }
   }

   tail = head;
   while ( ( *tail != 0 ) && ( *tail != ' ' ) && ( *tail != '\t' ) && ( *tail != '(' ) && ( *tail != '\r' ) && ( *tail != '\n' ) ) tail++;
   fwrite(head, 1, tail-head, parser->pOutFile);

   if ( options.fPreprocess )
   {
      node = hash_map_find(pDefinesMap, head, (unsigned int)(tail - head));
      if ( node )
         printf("(%s::%d) %s: %s\n", parser->pFileName, parser->iLineNum, "h2incn_parse_define", "warning: redefinition");
   }

   vhead = tail;
   while ( *vhead != 0 )
   {
      /* value may, or may not, be defined */
      while ( ( *vhead == ' ' ) || ( *vhead == '\t' ) ) vhead++;
      if ( ( *vhead == '/' ) && ( ( *(vhead+1) == '/' ) || ( *(vhead+1) == '*' ) ) )
      {
         /* parse out inline comment */
         bComments = options.fComments;
         options.fComments = 0;
         parser->pNextToken = vhead;
         bSuccess = h2incn_parse_comment(parser);
         options.fComments = bComments;
         if ( !bSuccess )
            return bSuccess;
         vhead = parser->pNextToken;
      }
      else
      {
         break;
      }
   }
   vtail = vhead;

   while ( ( *vtail != 0 ) && ( *vtail != '\r' ) && ( *vtail != '\n' ) ) vtail++;
   while ( *(vtail-1) == '\\' )
   {
      if ( *vtail == '\r' )
         vtail++;
      if ( *vtail == '\n' )
      {
         vtail++;
         parser->iLineNum++;
      }
      while ( *vtail != 0 )
      {
         while ( (*vtail != 0) && (*vtail != '/') && ( *vtail != '\r' ) && ( *vtail != '\n' ) ) vtail++;
         if (( *vtail == '/' ) && ( ( *(vhead+1) == '/' ) || ( *(vhead+1) == '*' ) ) )
         {
            /* parse out inline comment */
            bComments = options.fComments;
            options.fComments = 0;
            parser->pNextToken = vtail;
            bSuccess = h2incn_parse_comment(parser);
            options.fComments = bComments;
            if ( !bSuccess )
               return bSuccess;
            vtail = parser->pNextToken;
         }
         else
         {
            vtail++;
         }
      }
   }
   if ( vtail > vhead )
   {
      if ( *vhead != '(' )
         fwrite(" ", 1, 1, parser->pOutFile);
      fwrite(vhead, 1, vtail - vhead, parser->pOutFile);
   }

   /* add this define to the DefinesMap */
   bSuccess = hash_map_insert(pDefinesMap, head, (unsigned int)(tail - head), vhead, (unsigned int)(vtail - vhead));
#ifdef _DEBUG
   node = hash_map_find(pDefinesMap, head, (unsigned int)(tail - head));
   if ( !node )
   {
      h2incn_print_err(parser, "h2incn_parse_define", "binary tree corrupt");
      return 0;
   }
#endif

   parser->pNextToken = vtail;

   return (bSuccess == 0 ? 1 : 0);

}


int h2incn_parse_if(struct parser_t *parser)
{
   char *head;
   char *tail;
   int bSuccess;

   head = parser->pNextToken;
   fwrite("%if ", 1, 4, parser->pOutFile);
   head += 4;
   while ( ( *head != 0 ) && ( ( *head == ' ' ) || ( *head == '\t' ) ) ) head++;
   while ( ( *head != '\r' ) && ( *head != '\n' ) )
   {
      tail = head;
      while ( ( *tail != 0 ) && ( *tail != '/' ) && ( *tail != '\r' ) && ( *tail != '\n' ) ) tail++;
      if ( tail > head )
         fwrite(head, 1, tail - head, parser->pOutFile);

      head = tail;
      if ( ( *head == '/' ) && ( ( *(head+1) == '/' ) || ( *(head+1) == '*' ) ) )
      {
         /* parse inline comment */
         parser->pNextToken = head;
         if ( options.fComments )
            fwrite(" ", 1, 1, parser->pOutFile);
         bSuccess = h2incn_parse_comment(parser);
         if ( !bSuccess )
            return bSuccess;
         head = parser->pNextToken;
      }
   }

   parser->pNextToken = head;

   return 1;
}

int h2incn_parse_ifdef(struct parser_t *parser)
{
   char *head;
   char *tail;
   int bSuccess;

   head = parser->pNextToken;
   fwrite("%ifdef ", 1, 7, parser->pOutFile);
   head += 7;
   while ( ( *head != 0 ) && ( ( *head == ' ' ) || ( *head == '\t' ) ) ) head++;
   while ( ( *head != '\r' ) && ( *head != '\n' ) )
   {
      tail = head;
      while ( ( *tail != 0 ) && ( *tail != '/' ) && ( *tail != '\r' ) && ( *tail != '\n' ) ) tail++;
      if ( tail > head )
         fwrite(head, 1, tail - head, parser->pOutFile);

      head = tail;
      if ( ( *head == '/' ) && ( ( *(head+1) == '/' ) || ( *(head+1) == '*' ) ) )
      {
         /* parse inline comment */
         parser->pNextToken = head;
         if ( options.fComments )
            fwrite(" ", 1, 1, parser->pOutFile);
         bSuccess = h2incn_parse_comment(parser);
         if ( !bSuccess )
            return bSuccess;
         head = parser->pNextToken;
      }
   }

   parser->pNextToken = head;

   return 1;
}

int h2incn_parse_ifndef(struct parser_t *parser)
{
   char *head;
   char *tail;
   int bSuccess;

   head = parser->pNextToken;
   fwrite("%ifndef ", 1, 8, parser->pOutFile);
   head += 8;
   while ( ( *head != 0 ) && ( ( *head == ' ' ) || ( *head == '\t' ) ) ) head++;
   while ( ( *head != '\r' ) && ( *head != '\n' ) )
   {
      tail = head;
      while ( ( *tail != 0 ) && ( *tail != '/' ) && ( *tail != '\r' ) && ( *tail != '\n' ) ) tail++;
      if ( tail > head )
         fwrite(head, 1, tail - head, parser->pOutFile);

      head = tail;
      if ( ( *head == '/' ) && ( ( *(head+1) == '/' ) || ( *(head+1) == '*' ) ) )
      {
         /* parse inline comment */
         parser->pNextToken = head;
         if ( options.fComments )
            fwrite(" ", 1, 1, parser->pOutFile);
         bSuccess = h2incn_parse_comment(parser);
         if ( !bSuccess )
            return bSuccess;
         head = parser->pNextToken;
      }
   }

   parser->pNextToken = head;

   return 1;
}

int h2incn_parse_elif(struct parser_t *parser)
{
   char *head;
   char *tail;
   int bSuccess;

   head = parser->pNextToken;
   fwrite("%elif ", 1, 6, parser->pOutFile);
   head += 5;
   while ( ( *head != 0 ) && ( ( *head == ' ' ) || ( *head == '\t' ) ) ) head++;
   while ( ( *head != '\r' ) && ( *head != '\n' ) )
   {
      tail = head;
      while ( ( *tail != 0 ) && ( *tail != '/' ) && ( *tail != '\r' ) && ( *tail != '\n' ) ) tail++;
      if ( tail > head )
         fwrite(head, 1, tail - head, parser->pOutFile);

      head = tail;
      if ( ( *head == '/' ) && ( ( *(head+1) == '/' ) || ( *(head+1) == '*' ) ) )
      {
         /* parse inline comment */
         parser->pNextToken = head;
         if ( options.fComments )
            fwrite(" ", 1, 1, parser->pOutFile);
         bSuccess = h2incn_parse_comment(parser);
         if ( !bSuccess )
            return bSuccess;
         head = parser->pNextToken;
      }
   }

   parser->pNextToken = head;

   return 1;
}


int h2incn_parse_else(struct parser_t *parser)
{
   char *head;
   int bSuccess;

   head = parser->pNextToken;
   fwrite("%else", 1, 5, parser->pOutFile);
   head += 5;
   while ( ( *head != 0 ) && ( ( *head == ' ' ) || ( *head == '\t' ) ) ) head++;
   if ( ( *head == '/' ) && ( ( *(head+1) == '/' ) || ( *(head+1) == '*' ) ) )
   {
      /* parse inline comment */
      parser->pNextToken = head;
      if ( options.fComments )
         fwrite(" ", 1, 1, parser->pOutFile);
      bSuccess = h2incn_parse_comment(parser);
      if ( !bSuccess )
         return bSuccess;
   }
   else
   {
      while ( ( *head != 0 ) && ( *head != '\r' ) && ( *head != '\n' ) ) head++;
      parser->pNextToken = head;
   }

   return 1;
}


int h2incn_parse_endif(struct parser_t *parser)
{
   char *head;
   int bSuccess;

   head = parser->pNextToken;
   fwrite("%endif", 1, 6, parser->pOutFile);
   head += 6;
   while ( ( *head != 0 ) && ( ( *head == ' ' ) || ( *head == '\t' ) ) ) head++;
   if ( ( *head == '/' ) && ( ( *(head+1) == '/' ) || ( *(head+1) == '*' ) ) )
   {
      /* parse inline comment */
      parser->pNextToken = head;
      if ( options.fComments )
         fwrite(" ", 1, 1, parser->pOutFile);
      bSuccess = h2incn_parse_comment(parser);
      if ( !bSuccess )
         return bSuccess;
   }
   else
   {
      while ( ( *head != 0 ) && ( *head != '\r' ) && ( *head != '\n' ) ) head++;
      parser->pNextToken = head;
   }

   return 1;
}


int h2incn_parse_undef(struct parser_t *parser)
{
   char *head;
   char *tail;

   head = parser->pNextToken;
   fwrite("%undef ", 1, 7, parser->pOutFile);
   head += 7;
   while ( ( *head != 0 ) && ( ( *head == ' ' ) || ( *head == '\t' ) ) ) head++;
   tail = head;
   while ( ( *tail != 0 ) && ( *tail != ' ' ) && ( *tail != '\t' ) && ( *tail != '/' ) && ( *tail != '(' ) && ( *tail != '\r' ) && ( *tail != '\n' ) ) tail++;

   fwrite(head, 1, tail-head, parser->pOutFile);

   /* remove this define from the DefinesMap */
   hash_map_delete(pDefinesMap, head, (unsigned int)(tail - head));

   /* scan to eol or next token */
   while ( ( *tail != 0 ) && ( ( *tail == ' ' ) || ( *tail == '\t' ) ) ) tail++;
   if ( ( *tail != '\r' ) && ( *tail != '\n' ) )
      fwrite(" ", 1, 1, parser->pOutFile);
   parser->pNextToken = tail;

   return 1;

}

/****************************************************

   h2incn_parse

   Purpose
     To parse include file

   Params
      parser - ptr to struct used for parsing

   Returns
      0 if error, otherwise 1
*/
int h2incn_parse(struct parser_t *parser)
{
   char *head;
   char *tail;
   char *outbuf;
   int bSuccess;

   outbuf = malloc(H2INCN_BUFSIZE + 2);
   if ( !outbuf )
   {
      printf("h2incn_parse: insufficient memory\n");
      return 0;
   }

   if ( options.fVerbose )
      printf("processing file %s\n", parser->pFileName);

   bSuccess = 1;

   while ( *parser->pNextToken != 0 )
   {
      /* skip leading space */
      head = parser->pNextToken;
      while ( ( *head == ' ' ) || ( *head == '\t' ) ) head++;

      /* check for eol, account for differences in Windows/Linux CR/NL */
      tail = head ;
      if ( *tail == '\r' )
         tail++;
      if ( *tail == '\n' )
      {
         tail++;
         fwrite(head, 1, tail - head, parser->pOutFile);
         parser->iLineNum++;
         parser->pNextToken = tail;
         parser->pLine = tail;
         continue;
      }

      /* assert: tail is positioned at a token or eof */
      parser->pNextToken = tail;
      head = tail;
      if ( *head == 0 )
         break;

      memset(outbuf, 0, H2INCN_BUFSIZE + 2);

      if ( *head == '#' )
      {
         if ( !memcmp(head, "#include ", 9) )
         {
            if ( !h2incn_parse_include(parser) )
               return 0;
         }
         else if ( !memcmp(head, "#define ", 8) )
         {
            if ( !h2incn_parse_define(parser) )
               return 0;
         }
         else if ( !memcmp(head, "#undef ", 7) )
         {
            if ( !h2incn_parse_undef(parser) )
               return 0;
         }
         else if ( !memcmp(head, "#if ", 4) )
         {
            if ( !h2incn_parse_if(parser) )
               return 0;
         }
         else if ( !memcmp(head, "#ifdef ", 7) )
         {
            if ( !h2incn_parse_ifdef(parser) )
               return 0;
         }
         else if ( !memcmp(head, "#ifndef ", 8) )
         {
            if ( !h2incn_parse_ifndef(parser) )
               return 0;
         }
         else if ( !memcmp(head, "#elif", 5) )
         {
            if ( !h2incn_parse_elif(parser) )
               return 0;
         }
         else if ( !memcmp(head, "#else", 5) )
         {
            if ( !h2incn_parse_else(parser) )
               return 0;
         }
         else if ( !memcmp(head, "#endif", 6) )
         {
            if ( !h2incn_parse_endif(parser) )
               return 0;
         }
         else
         {
            tail = head;
            while ( ( *tail != 0 ) && ( *tail != '\r' ) && ( *tail != '\n' ) ) tail++;
            if ( *tail == '\r')
               tail++;
            if ( *tail == '\n')
            {
               tail++;
               parser->iLineNum++;
               parser->pLine = tail;
            }
            if ( options.fCode )
            {
               /* assert: emit unknown preprocessor directive as comment */
               fwrite(";", 1, 1, parser->pOutFile);
               fwrite(head, 1, tail - head, parser->pOutFile);
            }
            parser->pNextToken = tail;
         }
      }
      else if ( ( *head == '/' ) && ( ( *(head+1) == '/' ) || ( *(head+1) == '*' ) ) )
      {
         if ( !h2incn_parse_comment(parser) )
            return 0;
      }
      else
      {
#if 0
         if ( !memcmp(head, "typedef ", 8) )
         {
            if ( !h2incn_parse_typedef(parser) )
               return 0;
         }
         else
         {
#endif
            tail = head;
            while ( ( *tail != 0 ) && ( *tail != '\r' ) && ( *tail != '\n' ) ) tail++;
            if ( *tail == '\r')
               tail++;
            if ( *tail == '\n')
            {
               tail++;
               parser->iLineNum++;
               parser->pLine = tail;
            }
            if ( options.fCode )
            {
               /* emit code as comment */
               fwrite(";", 1, 1, parser->pOutFile);
               fwrite(head, 1, tail-head, parser->pOutFile);
            }
            parser->pNextToken = tail;
#if 0
         }
#endif
      }
   }

   free(outbuf);

   return bSuccess;
}


/****************************************************

   h2incn_read

   Purpose
     To read in an include file

   Params
      parser - ptr to struct used for parsing

   Returns
      0 if error, otherwise 1
*/
int h2incn_read(struct parser_t *parser)
{
   FILE *pInFile;
   int bSuccess;

   if ( !parser->pFileName )
   {
      printf("invalid filename arg\n");
      return 0;
   }

   /* open input file */
   pInFile = fopen(parser->pFileName, "r");
   if ( !pInFile )
   {
#if 0
      if ( options.searchpath )
      {
      }
#endif
      if ( parser->pPrevParser )
         parser = parser->pPrevParser;
      h2incn_print_err(parser, "h2incn_read", "error opening file");
      return 0;
   }

   fseek(pInFile, 0, SEEK_END);
   parser->iFileSize = ftell(pInFile);
   fseek(pInFile, 0, SEEK_SET);

   if ( parser->iFileSize < 1 )
   {
      fclose(pInFile);
      printf("no data in file: %s\n", parser->pFileName);
      return 0;
   }

   parser->pFileBuffer = malloc(parser->iFileSize + 2);
   if ( !parser->pFileBuffer )
   {
      fclose(pInFile);
      printf("insufficient memory\n");
      return 0;
   }

   fread(parser->pFileBuffer, 1, parser->iFileSize, pInFile);
   parser->pFileBuffer[parser->iFileSize] = 0;
   fclose(pInFile);

   parser->pLine = parser->pFileBuffer;
   parser->pNextToken = parser->pFileBuffer;
   parser->iLineNum  = 1;

   bSuccess = h2incn_parse(parser);

   free(parser->pFileBuffer);

   return bSuccess;
}

/* #define BINTREE_TEST */
#ifdef BINTREE_TEST
/* This code is only used to test the binary tree functions and should
   not normally be included in the compilation of the program.
*/
int binarytree_test(void)
{
   struct bst_node_t *root;
   struct bst_node_t *node;
   int err;
   char* p;
   char* pchars =    "JKGHIAROBNEFLCDWXUVSTPQYZ";
   char* pdelchars = "STUVOPQRIJKLWXYHCDEFGNZAB";

   /* establish a root */
   p = pchars;
   root = binarytree_alloc_node(p, 1, (void*)0, 0);
   if ( !root )
   {
      printf("\nbinarytree_test: error: insufficient memory\n");
      return 0;
   }

   /* add in data to binary tree */
   p++;
   while ( *p != 0 )
   {
      node = binarytree_alloc_node(p, 1,  (void*)0, 0);
      if ( !node )
      {
         printf("\nbinarytree_test: error: insufficient memory\n");
         return 0;
      }
      if ( err = binarytree_insert_node(&root, node) )
      {
         printf("\nbinarytree_insert_node: error %d\n", err);
         return 0;
      }
      p++;
   }

   p = pdelchars;
   while ( *p != 0 )
   {
      node = binarytree_find_node(&root, p, 1);
      if ( !node )
      {
         printf("\nbinarytree_find_node: error: node not found!\n");
         return 0;
      }
      if ( err = binarytree_delete_node(&root, p, 1) )
      {
         printf("\nbinarytree_delete_node: error %d\n", err);
         return 0;
      }
      node = binarytree_find_node(&root, p, 1);
      if ( node )
      {
         printf("\nbinarytree_find_node: error: found previously deleted node!\n");
         return 0;
      }

      p++;
   }

   return 1;
}
#endif /* ifdef BINTREE_TEST */

int main(int argc, char **argv)
{
   struct parser_t *parser;
   char *tptr;
   int bSuccess;

   print_copyright();
   parse_cmdln(argc, argv);

#ifdef BINTREE_TEST
   if ( !binarytree_test() )
      return 1;
   printf("binarytree_test: info: completed\n");
   return 0;
#endif

   parser = malloc(sizeof(struct parser_t));
   if ( !parser )
   {
      printf("insufficient memory\n");
      return 1;
   }

   if ( !options.pOutFileName )
   {
      /* set up default out_file name */
      options.pOutFileName = malloc(strlen(options.pInFileName)+8);
      strcpy(options.pOutFileName, options.pInFileName);
      tptr = strrchr(options.pOutFileName, '.');
      if ( !tptr )
         strcat(options.pOutFileName, ".inc");
      else
         strcpy(tptr, ".inc");
   }

   /* open output file */
   parser->pOutFile = fopen(options.pOutFileName, "w");
   if ( !parser->pOutFile )
   {
      printf("error opening output file: %s\n", options.pOutFileName);
      return 1;
   }

   pHeadersMap = hash_map_alloc(0x80);
   if ( !pHeadersMap )
   {
      printf("insufficient memory\n");
      return 1;
   }

   pDefinesMap = hash_map_alloc(0x8000);
   if ( !pDefinesMap )
   {
      printf("insufficient memory\n");
      return 1;
   }

   parser->pFileName = options.pInFileName;

   bSuccess = h2incn_read(parser);

   fflush(parser->pOutFile);
   fclose(parser->pOutFile);

   free(parser);

   hash_map_free(pHeadersMap);
   hash_map_free(pDefinesMap);

   return ( bSuccess == 0 ? 1 : 0 );
}

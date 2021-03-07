/*
   h2incn

   Copyright (C)2010 Rob Neff - All rights reserved.
   Source code licensed under the new/simplified 2-clause BSD OSI license.
*/

#ifndef __H2INCN_INCLUDED__
#define __H2INCN_INCLUDED__

#define __H2INCN_VERSION_MAJOR__ 1
#define __H2INCN_VERSION_MINOR__ 0
#define __H2INCN_VERSION_BUILD__ 1

#define H2INCN_BUFSIZE 4096

extern struct list_t *pFileList;

struct parser_t {
   struct parser_t *pPrevParser;
   char *pFileName;
   char *pFileBuffer;
   char *pLine;
   char *pNextToken;
   int  iLineNum;
   int  iFileSize;
   FILE *pOutFile;
};

struct options_t {
   char *pInFileName;
   char *pOutFileName;
   char *pDefines;
   char *pIncludePath;

   int fComments: 1,
       fCode: 1,
       fMacros: 1,
       fPreprocess: 1,
       fRecurse: 1,
       fVerbose: 1;
};

extern struct options_t options;

#endif /* ifndef __H2INCN_INCLUDED__ */

/*
  cobextractor v1.0 - (C)2005 Eddy L O Jansson <srm_dfr@hotmail.com>

  THIS SOFTWARE IS DONATED TO THE PUBLIC DOMAIN AND FREELY REDISTRIBUTABLE

 Purpose:

  cobextractor will extract the individual resources from the .COB resource
  files[0] used by the IBM-PC version of the old computer game Ascendancy.

  Some of the music is stored as raw 22KHz mono samples, which can be
  converted to RIFF WAVE using sox like so:

    sox -c1 -u -b -t raw -r 22050 theme04.raw theme04.wav

  I wrote this to hunt for the music, which I remembered as being very
  good. However, either my memory fails me, or it's not included with
  the PC version, because I couldn't find anything that triggered a memory.

 Usage:

   cobextractor <filename.cob>

   The files will be extracted into the current directory. Some resources
   are located in the subdirectory "data". This directory will not be created
   for you automatically, cobextractor will abort instead. Just create the
   directory and re-run.


[0] ascend00.cob, ascend01.cob, ascend02.cob
*/

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

typedef unsigned int u32;
typedef unsigned char u8;

/*
  stat a file and returns it's size, or -1 on error/file not found
*/
int file_size(const char* filename)
{
  struct stat file_stat;
  int err = stat(filename, &file_stat );
  return err == 0 ? file_stat.st_size : -1;
}

bool unpack_cob(const char* filename)
{
 /*
   File structure:
    u32     number of directory entries (dir_ents)
    char*   dir_ents# of filename entries a' 50 bytes each.
    u32     dir_ents# of absolute (start of file) file data offsets.
    ...     file data
 */

 static const u32 DIRENT_FILENAME_SIZE = 50;
 static const u32 DATA_BUFFER_MAX_SIZE = 1024*1024*2;

 u32   cob_dirents = 0;
 u32   i = 0;
 u32   bytes_left = 0;
 u32   block_size = 0;

 char* data_buffer = NULL;
 char* cob_filenames = NULL;
 u32*  cob_offsets = NULL;

 FILE* cob_fh = NULL;
 FILE* out_fh = NULL;

 if(!(cob_fh = fopen(filename, "rb")) ) return false;

 /* Read number of directory entries from header */
 fread(&cob_dirents, sizeof cob_dirents, 1, cob_fh);

 /* Calculate amount of memory to allocate in the different structures */
 u32 fn_size = cob_dirents * DIRENT_FILENAME_SIZE;
 u32 fo_size = (cob_dirents+1) * 4; /* Allocate one extra entry for use as "sentinel" */
 printf("Allocating %lu bytes for %lu directory entries, and %lu bytes for offsets.\n", fn_size, cob_dirents, fo_size);
 printf("Allocating %lu bytes for data copy buffer.\n", DATA_BUFFER_MAX_SIZE);

 /* Allocate */
 data_buffer   = (char*)malloc(DATA_BUFFER_MAX_SIZE);
 cob_filenames = (char*)malloc(fn_size);
 cob_offsets   = (u32*)malloc(fo_size);

 /* Read directory and offsets from file */
 fread(cob_filenames, DIRENT_FILENAME_SIZE, cob_dirents, cob_fh);
 fread(cob_offsets, 4, cob_dirents, cob_fh);

 /* Set up offset "sentinel" as being the file size */
 cob_offsets[cob_dirents] = file_size(filename);

 /* Extract */
 for(i = 0 ; i < cob_dirents ; ++i)
 {
   bytes_left = cob_offsets[i+1]-cob_offsets[i];
   printf("File '%s' at 0x%x for %lu bytes of data -- ", &cob_filenames[i*DIRENT_FILENAME_SIZE], cob_offsets[i], bytes_left);

   /* Setup files */
   fseek(cob_fh, cob_offsets[i], SEEK_SET);
   if( (out_fh = fopen(&cob_filenames[i*DIRENT_FILENAME_SIZE], "wb")) )
   {
     /* Initiate block-copy algorithm */
     while( bytes_left > 0 )
     {
       block_size = bytes_left < DATA_BUFFER_MAX_SIZE ? bytes_left : DATA_BUFFER_MAX_SIZE;
       fread(data_buffer, block_size, 1, cob_fh);
       fwrite(data_buffer, block_size, 1, out_fh);
       bytes_left -= block_size;
     }

     fclose(out_fh);
     printf("Unpacked!\n");
   } else {
     printf("Error!\n");
     fclose(cob_fh);
     free(cob_offsets);
     free(cob_filenames);
     free(data_buffer);
     return false;
   }
 }

 fclose(cob_fh);
 free(cob_offsets);
 free(cob_filenames);
 free(data_buffer);

 return true;
}

int main(int argc, char* argv[])
{
  if( argc != 2 )
  {
    printf("usage: %s <filename.cob>\n", argv[0]);
    return EXIT_FAILURE;
  }

  if( unpack_cob(argv[1]) )
  {
    printf("COB file processed successfully.\n");
  } else {
    printf("Error, couldn't process COB file: \"%s\".\n", argv[1]);
    return EXIT_FAILURE;
  }

  return EXIT_SUCCESS;
}

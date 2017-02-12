/*
  mm7vidextractor v1.1 - (C)2007 Eddy L O Jansson <srm_dfr@hotmail.com>

  THIS SOFTWARE IS DONATED TO THE PUBLIC DOMAIN AND FREELY REDISTRIBUTABLE

 Purpose:

   Extract the BIK and SMK animations from the game(s)

   Might and Magic 6: The Mandate of Heaven
   Might and Magic 7: For Blood and Honor.
   Might and Magic 8: Day of the Destroyer

   You need to have RAD Video Tools installed to play these files.
   http://www.radgametools.com/bnkdown.htm

 Usage:

   mm7vidextractor <filename.vid>

   The files will be extracted into the current directory.

 History:

   2007-04-16  1.1  eloj  Tested with and adapted for MM6 (added mm6_mode) and MM8.
   2007-04-15  1.0  eloj  First version released.

*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

typedef unsigned int u32;

static const u32 DATA_BUFFER_MAX_SIZE = 1024*1024*2;

typedef struct
{
  char  filename[40];
  u32   offset;
} __attribute__((packed)) t_vidtbl;

/*
  stat a file and returns it's size, or -1 on error/file not found
*/
int file_size(const char* filename)
{
  struct stat file_stat;
  int err = stat(filename, &file_stat );
  return err == 0 ? file_stat.st_size : -1;
}


int main(int argc, char* argv[])
{
  char const * const filename = argc > 1 ? argv[1] : "Magic7.vid";

  printf("Extracting %s to current directory.\n", filename);

  FILE* f = fopen(filename, "rb");
  if( f )
  {
    u32 file_entries = 0;
    int mm6_mode = 0; // When set, file records are modified to not terminate before the file ext.
    fread(&file_entries, 4, 1,f);
    printf("Writing %d files.\n", file_entries);

    // Let's abort if the number of file entries is oddly large or zero.
    if( (file_entries < 1) || (file_entries > 255) )
    {
      fclose(f);
      printf("Never seen this few/many file entries before. Something's probably wrong, aborting.\n");
      return EXIT_FAILURE;
    }

    // We allocate one extra entry for sentry duty
    const int file_entries_size = (file_entries+1)*sizeof(t_vidtbl);

    printf("Allocating %d bytes for file entries, %d for copy-buffer.\n", file_entries_size, DATA_BUFFER_MAX_SIZE);
    t_vidtbl* files = (t_vidtbl*)malloc(file_entries_size);
    char* data_buffer = (char*)malloc(DATA_BUFFER_MAX_SIZE);

    // Set up offset "sentinel" as being the file size
    files[file_entries].offset = file_size(filename);

    // Read in file table.
    fread(files, sizeof(t_vidtbl), file_entries, f);

    // Auto-detect MM6-mode by seeing if there's a stray "smk" after the first resource name
    if( strcmp( &files[0].filename[ strlen(files[0].filename)+1 ], "smk" ) == 0 )
    {
      printf("Auto-detected MM6 mode, adding file extensions.\n");
      mm6_mode = 1;
    }

    // Extract
    for(int i=0 ; i<file_entries ; ++i)
    {
      int bytes_left = files[i+1].offset-files[i].offset;

      if( mm6_mode ) // Add the dot that is missing from the resource name for some reason.
      {
        files[i].filename[ strlen(files[i].filename) ] = '.';
      }

      printf("File '%s' at 0x%x, %lu bytes -- ", files[i].filename, files[i].offset, bytes_left);

      FILE* out = fopen(files[i].filename, "wb");
      if( out )
      {
        fseek(f, files[i].offset, SEEK_SET);

        // Initiate block-copy algorithm
        while( bytes_left > 0 )
        {
          int block_size = bytes_left < DATA_BUFFER_MAX_SIZE ? bytes_left : DATA_BUFFER_MAX_SIZE;
          fread(data_buffer, block_size, 1, f);
          fwrite(data_buffer, block_size, 1, out);
          bytes_left -= block_size;
        }

        printf("OK.\n");
        fclose(out);
      } else {
        printf("write failed!\n");
        fclose(out);
      }

    }

    printf("done.\n");
    fclose(f);
    free(files);
    free(data_buffer);
  } else {
    printf("Couldn't open file.\n");
    return  EXIT_FAILURE;
  }

  return EXIT_SUCCESS;
}

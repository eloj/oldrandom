/*

  infinitycracker v1.1.1

  THIS SOFTWARE IS DONATED INTO THE PUBLIC DOMAIN AND FREELY REDISTRIBUTABLE

 Purpose:

   Remove CD-check from any and all Bioware and Black Isle Infinity Engine games.

 Usage:

   infinitycracker [ --list | --scan filename.exe | filename.exe ]

   The default behaviour is the probe the current directory for known
   executables and crack or decrack them if possible.

   Alternatively, supply a filename to attempt to crack/decrack ("restore") it.

   If that fails, you can try the generic scanning patcher, which might
   work on any version not in the database, by using --scan with a filename.

   The --list option will output the patch database including file name,
   size and version.

 History:

  2010-12-31  1.1.1  eloj    Added BG .4315 US/Int, BG:TotSC .5512 US/UK/Int'l
  2006-11-08  1.1    eloj    Added generic scanning patcher.
  2006-11-01  1.0    eloj    First release.

 Future:

  If you have a version that you feel should be supported, well, I guess you can always
  fix the code yourself. Send me a diff or something.

  "Hey wouldn't it be great if we had a day a week to debug our code, update our notes,
   and try to plan for the next week?" - Mark

  "Sure! Would you like Saturday or Sunday?" - Ray

*/

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>

typedef unsigned int u32;
typedef unsigned char u8;

static const char* PROGRAM_NAME = "InfinityCracker";
static const char* PROGRAM_VER = "v1.1.1";

static const int   BUFSIZE = 1024*1024;
static const int   BACKTRACK_SIZE = 256;

typedef enum { FILE_OPEN_FAIL, FILE_NOT_CANDIDATE, FILE_IS_PRISTINE, FILE_IS_CRACKED } file_classification;

typedef struct games_s
{
  const char**  file_name;
  const char*   file_description;
} games_t;

typedef struct binary_patch_s
{
  const char*    patch_description;
  u8             num_bytes;
  const u8*      bytes_original;
  const u8*      bytes_cracked;
} binary_patch_t;

typedef struct patch_s
{
  const games_t*  game_info;
  const char*     file_version;
  u32             file_size;
  u32             offset;
  const binary_patch_t* patch;
  u32             checksum;
} patch_t;


typedef enum { FN_BGMAIN, FN_BGMAIN2, FN_IDMAIN, FN_IWD2, FN_TORMENT, NUM_FILENAME_IDS } filename_ids;
static const char* fn_table[NUM_FILENAME_IDS] = {
   "BGMain.exe",
   "BGMain2.exe",
   "IDMain.exe",
   "IWD2.exe",
   "Torment.exe",
 };

typedef enum { BG2SOA, BG2TOB, BG1, BG1TOTSC, BG1TOS, IWD, IWDHOW, IWD2, PST, NUM_GAME_IDS } game_ids;
games_t game_table[NUM_GAME_IDS] = {
  { &fn_table[FN_BGMAIN],  "Baldur's Gate 2: Shadows of Amn" },  /* "BGMain.exe" */
  { &fn_table[FN_BGMAIN],  "Baldur's Gate 2: Throne of Bhaal" },
  { &fn_table[FN_BGMAIN],  "Baldur's Gate" },
  { &fn_table[FN_BGMAIN2], "Baldur's Gate: Tales of the Sword Coast" }, /* "BGMain2.exe" */
  { &fn_table[FN_BGMAIN2], "Baldur's Gate: The Original Saga" },
  { &fn_table[FN_IDMAIN],  "Icewind Dale" },                     /* "IDMain.exe" */
  { &fn_table[FN_IDMAIN],  "Icewind Dale: Heart of Winter" },
  { &fn_table[FN_IWD2],    "Icewind Dale 2" },                   /* "IWD2.exe" */
  { &fn_table[FN_TORMENT], "Planescape Torment" },               /* "Torment.exe" */
};

enum { SET_AL_RET=0, PROLOGUE1=3, PROLOGUE2=6 } patch_offsets;
static const u8 PATCH_ARRAY[] = { 0xb0, 0x01, 0xc3, 0x55, 0x8b, 0xec, 0x6a, 0xff, 0x68 };

enum { CRK_STD, CRK_IWD2, NUM_BINARY_PATCHES };
binary_patch_t binary_patch_table[NUM_BINARY_PATCHES] = {
  { "no-cd", 3, &PATCH_ARRAY[PROLOGUE1], &PATCH_ARRAY[SET_AL_RET] },   /* Standard IE no-cd */
  { "no-cd", 3, &PATCH_ARRAY[PROLOGUE2], &PATCH_ARRAY[SET_AL_RET] },   /* IWD2 */
};

patch_t patch_table[] = {
  { &game_table[BG2SOA],   "23037", 7417902, 0x397fe, &binary_patch_table[CRK_STD], 0 },
  { &game_table[BG2TOB],   "26498", 7839790, 0x39d1f, &binary_patch_table[CRK_STD], 0 },
  { &game_table[BG2TOB],   "26499", 7843886, 0x398af, &binary_patch_table[CRK_STD], 0 },
  { &game_table[IWD],      "1.3.062916 / v1.06", 6287360, 0x3acba, &binary_patch_table[CRK_STD], 0 },
  { &game_table[IWDHOW],   "1.4 (021002) / v1.40", 6819840, 0x3cd2e, &binary_patch_table[CRK_STD], 0 },
  { &game_table[IWDHOW],   "1.4 (041115) / v1.41", 6840320, 0x3cd8e, &binary_patch_table[CRK_STD], 0 },
  { &game_table[IWDHOW],   "1.4 (062714) / v1.42", 6873088, 0x3cd43, &binary_patch_table[CRK_STD], 0 },
  { &game_table[IWD2],     "2.01.101615", 5029888, 0x26b20, &binary_patch_table[CRK_IWD2], 0 },
  { &game_table[PST],      "1.1.0000 (2CD)", 5718077, 0x3a0fc, &binary_patch_table[CRK_STD], 0 },
  { &game_table[PST],      "1.1 (4CD)", 5713981, 0x3a0fc, &binary_patch_table[CRK_STD], 0 },
  { &game_table[BG1TOS],   "1.3.5521", 5009408, 0x308d2, &binary_patch_table[CRK_STD], 0 },
  { &game_table[BG1],      "1.0.4309 UK (5CD)", 5004288, 0x2e5b1, &binary_patch_table[CRK_STD], 0 },
  { &game_table[BG1],      "1.1.4320 Eng (DX8, 5CD)", 4857856, 0x2f8e5, &binary_patch_table[CRK_STD], 0 },
  { &game_table[BG1],      "1.1.4315 US/Int", 5022720, 0x2e659, &binary_patch_table[CRK_STD], 0 },
  { &game_table[BG1],      "1.1.4320 Int (DX8, 5CD)", 4857856, 0x2f8c9, &binary_patch_table[CRK_STD], 0 },
  { &game_table[BG1TOTSC], "1.3.5508", 5046319, 0x30e0c, &binary_patch_table[CRK_STD], 0 },
  { &game_table[BG1TOTSC], "1.3.5512 US", 5046319, 0x30ea7, &binary_patch_table[CRK_STD], 0 },
  { &game_table[BG1TOTSC], "1.3.5512 UK/Int", 5042223, 0x30dbd, &binary_patch_table[CRK_STD], 0 },
  { &game_table[BG1TOTSC], "1.3.5521 Eng (DX8)", 4923392, 0x30a39, &binary_patch_table[CRK_STD], 0 },
  { &game_table[BG1TOTSC], "1.3.5521 Int (DX8)", 4923392, 0x3099e, &binary_patch_table[CRK_STD], 0 },
  { NULL }, /* eot sentinel */
};



/*
  stat a file and returns it's size, or -1 on error/file not found
*/
int file_size(const char* filename)
{
  struct stat file_stat;
  return stat(filename, &file_stat ) == 0 ? file_stat.st_size : -1;
}

void display_patch_table(patch_t* tbl)
{
  int i=0;
  printf("%s contain patches for the following games and versions:\n", PROGRAM_NAME);
  while( tbl[i].game_info != NULL)
  {
    printf(" * %s (%s, %ib, %s)\n", tbl[i].game_info->file_description, *(tbl[i].game_info->file_name), tbl[i].file_size, tbl[i].file_version);
    ++i;
  }
  printf("%i patches in database.\n", i);
}

/*
  Given a file handle and a pointer to a patch, verify that
  the data at the offset to be patched is correct. Return
  0 if data mismatch, -1 if valid/cracked and 1 if valid/uncracked.

*/
file_classification classify_file(FILE* fh, patch_t* patch)
{
  /* printf("[classify] Seek target 0x%x\n", patch->offset); */
  fseek(fh, patch->offset, SEEK_SET);

  char* data_buffer = (char*)malloc(patch->patch->num_bytes);
  fread(data_buffer, patch->patch->num_bytes, 1, fh);

  int match_uncracked = memcmp(data_buffer, patch->patch->bytes_original, patch->patch->num_bytes);
  int match_cracked   = memcmp(data_buffer, patch->patch->bytes_cracked,  patch->patch->num_bytes);
  free(data_buffer);

  if( match_uncracked == 0 ) return FILE_IS_PRISTINE;
  if( match_cracked == 0 ) return FILE_IS_CRACKED;

  return FILE_NOT_CANDIDATE;
}

bool patch_file(FILE* fh, const patch_t* patch, bool restore_original_data)
{
  /* printf("[patch] Seek target 0x%x\n", patch->offset); */
  fseek(fh, patch->offset, SEEK_SET);
  return fwrite(restore_original_data ? patch->patch->bytes_original : patch->patch->bytes_cracked, patch->patch->num_bytes, 1, fh) == 1;
}

/*
  Search in patch table based on file size, then check if the
  contents at the offset to be modified is correct.

  If the file is a candidate for patching, return a pointer to
  the relevant patch, else NULL.

*/
file_classification match_patch(FILE* fh, int file_size, patch_t** patch)
{
  patch_t* tbl = *patch;
  file_classification classification = FILE_NOT_CANDIDATE;

  while( tbl->game_info != NULL )
  {
    if( tbl->file_size == file_size )
    {
      printf("Possible match: %s (%s, %s)\n", tbl->game_info->file_description, *(tbl->game_info->file_name), tbl->file_version);
      if( (classification = classify_file(fh, tbl)) != FILE_NOT_CANDIDATE )
      {
        /*printf("Classification: %i\n", classification);*/
        *patch = tbl;
        return classification;
      }
    }
    ++tbl;
  }

  return FILE_NOT_CANDIDATE;
}

file_classification infinity_crack(const char* filename)
{
  FILE* fh = NULL;
  patch_t* patch = patch_table;

  if(!(fh = fopen(filename, "r+b")) ) return FILE_OPEN_FAIL;

  file_classification classification = match_patch(fh, file_size(filename), &patch);

  if( patch != NULL )
  {
    if( classification == FILE_IS_PRISTINE )
    {
      patch_file(fh, patch, false); /* Cracking */
      classification = FILE_IS_CRACKED;
    } else if( classification == FILE_IS_CRACKED ) {
      patch_file(fh, patch, true); /* Reverting patch */
      classification = FILE_IS_PRISTINE;
    }
  }

  fclose(fh);
  return classification;
}

int display_result(const char* filename, file_classification c, bool notfound_quiet)
{
  int exit_status = EXIT_SUCCESS;

  switch( c )
  {
    case FILE_OPEN_FAIL:
      if( notfound_quiet ) break;
      printf("File '%s' couldn't be opened.\n", filename);
      exit_status = EXIT_FAILURE;
      break;

    case FILE_NOT_CANDIDATE:
      printf("File '%s' is not a candidate.\nMight be unknown version, loader, or packed/wrapped, but try --scan\n", filename);
      break;

    case FILE_IS_PRISTINE:
    case FILE_IS_CRACKED:
      printf("File '%s' %s successfully.\n", filename, c == FILE_IS_CRACKED ? "cracked" : "decracked");
      break;
  }
  return exit_status;
}

/* path isn't used */
int crack_directory(const char* path)
{
  int i, num_cracked = 0, num_decracked = 0;
  for(i=0; i<NUM_FILENAME_IDS ; ++i)
  {
    file_classification res = infinity_crack(fn_table[i]);
    if( res == FILE_IS_CRACKED ) ++num_cracked;
    if( res == FILE_IS_PRISTINE ) ++num_decracked;
    display_result(fn_table[i], res, true);
  }
  return num_cracked+num_decracked;
}

/*
   Handwritten generic scanning patcher for Infinity Engine games.
   This one catches all my known executables except IWD2. A bit messy, but good enough.
*/
int generic_scan_patch(const char* filename)
{
  FILE* fh = NULL;
  unsigned char buf2[BACKTRACK_SIZE];
  unsigned char* buf = malloc(BUFSIZE);
  size_t offset = 0;

  if( !(fh = fopen(filename, "r+b")) || (!buf) ) return FILE_OPEN_FAIL;

  printf("Invoking generic scanning patcher on '%s'\n", filename);
  while( !feof(fh) )
  {
    int i = 0, j = 0;
    int bsize = fread(buf, 1, BUFSIZE, fh);
    /* scan buffer */
    for(i=0 ; i<bsize-16 ; ++i)
    {
      // Hand-selected opcodes in cd-check function to locate.
      if( (buf[i] == 0xc6) && (buf[i+7] == 0xff) && (buf[i+8] == 0x15) && (buf[i+13] == 0x89) && (buf[i+14] == 0x45) && (buf[i+15] == 0xdc) )
      {
        long where_we_were = ftell(fh);
        printf("GetLogicalDrives call located at offset 0x%x\n", offset+i+7);
        /*
           To not clobber our other buffer if we need to backtrack, simply use a new one and
           simplify the code by always backtrack.
        */
        fseek(fh, offset+i-BACKTRACK_SIZE, SEEK_SET);
        int offset_k = offset+i-BACKTRACK_SIZE;
        fread(buf2, 1, sizeof buf2, fh);

        /* Now scan backwards to locate the function entry point. */
        for(j=sizeof(buf2)-3 ; j >= 0 ; --j)
        {
          if( (buf2[j] == 0x55) && (buf2[j+1] == 0x8b) && (buf2[j+2] == 0xec) )
          {
            printf("Original function prologue found at offset 0x%x\n", offset_k+j);
            fseek(fh, offset_k+j, SEEK_SET);
            fwrite(&PATCH_ARRAY[SET_AL_RET], 3, 1, fh);
            fclose(fh);
            free(buf);
            return FILE_IS_CRACKED;
          }

          if( (buf2[j] == 0xb0) && (buf2[j+1] == 0x01) && (buf2[j+2] == 0xc3) )
          {
            printf("Patched function prologue found at offset 0x%x\n", offset_k+j);
            fseek(fh, offset_k+j, SEEK_SET);
            fwrite(&PATCH_ARRAY[PROLOGUE1], 3, 1, fh);
            fclose(fh);
            free(buf);
            return FILE_IS_PRISTINE;
          }
        }
        /* If we get here, something went fairly wrong... since we had a hit but couldn't find the prologue */
        printf("Warning: Prologue not found, maybe we backtracked too short a distance?\n");
        fseek(fh, where_we_were, SEEK_SET);
      }
    }

    /* We seek back a bit to handle the case where a match may cross the block boundary */
    if( !feof(fh) )
    {
      fseek(fh, -16, SEEK_CUR);
      offset += bsize - 16;
    }

  }
  free(buf);
  fclose(fh);

  return FILE_NOT_CANDIDATE;
}


void display_help(const char* argv0)
{
  printf("usage: %s [ --list | --scan FILE | FILE ]\n", argv0);
}

void display_header()
{
  printf("%s %s by eloj\n\n", PROGRAM_NAME, PROGRAM_VER);
}

int main(int argc, char* argv[])
{
  display_header();

  if( (argc > 3) || ( (argc > 1) && ( strcmp("--help",argv[1]) == 0 ) ) )
  {
    display_help(argv[0]);
    return EXIT_SUCCESS;
  }

  /* Default: Try all known filenames */
  if( argc == 1 )
  {
    printf("Scanning directory for executables ... \n");
    if( !crack_directory("") )
    {
      printf("No files processed. Verify game file name and version against '--list'\n");
    }
    return EXIT_SUCCESS;
  }

  /* List all available patches */
  if( strcmp("--list", argv[1]) == 0 )
  {
    display_patch_table(patch_table);
    return EXIT_SUCCESS;
  }

  /* Try the scanning patcher */
  if( (strcmp("--scan", argv[1]) == 0) && (argc>2) )
  {
    return display_result(argv[2], generic_scan_patch(argv[2]), false);
  }

  /* Process the given filename */
  return display_result(argv[1], infinity_crack(argv[1]), false);
}

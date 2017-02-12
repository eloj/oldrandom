/*
	FTL: Faster Than Light - Resource Extractor v1.0
	by Eddy L O Jansson, 2012. Donated into the Public Domain.

	Purpose:
		Will extract the individual files from the resource
		bundles of the game FTL. This includes audio, images,
		fonts and more.

	Usage:
		./unftl [file1.dat] [fileN.dat]

	Compile:
		gcc -std=c99 -ggdb -Wall -Wextra -O2 -fomit-frame-pointer unftl.c -o unftl

	{resource,data}.dat file format (files from v1.03.1)

	directory:
		uint32_t	max_dir_entries
		uint32_t	offset_of_file_entry[max_dir_entries]

	file_entry:
		uint32_t	file_size
		uint32_t	filename_len
		char		filename[]
		char		file_data[file_size]

*/
#ifndef _BSD_SOURCE
#define _BSD_SOURCE
#endif
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <errno.h>

struct file_entry {
	uint32_t	size;
	uint32_t	filename_len;
	char		filename[];
} __attribute((packed))__;

enum mkpath_flags {
	MKPATH_NONE = 0,
	MKPATH_WITH_FILENAME = 1
};

static int mkpath_helper(const char* path, mode_t mode) {
	struct stat st;

	if (stat(path, &st) != 0) {
		/* Abort on any error except EEXIST */
		if ((mkdir(path, mode) != 0) && (errno != EEXIST))
			return 0;
	} else if (!S_ISDIR(st.st_mode)) {
		errno = ENOTDIR;
		return 0;
	}
	return 1;
}

int mkpath(const char* path, mode_t mode, enum mkpath_flags flags) {
	char* workpath = __builtin_strdup(path);
	char* subpath = workpath;
	char* sp = NULL;

	int ok = 1;
	while (ok && *subpath && ((sp = strchr(subpath, '/')) || (sp = strchr(subpath, '\0')))) {
		if (*sp) {
			*sp = '\0';
			ok = mkpath_helper(workpath, mode);
			*sp = '/';
			subpath = sp + 1;
		} else {
			if ((flags & MKPATH_WITH_FILENAME) == 0)
				ok = mkpath_helper(workpath, mode);
			break;
		}
	}
	free(workpath);

	return ok;
}

int mmap_file(const char* filename, unsigned char** map) {

	int fd;
	struct stat st;

	fd = open(filename, O_RDONLY);
	if (fd < 0)
		return fd;

	if (fstat(fd, &st) == -1)
		return 0;

	*map = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
	if (*map == MAP_FAILED)
		return 0;

	close(fd);

	return 1;
}

int ftl_unpak(const char* filename) {

	unsigned char* map = NULL;
	int i = 0;

	if ((i = mmap_file(filename, &map) < 1) || !map) {
		fprintf(stderr, "Error memory-mapping file '%s'\n", filename);
		return 0;
	}

	uint32_t* directory = (uint32_t*)map;
	int max_entries = *directory;
	char dirname[256];
	int outfd;
	int num_written = 0;

	printf("Directory entries: %d\n", max_entries);

	for (int i=0 ; i < max_entries ; ++i) {
		if (directory[1+i] == 0) {
			fprintf(stderr, "Aborted, directory ends at entry %i\n", i);
			break;
		}
		struct file_entry* fe = (struct file_entry*)(map + directory[1+i]);
		snprintf(dirname, sizeof(dirname), "%.*s", fe->filename_len, fe->filename);
		printf("Entry %d at offset 0x%x, %d bytes; '%s' ... ", i, directory[1+i], fe->size, dirname);

		outfd = open(dirname, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR);
		if (outfd == -1) {
			/* If we can't write the file, maybe we need to create the directories first ... */
			if (!mkpath(dirname, 0770, MKPATH_WITH_FILENAME)) {
				printf("error creating directory.\n");
				continue;
			} else {
				printf("[new dir] ");
			}
			outfd = open(dirname, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR);
		}
		if (outfd != -1) {
			write(outfd, (void*)(map + directory[1+i] + sizeof(struct file_entry) + fe->filename_len), fe->size);
			close(outfd);
			printf("written.\n");
			++num_written;
		} else  {
			printf("error writing file.\n");
		}
	}

	return num_written;
}

int main(int argc, char* argv[])
{
	char* std_files[] = { "data.dat", "resource.dat", NULL };
	char** files = std_files;
	int num_written = 0;

	if (argc > 1)
		files = &argv[1];

	while (*files) {
		printf("<<%s\n", *files);
		num_written += ftl_unpak(files[0]);
		++files;
	}

	printf("%d file(s) written.\n", num_written);

	return EXIT_SUCCESS;
}


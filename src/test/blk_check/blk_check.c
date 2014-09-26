/*
 * Copyright (c) 2014, Intel Corporation
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in
 *       the documentation and/or other materials provided with the
 *       distribution.
 *
 *     * Neither the name of Intel Corporation nor the names of its
 *       contributors may be used to endorse or promote products derived
 *       from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * blk_check.c -- unit test for pmemblk_check
 *
 * usage: blk_check bsize file seed nthread nops
 *
 */

#include "unittest.h"

static const size_t Bsize = 128;
static PMEMblk *Handle;

/*
 * construct -- build a buffer for writing
 */
void
construct(int *ordp, unsigned char *buf)
{
	for (int i = 0; i < Bsize; i++)
		buf[i] = *ordp;

	(*ordp)++;

	if (*ordp > 255)
		*ordp = 1;
}


int
main(int argc, char *argv[])
{
	START(argc, argv, "blk_check");

	if (argc < 2)
		FATAL("usage: %s file check1 check2 ...", argv[0]);

	char *file_name = argv[1];

	/*
	 * This will basically format the file.
	 */
	int fd = OPEN(file_name, O_RDWR);

	if ((Handle = pmemblk_map(fd, 4096)) == NULL)
		FATAL("!%s: pmemblk_map", file_name);

	close(fd);

	pmemblk_unmap(Handle);


	/*
	 * Perform different tests according to id number specified
	 * on the command line.
	 *
	 * First we prepare a filure case.
	 */
	fd = OPEN(file_name, O_RDWR);
	if ((Handle = pmemblk_map(fd, 4096)) == NULL)
		FATAL("!%s: pmemblk_map", file_name);

	for (int count = 2; count < argc; ++count) {
		int test = strtoul(argv[count], NULL, 0);

		switch (test) {
		case 0:
			/* test for bad address */
			argv[1] = argv[2];
			break;

		case 1:
			break;

		case 2:
			break;

		default:
			/* unknown test case */
			break;
		}
	}




	close(fd);

	pmemblk_unmap(Handle);


	/*
	 * Now we verify the consistency of the data, which is inconsistent
	 * according to the test case choosen.
	 */
	int result = pmemblk_check(file_name);
	if (result < 0)
		OUT("!%s: pmemblk_check", file_name);
	else if (result == 0)
		OUT("%s: pmemblk_check: not consistent", file_name);

	DONE(NULL);
}

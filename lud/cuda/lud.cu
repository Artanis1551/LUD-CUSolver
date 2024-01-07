/*
 * =====================================================================================
 *
 *       Filename:  lud.cu
 *
 *    Description:  The main wrapper for the suite
 *
 *        Version:  1.0
 *        Created:  10/22/2009 08:40:34 PM
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  Liang Wang (lw2aw), lw2aw@virginia.edu
 *        Company:  CS@UVa
 *
 * =====================================================================================
 */

#include <cuda.h>
#include <stdio.h>
#include <unistd.h>
#include <getopt.h>
#include <stdlib.h>
#include <assert.h>

#include "common.h"

//Defines kernel sizes (block size)
#ifdef RD_WG_SIZE_0_0
        #define BLOCK_SIZE RD_WG_SIZE_0_0
#elif defined(RD_WG_SIZE_0)
        #define BLOCK_SIZE RD_WG_SIZE_0
#elif defined(RD_WG_SIZE)
        #define BLOCK_SIZE RD_WG_SIZE
#else
        #define BLOCK_SIZE 16
#endif

//initializes do_verify
static int do_verify = 0;
static int cuSolve = 0;

//Options for matrix
static struct option long_options[] = {
  /* name, has_arg, flag, val */
  {"input", 1, NULL, 'i'},
  {"size", 1, NULL, 's'},
  {"cuSolver", 0, NULL, 'c'},
  {"verify", 0, NULL, 'v'},
  {0,0,0,0}
};

//Creates function for kernel launch
extern void
lud_cuda(double *d_m, int matrix_dim, int cuSolve);


int
main ( int argc, char *argv[] )
{
  printf("WG size of kernel = %d X %d\n", BLOCK_SIZE, BLOCK_SIZE);

  int matrix_dim = 32; /* default matrix_dim */
  int opt, option_index = 1;
  func_ret_t ret;
  const char *input_file = NULL;
  double *d_m, *mm;
  double *m;
  stopwatch sw;

  //Gets option from run call (loops for all options)
  while ((opt = getopt_long(argc, argv, "::vcs:i:", 
                            long_options, &option_index)) != -1 ) {
    switch(opt){
    //if option -i read input values from input file
    case 'i':
      input_file = optarg;
      break;
    //if option -v enable verification
    case 'v':
      do_verify = 1;
      break;
    //Manually sets matrix_dim to value in run call
    case 's':
      matrix_dim = atoi(optarg);
      printf("Generate input matrix internally, size =%d\n", matrix_dim);
      // fprintf(stderr, "Currently not supported, use -i instead\n");
      // fprintf(stderr, "Usage: %s [-v] [-s matrix_size|-i input_file]\n", argv[0]);
      // exit(EXIT_FAILURE);
      break;
    case 'c':
      cuSolve = 1;
    break;
    //Indicates that option is invalid
    case '?':
      fprintf(stderr, "invalid option\n");
      break;
    //Indicates that argument is missing
    case ':':
      fprintf(stderr, "missing argument\n");
      break;
    //Tells user how to use options
    default:
      fprintf(stderr, "Usage: %s [-v] [-s matrix_size|-i input_file]\n",
	      argv[0]);
      exit(EXIT_FAILURE);
    }
  }
  
  //If any elements are left that are not options it prints how to use options
  if ( (optind < argc) || (optind == 1)) {
    fprintf(stderr, "Usage: %s [-v] [-s matrix_size|-i input_file]\n", argv[0]);
    exit(EXIT_FAILURE);
  }

  //If option was -i this code calls a function that reads a file. and prints if read failed
  if (input_file) {
    printf("Reading matrix from file %s\n", input_file);
    ret = create_matrix_from_file(&m, input_file, &matrix_dim);
    if (ret != RET_SUCCESS) {
      m = NULL;
      fprintf(stderr, "error create matrix from file %s\n", input_file);
      exit(EXIT_FAILURE);
    }
  } //If input_file is not set it creates the matrix
  else if (matrix_dim) {
    printf("Creating matrix internally size=%d\n", matrix_dim);
    ret = create_matrix(&m, matrix_dim);
    if (ret != RET_SUCCESS) {
      m = NULL;
      fprintf(stderr, "error create matrix internally size=%d\n", matrix_dim);
      exit(EXIT_FAILURE);
    }
  }

  //Else say no input file was specified
  else {
    printf("No input file specified!\n");
    exit(EXIT_FAILURE);
  }

  //If do_verify is 1 print matrix before LUD and duplicate matrix
  if (do_verify){
    //printf("Before LUD\n");
    //print_matrix(m, matrix_dim);
    matrix_duplicate(m, &mm, matrix_dim);
  }

  //Allocate memory and begin timing and copy memory
  cudaMalloc((void**)&d_m, 
             matrix_dim*matrix_dim*sizeof(double));

  /* beginning of timing point */
  stopwatch_start(&sw);
  cudaMemcpy(d_m, m, matrix_dim*matrix_dim*sizeof(double), 
	     cudaMemcpyHostToDevice);

  //Kernel launch
  lud_cuda(d_m, matrix_dim, cuSolve);
  

  //Copy back memory
  cudaMemcpy(m, d_m, matrix_dim*matrix_dim*sizeof(double), 
	     cudaMemcpyDeviceToHost);

  /* end of timing point */
  stopwatch_stop(&sw);
  printf("Time consumed(ms): %lf\n", 1000*get_interval_by_sec(&sw));

  cudaFree(d_m);

  //If do_verify is 1 print matrix after LUD and verify lud by comparing gpu implementation with cpu implementation
  if (do_verify){
    //printf("After LUD\n");
    //print_matrix(m, matrix_dim);
    printf(">>>Verify<<<<\n");
    lud_verify(mm, m, matrix_dim, cuSolve); 
    free(mm);
  }

  free(m);

  return EXIT_SUCCESS;
}				/* ----------  end of function main  ---------- */

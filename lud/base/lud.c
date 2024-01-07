/*
 * =====================================================================================
 *
 *       Filename:  suite.c
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

#include <stdio.h>
#include <unistd.h>
#include <getopt.h>
#include <stdlib.h>
#include <assert.h>

#include "common.h"

static int do_verify = 0;

//options for matrix
static struct option long_options[] = {
      /* name, has_arg, flag, val */
      {"input", 1, NULL, 'i'},
      {"size", 1, NULL, 's'},
      {"verify", 0, NULL, 'v'},
      {0,0,0,0}
};

//Creates function for CPU LU Decomposition
extern void
lud_base(double *m, int matrix_dim);

int
main ( int argc, char *argv[] )
{
  //Initialize matrix
  int matrix_dim = 32; /* default matrix_dim */
  int opt, option_index=0;
  func_ret_t ret;
  const char *input_file = NULL;
  double *m;
  double *mm;
  stopwatch sw;

  //Gets option from run call (loops for all options)
  while ((opt = getopt_long(argc, argv, "::vs:i:", 
                            long_options, &option_index)) != -1 ) {
      switch(opt){
        //if option -i read input val from input file
        case 'i':
          input_file = optarg;
          break;
        //if option -v we enable verification
        case 'v':
          do_verify = 1;
          break;
        //should manually set matri_dim to value in run call. But instead says currently not supported and recommends -i instead
        case 's':
          matrix_dim = atoi(optarg);
          fprintf(stderr, "Currently not supported, use -i instead\n");
          fprintf(stderr, "Usage: %s [-v] [-s matrix_size|-i input_file]\n", argv[0]);
          exit(EXIT_FAILURE);
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
  } else {
    printf("No input file specified!\n");
    exit(EXIT_FAILURE);
  } 

  //If option -v is chosen: prints matrix Before LUD
  if (do_verify){
    printf("Before LUD\n");
    print_matrix(m, matrix_dim);
    matrix_duplicate(m, &mm, matrix_dim);
  }

  //Code for taking time, also calls lud_Base where LUD takes place
  stopwatch_start(&sw);
  lud_base(m, matrix_dim);
  stopwatch_stop(&sw);
  printf("Time consumed(ms): %lf\n", 1000*get_interval_by_sec(&sw));

  //Verifies
  if (do_verify){
    printf("After LUD\n");
    print_matrix(m, matrix_dim);
    printf(">>>Verify<<<<\n");
    lud_verify(mm, m, matrix_dim); 
    free(mm);
  }

  free(m);

  return EXIT_SUCCESS;
}				/* ----------  end of function main  ---------- */

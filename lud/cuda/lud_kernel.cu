#include <cuda.h>
#include <stdio.h>
#include <cusolverDn.h>

#include "common.h"

#ifdef RD_WG_SIZE_0_0
        #define BLOCK_SIZE RD_WG_SIZE_0_0
#elif defined(RD_WG_SIZE_0)
        #define BLOCK_SIZE RD_WG_SIZE_0
#elif defined(RD_WG_SIZE)
        #define BLOCK_SIZE RD_WG_SIZE
#else
        #define BLOCK_SIZE 16
#endif


__global__ void 
lud_diagonal(double *m, int matrix_dim, int offset)
{
  int i,j;
  __shared__ double shadow[BLOCK_SIZE][BLOCK_SIZE];

  int array_offset = offset*matrix_dim+offset;
  for(i=0; i < BLOCK_SIZE; i++){
    shadow[i][threadIdx.x]=m[array_offset+threadIdx.x];
    array_offset += matrix_dim;
  }
  __syncthreads();
  for(i=0; i < BLOCK_SIZE-1; i++) {

    if (threadIdx.x>i){
      for(j=0; j < i; j++)
        shadow[threadIdx.x][i] -= shadow[threadIdx.x][j]*shadow[j][i];
      shadow[threadIdx.x][i] /= shadow[i][i];
    }

    __syncthreads();
    if (threadIdx.x>i){

      for(j=0; j < i+1; j++)
        shadow[i+1][threadIdx.x] -= shadow[i+1][j]*shadow[j][threadIdx.x];
    }
    __syncthreads();
  }

  /* 
     The first row is not modified, it
     is no need to write it back to the
     global memory

   */
  array_offset = (offset+1)*matrix_dim+offset;
  for(i=1; i < BLOCK_SIZE; i++){
    m[array_offset+threadIdx.x]=shadow[i][threadIdx.x];
    array_offset += matrix_dim;
  }
}

__global__ void
lud_perimeter(double *m, int matrix_dim, int offset)
{
  __shared__ double dia[BLOCK_SIZE][BLOCK_SIZE];
  __shared__ double peri_row[BLOCK_SIZE][BLOCK_SIZE];
  __shared__ double peri_col[BLOCK_SIZE][BLOCK_SIZE];

  int i,j, array_offset;
  int idx;

  if (threadIdx.x < BLOCK_SIZE) {
    idx = threadIdx.x;
    
    array_offset = offset*matrix_dim+offset;
    for (i=0; i < BLOCK_SIZE/2; i++){
      dia[i][idx]=m[array_offset+idx];
      array_offset += matrix_dim;
    }
    
    array_offset = offset*matrix_dim+offset;
    for (i=0; i < BLOCK_SIZE; i++) {
      peri_row[i][idx]=m[array_offset+(blockIdx.x+1)*BLOCK_SIZE+idx];
      array_offset += matrix_dim;
    }

  } else {
    idx = threadIdx.x-BLOCK_SIZE;
    
    array_offset = (offset+BLOCK_SIZE/2)*matrix_dim+offset;
    for (i=BLOCK_SIZE/2; i < BLOCK_SIZE; i++){
      dia[i][idx]=m[array_offset+idx];
      array_offset += matrix_dim;
    }
    
    array_offset = (offset+(blockIdx.x+1)*BLOCK_SIZE)*matrix_dim+offset;
    for (i=0; i < BLOCK_SIZE; i++) {
      peri_col[i][idx] = m[array_offset+idx];
      array_offset += matrix_dim;
    }
  
  }
  __syncthreads();

/* this version works ok on hardware, but not gpgpusim
 **************************************************************
  if (threadIdx.x < BLOCK_SIZE) { //peri-row
    idx=threadIdx.x;
    for(i=1; i < BLOCK_SIZE; i++){
      for (j=0; j < i; j++)
        peri_row[i][idx]-=dia[i][j]*peri_row[j][idx];
    }

    
    array_offset = (offset+1)*matrix_dim+offset;
    for(i=1; i < BLOCK_SIZE; i++){
      m[array_offset+(blockIdx.x+1)*BLOCK_SIZE+idx] = peri_row[i][idx];
      array_offset += matrix_dim;
    }
  } else { //peri-col
    idx=threadIdx.x - BLOCK_SIZE;
    for(i=0; i < BLOCK_SIZE; i++){
      for(j=0; j < i; j++)
        peri_col[idx][i]-=peri_col[idx][j]*dia[j][i];
      peri_col[idx][i] /= dia[i][i];
    }

    __syncthreads();
    
    array_offset = (offset+(blockIdx.x+1)*BLOCK_SIZE)*matrix_dim+offset;
    for(i=0; i < BLOCK_SIZE; i++){
      m[array_offset+idx] =  peri_col[i][idx];
      array_offset += matrix_dim;
    }
  }
***************************************************************/
  if (threadIdx.x < BLOCK_SIZE) { //peri-row
    idx=threadIdx.x;
    for(i=1; i < BLOCK_SIZE; i++){
      for (j=0; j < i; j++)
        peri_row[i][idx]-=dia[i][j]*peri_row[j][idx];
    }
  } else { //peri-col
    idx=threadIdx.x - BLOCK_SIZE;
    for(i=0; i < BLOCK_SIZE; i++){
      for(j=0; j < i; j++)
        peri_col[idx][i]-=peri_col[idx][j]*dia[j][i];
      peri_col[idx][i] /= dia[i][i];
    }
  }

  __syncthreads();
    
  if (threadIdx.x < BLOCK_SIZE) { //peri-row
    idx=threadIdx.x;
    array_offset = (offset+1)*matrix_dim+offset;
    for(i=1; i < BLOCK_SIZE; i++){
      m[array_offset+(blockIdx.x+1)*BLOCK_SIZE+idx] = peri_row[i][idx];
      array_offset += matrix_dim;
    }
  } else { //peri-col
    idx=threadIdx.x - BLOCK_SIZE;
    array_offset = (offset+(blockIdx.x+1)*BLOCK_SIZE)*matrix_dim+offset;
    for(i=0; i < BLOCK_SIZE; i++){
      m[array_offset+idx] =  peri_col[i][idx];
      array_offset += matrix_dim;
    }
  }

}

__global__ void
lud_internal(double *m, int matrix_dim, int offset)
{
  __shared__ double peri_row[BLOCK_SIZE][BLOCK_SIZE];
  __shared__ double peri_col[BLOCK_SIZE][BLOCK_SIZE];

  int i;
  double sum;

  int global_row_id = offset + (blockIdx.y+1)*BLOCK_SIZE;
  int global_col_id = offset + (blockIdx.x+1)*BLOCK_SIZE;

  peri_row[threadIdx.y][threadIdx.x] = m[(offset+threadIdx.y)*matrix_dim+global_col_id+threadIdx.x];
  peri_col[threadIdx.y][threadIdx.x] = m[(global_row_id+threadIdx.y)*matrix_dim+offset+threadIdx.x];

  __syncthreads();

  sum = 0;
  for (i=0; i < BLOCK_SIZE; i++)
    sum += peri_col[threadIdx.y][i] * peri_row[i][threadIdx.x];
  m[(global_row_id+threadIdx.y)*matrix_dim+global_col_id+threadIdx.x] -= sum;


}

void lud_cuda(double *m, int matrix_dim, int choice)
{
  int i=0;
  dim3 dimBlock(BLOCK_SIZE, BLOCK_SIZE);
  
  stopwatch func;

  //If c was chosen as option run cuSolve version otherwise run rodinia implementation
  if(choice == 1)
  {
    printf("Using library\n");
    //Creating cusolver handle and function timer
    stopwatch_start(&func);
    cusolverDnHandle_t handle;
    cusolverDnCreate(&handle);

    //Creating array to store permutation of rows during LU decomposition
    int* devIpiv;
    cudaMalloc((void**)&devIpiv, matrix_dim * sizeof(int));

    //Obtain bufferSize needed for cuSolve LUD
    int bufferSize;
    cusolverDnDgetrf_bufferSize(handle, matrix_dim, matrix_dim, m, matrix_dim, &bufferSize);

    //Allocate memory for buffer
    double* buffer;
    cudaMalloc((void**)&buffer, bufferSize * sizeof(double));

    //Create variable to store error messages from parameters
    int* devInfo;
    cudaMalloc((void**)&devInfo, sizeof(int));

    //Run CuSolve LUD and store error message in status
    cusolverStatus_t status = cusolverDnDgetrf(handle, matrix_dim, matrix_dim, m, matrix_dim, buffer, devIpiv, devInfo);
    cudaDeviceSynchronize();
    
    //Copy over dev info to host info
    int* hostInfo = (int*)malloc(sizeof(int));
    cudaMemcpy(hostInfo, devInfo, sizeof(int), cudaMemcpyDeviceToHost);
    
    //Check for errors from cusolverDnDgetrf and print them out if error occurs
    if (status != CUSOLVER_STATUS_SUCCESS || *hostInfo != 0) {
      fprintf(stderr, "cusolverDnDgetrf failed. Status: %d, devInfo: %d\n", status, *hostInfo);
    } else {
      printf("cusolverDnDgetrf succeeded\n");
    }

    //free allocated memory
    cudaFree(devIpiv);
    cudaFree(buffer);
    cudaFree(devInfo);
    
    //Destroy handle and stop function timer
    cusolverDnDestroy(handle);
    stopwatch_stop(&func);

  //If option c is not chosen rodinia implementation is executed
  }else{
    printf("Using rodinia\n");
    stopwatch_start(&func);
    for (i=0; i < matrix_dim-BLOCK_SIZE; i += BLOCK_SIZE) {
      lud_diagonal<<<1, BLOCK_SIZE>>>(m, matrix_dim, i);
      lud_perimeter<<<(matrix_dim-i)/BLOCK_SIZE-1, BLOCK_SIZE*2>>>(m, matrix_dim, i);
      dim3 dimGrid((matrix_dim-i)/BLOCK_SIZE-1, (matrix_dim-i)/BLOCK_SIZE-1);
      lud_internal<<<dimGrid, dimBlock>>>(m, matrix_dim, i);
    }
    lud_diagonal<<<1,BLOCK_SIZE>>>(m, matrix_dim, i);
    cudaDeviceSynchronize();
    stopwatch_stop(&func);
  }

  printf("Time consumed for only functons(ms): %lf\n", 1000*get_interval_by_sec(&func));
}



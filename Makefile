CC = gcc
NVCC = /usr/local/cuda-12.3/bin/nvcc

DEFS += \
		-DGPU_TIMER \
		$(SPACE)

NVCCFLAGS += -I../common \
			 -O3 \
			 -use_fast_math \
			 -lm \
			 $(SPACE)

CFLAGS += -I../common \
			-I/usr/include/cuda \
			-I/usr/local/cuda/include \
		  	-O3 \
		  	-Wall \
		  	$(SPACE)
		  
LDFLAGS += -L/usr/local/cuda-12.3/lib64 -lcusolver
# Add source files here
EXECUTABLE  := lud_cuda
# Cuda source files (compiled with cudacc)
CUFILES     := lud_kernel.cu
# C/C++ source files (compiled with gcc / c++)
CCFILES     := lud.c lud_cuda.c ../common/common.c

OBJS = ../common/common.o lud.o lud_kernel.o

.PHONY: all clean 
all : $(EXECUTABLE)

.c.o : 
	$(NVCC) $(KERNEL_DIM) $(NVCCFLAGS) $(DEFS) -o $@ -c $<

%.o:	%.cu 
	$(NVCC) $(KERNEL_DIM) $(NVCCFLAGS) $(DEFS) -o $@ -c $<


$(EXECUTABLE) : $(OBJS)
	$(NVCC) $(NVCCFLAGS) -o $@  $? $(LDFLAGS) --gpu-architecture=compute_89 --gpu-code=sm_89,compute_89 -lcusolver

clean:
	rm -f $(EXECUTABLE) $(OBJS) *.linkinfo

# Build

To build the code, run the following command from inside the "lud" folder:

```bash
make clean
make
```

# Input generation
In the "lud/tools" folder build the tool using:
```bash
make
```
Then to generate data files run (replace 32 with the desired input size) from inside the "lud" folder:
```bash
./tools/gen_input 32
```
This will create a file called 32.dat (or any other number that was used as the input size)

# Running the benchmark
To run the executable lud_cuda, use the following options:

* -c: Use CUSolver. Without it the default Rodinia implementation will be used.
* -v: To verify results of the benchmark. It takes some time to verify with input sizes larger than 8000.
* -s <number>: Pass the input size for the matrix that will be generated for the benchmark. Cannot be used with the -i option.
* -i <file path>: Pass a file path containing the matrix on which the LU decomposition will be applied. Cannot be used with the -s option.
 
For example, to run the executable with CUSolver and verify the results, use the following command:
```bash
./lud_cuda -v -c -s 8192
```

// Compiled by the CUDA example test; the runners have no GPU, so it is only built.
#include <cstdio>

__global__ void hello() { printf("hello from the GPU\n"); }

int main() {
  hello<<<1, 1>>>();
  return cudaDeviceSynchronize() == cudaSuccess ? 0 : 1;
}

#include "utils.h"
#include <stdio.h>
#include <math.h>       /* ceil */

#include <iostream>
#include <string>

// Function calling the kernel to operate
void rgba_to_grey(uchar4 * const d_rgbaImage,
                  unsigned char* const d_greyImage, 
                  size_t numRows, size_t numCols);

//include the definitions of the above functions for this homework
#include "preprocess.cpp"

using namespace std;
using namespace cv;

// Max Threads per block in GeForce 210
#define TxB 512

__global__
void rgba_to_grey_kernel(const uchar4* const rgbaImage,
                       unsigned char* const greyImage,
                       int numRows, int numCols)
{
  // The mapping from components of a uchar4 to RGBA is:
  // .x -> R ; .y -> G ; .z -> B ; .w -> A
  //
  //The output (greyImage) at each pixel should be the result of
  //applying the formula: output = .299f * R + .587f * G + .114f * B;
  //Note: We will be ignoring the alpha channel for this conversion
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  uchar4 px = rgbaImage[i]; // thread pixel to process
  greyImage[i] = .299f * px.x +
                 .587f * px.y +
                 .114f * px.z;
}

void rgba_to_grey(uchar4 * const d_rgbaImage,
                  unsigned char* const d_greyImage, size_t numRows, size_t numCols)
{

  // Since it does not matter the relative position of a pixel
  // the block - grid assign strategy will simply be to cover
  // all pixels secuencially in 'x' axis
  long long int total_px = numRows * numCols;  // total pixels
  long int grids_n = ceil(total_px / TxB); // grids numer
  const dim3 blockSize(TxB, 1, 1);
  const dim3 gridSize(grids_n, 1, 1);
  rgba_to_grey_kernel<<<gridSize, blockSize>>>(d_rgbaImage, d_greyImage, numRows, numCols);
  
  cudaDeviceSynchronize(); checkCudaErrors(cudaGetLastError());
}

int main(int argc, char **argv) {
  uchar4        *h_rgbaImage, *d_rgbaImage;
  unsigned char *h_greyImage, *d_greyImage;

  string input_file;
  string output_file;

  //make sure the context initializes ok
  checkCudaErrors(cudaFree(0));

  switch (argc)
  {
	case 2:
	  input_file = string(argv[1]);
	  output_file = string(argv[1]);
	  break;
  case 3:
    input_file = string(argv[1]);
	  output_file = string(argv[2]);
    break;
	default:
      cerr << "Usage: ./to_bw input_file [output_filename]" << endl;
      exit(1);
  }
  //load the image and give us our input and output pointers
  preProcess(&h_rgbaImage, &h_greyImage, &d_rgbaImage, &d_greyImage, input_file);

  //call the cuda code
  rgba_to_grey(d_rgbaImage, d_greyImage, numRows(), numCols());

  size_t numPixels = numRows()*numCols();
  checkCudaErrors(cudaMemcpy(h_greyImage, d_greyImage, sizeof(unsigned char) * numPixels, cudaMemcpyDeviceToHost));

  /* Output the grey image */
  Mat output(numRows(), numCols(), CV_8UC1, (void*)h_greyImage);
  //output the image
  imwrite(output_file.c_str(), output);

  /* Cleanup */
  cudaFree(d_rgbaImage__);
  cudaFree(d_greyImage__);

  return 0;
}

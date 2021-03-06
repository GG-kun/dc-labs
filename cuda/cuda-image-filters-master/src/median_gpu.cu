#include <iostream>
#include <cstdio>
#include "opencv2/core/core.hpp"
#include "opencv2/highgui/highgui.hpp"
#include <cuda_runtime.h>
#include "helper_cuda.h"

#include "opencv2/calib3d/calib3d.hpp"
#include "opencv2/imgproc/imgproc.hpp"
#include "opencv2/opencv.hpp"
#include "opencv2/gpu/gpu.hpp"
#include <stdio.h>
#include <ctime>
#include <sys/time.h>

using namespace std;
using namespace cv;

const int BLOCKDIM = 32;
const int MAX_WINDOW = 11;
__device__ const int FILTER_SIZE = 9;
__device__ const int FILTER_HALFSIZE = FILTER_SIZE >> 1;

__device__ void sort_bubble(float *x, int n_size) 
{
	for (int i = 0; i < n_size - 1; i++) 
	{
		for(int j = 0; j < n_size - i - 1; j++) 
		{
			if (x[j] > x[j+1]) 
			{
				float temp = x[j];
				x[j] = x[j+1];
				x[j+1] = temp;
			}
		}
	}
}

__device__ int index(int x, int y, int width) 
{
	return (y * width) + x;
}

__device__ int clamp(int value, int bound) 
{
	if (value < 0) {
		return 1;
	}
	if (value < bound) {
		return value;
	}
	return bound - 1;
}

__global__ void median_filter_2d(unsigned char* input, unsigned char* output, int width, int height)
{
	const int x = blockIdx.x * blockDim.x + threadIdx.x;
	const int y = blockIdx.y * blockDim.y + threadIdx.y;

	if((x<width) && (y<height))
	{
		const int color_tid = index(x,y,width);
		float windowMedian[MAX_WINDOW*MAX_WINDOW];
		int windowElements = 0;
		for (int x_iter = x - FILTER_HALFSIZE; x_iter <= x + FILTER_HALFSIZE; x_iter ++)
		 {
			for (int y_iter = y - FILTER_HALFSIZE; y_iter <= y + FILTER_HALFSIZE; y_iter++)
			 {
				if (0<=x_iter && x_iter < width && 0 <= y_iter && y_iter < height)
				{
					windowMedian[windowElements++] = input[index(x_iter,y_iter,width)];
				}
			}
		}
		sort_bubble(windowMedian,windowElements);
		output[color_tid] = windowMedian[windowElements/2];
	}
}

__global__ void median_filter_2d_sm(unsigned char* input, unsigned char* output, int width, int height)
{
	__shared__ int sharedPixels[BLOCKDIM + FILTER_SIZE][BLOCKDIM + FILTER_SIZE];
	
	const int x = blockIdx.x * blockDim.x + threadIdx.x;
	const int y = blockIdx.y * blockDim.y + threadIdx.y;

	int xBlockLimit_max = blockDim.x - FILTER_HALFSIZE - 1;
	int yBlockLimit_max = blockDim.y - FILTER_HALFSIZE - 1;
	int xBlockLimit_min = FILTER_HALFSIZE;
	int yBlockLimit_min = FILTER_HALFSIZE;

	if (threadIdx.x > xBlockLimit_max && threadIdx.y > yBlockLimit_max) {
		int i = index(clamp(x + FILTER_HALFSIZE,width), clamp(y + FILTER_HALFSIZE,height), width);
	    	unsigned int pixel = input[i];
		sharedPixels[threadIdx.x + 2*FILTER_HALFSIZE][threadIdx.y + 2*FILTER_HALFSIZE] = pixel;
	}
	if (threadIdx.x > xBlockLimit_max && threadIdx.y < yBlockLimit_min) {
		int i = index(clamp(x + FILTER_HALFSIZE,width), clamp(y - FILTER_HALFSIZE,height), width);
		unsigned int pixel = input[i];
		sharedPixels[threadIdx.x + 2*FILTER_HALFSIZE][threadIdx.y] = pixel;
	}
	if (threadIdx.x < xBlockLimit_min && threadIdx.y > yBlockLimit_max) {
		int i = index(clamp(x - FILTER_HALFSIZE,width), clamp(y + FILTER_HALFSIZE,height), width);
		unsigned int pixel = input[i];
		sharedPixels[threadIdx.x][threadIdx.y + 2*FILTER_HALFSIZE] = pixel;
	}
	if (threadIdx.x < xBlockLimit_min && threadIdx.y < yBlockLimit_min) {
		int i = index(clamp(x - FILTER_HALFSIZE,width), clamp(y - FILTER_HALFSIZE,height), width);
		unsigned int pixel = input[i];
		sharedPixels[threadIdx.x][threadIdx.y] = pixel;
	}
	if (threadIdx.x < xBlockLimit_min) {
		int i = index(clamp(x - FILTER_HALFSIZE,width), clamp(y,height), width);
		unsigned int pixel = input[i];
		sharedPixels[threadIdx.x][threadIdx.y + FILTER_HALFSIZE] = pixel;
	}
	if (threadIdx.x > xBlockLimit_max) {
		int i = index(clamp(x + FILTER_HALFSIZE,width), clamp(y,height), width);
		unsigned int pixel = input[i];
		sharedPixels[threadIdx.x + 2*FILTER_HALFSIZE][threadIdx.y + FILTER_HALFSIZE] = pixel;
	}
	if (threadIdx.y < yBlockLimit_min) {
		int i = index(clamp(x,width), clamp(y - FILTER_HALFSIZE,height), width);
		unsigned int pixel = input[i];
		sharedPixels[threadIdx.x + FILTER_HALFSIZE][threadIdx.y] = pixel;
	}
	if (threadIdx.y > yBlockLimit_max) {
		int i = index(clamp(x,width), clamp(y + FILTER_HALFSIZE,height), width);
		unsigned int pixel = input[i];
		sharedPixels[threadIdx.x + FILTER_HALFSIZE][threadIdx.y + 2*FILTER_HALFSIZE] = pixel;
	}
	int i = index(x, y, width);
	unsigned int pixel = input[i];
	sharedPixels[threadIdx.x + FILTER_HALFSIZE][threadIdx.y + FILTER_HALFSIZE] = pixel;

	__syncthreads();

	if((x<width) && (y<height))
	{
		const int color_tid = y * width + x;
		float windowMedian[MAX_WINDOW*MAX_WINDOW];
		int windowElements = 0;

		for (int x_iter = 0; x_iter < FILTER_SIZE; x_iter ++) 
		{
			for (int y_iter = 0; y_iter < FILTER_SIZE; y_iter++) 
			{
				if (0<=x_iter && x_iter < width && 0 <= y_iter && y_iter < height) 
				{
					windowMedian[windowElements++] = sharedPixels[threadIdx.x + x_iter][threadIdx.y + y_iter];
				}
			}
		}
		sort_bubble(windowMedian,windowElements);
		output[color_tid] = windowMedian[windowElements/2];
	}
}


void median_filter_wrapper(const cv::Mat& input, cv::Mat& output)
{
	unsigned char *d_input, *d_output;
	
	cudaError_t cudaStatus;	
	
	cudaStatus = cudaMalloc<unsigned char>(&d_input,input.rows*input.cols);
	checkCudaErrors(cudaStatus);	
	cudaStatus = cudaMalloc<unsigned char>(&d_output,output.rows*output.cols);
	checkCudaErrors(cudaStatus);

	cudaStatus = cudaMemcpy(d_input,input.ptr(),input.rows*input.cols,cudaMemcpyHostToDevice);
	checkCudaErrors(cudaStatus);	
	
	const dim3 block(BLOCKDIM,BLOCKDIM);
	const dim3 grid(input.cols/BLOCKDIM, input.rows/BLOCKDIM);

	median_filter_2d<<<grid,block>>>(d_input,d_output,input.cols,input.rows);

	cudaStatus = cudaDeviceSynchronize();
	checkCudaErrors(cudaStatus);	

	cudaStatus = cudaMemcpy(output.ptr(),d_output,output.rows*output.cols,cudaMemcpyDeviceToHost);
	checkCudaErrors(cudaStatus);	

	cudaStatus = cudaFree(d_input);
	checkCudaErrors(cudaStatus);	
	cudaStatus = cudaFree(d_output);
	checkCudaErrors(cudaStatus);	
}

int main(int argc, char* argv[])
{
	if (argc >= 2)
    {
        cout << " Usage: program image.format [output.format]" << endl;
        return -1;
    }

	string imagePath = argv[1];
	Mat input = imread(imagePath,0);
	if(input.empty()) {
		cout<<"Could not load image. Check location and try again."<<endl;
		cin.get();
		return -1;
	}
	Mat output_gpu(input.rows,input.cols,CV_8UC1);
	bilateral_filter_wrapper(input,output_gpu);
	string	outputPath = imagePath;
	if (argc > 2)
    {
        outputPath = argv[2]
    }
	imwrite(outputPath,output_gpu);

	return 0;

}

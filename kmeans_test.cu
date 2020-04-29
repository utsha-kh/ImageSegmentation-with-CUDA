#include <iostream>
#include <chrono>
#include <iomanip>
#include <cfloat>
#include <cmath>
#include <cuda.h>
#include "kmeans_gpu.h"
#include "parser.h"

#define THREAD_SIZE 1024

int n;  // number of data points
int d;  // dimention of input data (usually 2, for 2D data)
int k;  // number of clusterss

__device__ void d_getDistance(float* x1, float* x2, float *ret, int n, int d, int k);
__global__ void d_getRMSE(float* dataPoints, int* labels, float* centeroids, float* ret, int n, int d, int k);

// return L2 distance between two points
float getDistance(float* x1, float* x2){
    float dist = 0;
    for(int i = 0; i < d; i++){
        dist += (x2[i] - x1[i]) * (x2[i] - x1[i]);
    }
    return dist; 
}

// return L2 distance between 2 points
__device__ void d_getDistance(float* x1, float* x2, float *ret, int n, int d, int k){
	float dist = 0;
    for(int i = 0; i < d; i++){
        dist += (x2[i] - x1[i]) * (x2[i] - x1[i]);
    }
    *ret = dist; 
}

// return current Root Mean Squared Error value of all points. This is needed to detect convergence, but not essential in k-means algorithm.
float getRMSE(float** dataPoints, int* labels, float** centeroids){

    float error = 0;
    float* err = new float[n];  // distance between each dataPoints to centeroids
    float *d_dataPoints, *d_centeroids, *d_err; 
    int *d_labels;


    // Allocate memory on GPU
    cudaMalloc(&d_dataPoints, sizeof(float) * n * d);
    cudaMalloc(&d_labels, sizeof(int) * n);
    cudaMalloc(&d_centeroids, sizeof(float) * k * d);
    cudaMalloc(&d_err, sizeof(float) * n);    

    // Flattening both matrix to ease copying to GPU
    float* flattenDataPoints = new float[n * d];
    for(int i = 0; i < n; i++){
        for(int j = 0; j < d; j++){
            flattenDataPoints[i * d + j] = dataPoints[i][j];
        }
    }
    float* flattenCenteroids = new float[n * k];
    for(int i = 0; i < k; i++){
        for(int j = 0; j < d; j++){
            flattenCenteroids[i * d + j] = centeroids[i][j];
        }
    }

    // copy flattened data into GPU
    cudaMemcpy(d_dataPoints, flattenDataPoints, sizeof(float) * n * d, cudaMemcpyHostToDevice);
    cudaMemcpy(d_centeroids, flattenCenteroids, sizeof(float) * k * d, cudaMemcpyHostToDevice);
    cudaMemcpy(d_labels, labels, sizeof(int) * n, cudaMemcpyHostToDevice);
    
    // call the kernel function to compute RMSE values in parallel
    int block_size = n / THREAD_SIZE + (n % THREAD_SIZE != 1);
    d_getRMSE<<<block_size, THREAD_SIZE>>>(d_dataPoints, d_labels, d_centeroids, d_err, n, d, k);
    cudaDeviceSynchronize();

    // copy back the result from GPU to CPU
    cudaMemcpy(err, d_err, sizeof(float) * n, cudaMemcpyDeviceToHost);

    // Summing up computed errors. could be made faster by parallel reduction
    for(int i = 0; i < n; i++){
        error += err[i];
        std::cout << "error[" << i << "] = " << err[i] << std::endl;
    }
    // return actual Root Mean of Squared Errors.
    return sqrt(error / n);
}

// kernel of above function NOTE: this is like helper of RMSE. The error values stored in err[] still needs to be summed up.
__global__ void d_getRMSE(float* dataPoints, int* labels, float* centeroids, float* err, int n, int d, int k){
    int id = blockIdx.x * blockDim.x + threadIdx.x;
    if(id >= n) return;
    d_getDistance(&dataPoints[id * d], &centeroids[labels[id] * d], &err[id], n, d, k); 
}

// initialize each center values u_i to a randomly chosen data point
void initCenters(float** dataPoints, float** centeroids){
    // Each center u[i] should be a random data point x[j], but 
    // generating a non-repeated random number isn't straightforward
    // so I'll do it later
    for(int i = 0; i < k; i++){
        centeroids[i] = dataPoints[i];
    } 
}

float myAbs(float a, float b){
    if(a > b)
        return a - b;
    else
        return b - a;
}

// Checks convergence (d/dt < 0.5%)
bool hasConverged(float prevError, float currentError){
    return myAbs(prevError, currentError) / prevError < 0.005;
}

// Calling this function will do everything for the user
void kMeansClustering(float** dataPoints, int* labels){
    float** centeroids = new float*[k];
    for(int i = 0; i < d; i++){
        centeroids[i] = new float[d];
    }

    initCenters(dataPoints, centeroids);

    int iterations = 0;
    float previousError = FLT_MAX;
    float currentError = 0;
    currentError = getRMSE(dataPoints, labels, centeroids);     //
    std::cout << "Total Error Now: " << std::setprecision(6) << currentError << std::endl;  //

    // while(true){
    //     currentError = getRMSE(dataPoints, labels, centeroids);
    //     if(hasConverged(previousError, currentError)) break;
    //     previousError = currentError;
    //     iterations++;
    //     std::cout << "Total Error Now: " << std::setprecision(6) << currentError << std::endl;
    // }
    std::cout << "# of iterations: " << iterations << std::endl;
}

int main(){

    const char *filename = "input.csv";
    Parser parser(filename);

    n = parser.rows; d = parser.cols; k = 3;

    float** data = parser.rdata;
    int* labels = new int[n];

    kMeansClustering(data, labels);

    //parser.print();

    // parser.toCSV("result.csv", data, labels, n, d);
    return 0;


}

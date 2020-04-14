#ifndef __KMEANS__H
#define __KMEANS__H

#include <iostream>
#include <vector>

using namespace std;

class KMeans{
private:
    int n;  // number of data points
    int d;  // dimension of data points (vectors)
    int k;  // number of clusters
    vector<vector<float>> x;  // input data points
    vector<int> whichSet;  // stores info that which set a vector belong to
    vector<vector<float>> u; // centers of each of k sets
    bool converged;

    // return L2 distance between two points
    float getDistance(vector<float> x1, vector<float> x2);

    // add two vectors
    vector<float> addVector(vector<float> x1, vector<float> x2);

    // initialize each center values u_i to a randomly chosen data point
    void initCenters();

    // Assign each data point x_i to the closest center u_j
    void assignDataPoints();

    // Update each center of sets u_i to the average of all data points who belong to that set
    void updateCenters();

public:
    KMeans(int n, int d, int k, vector<vector<float>> x);

    // Calling this function will do everything for the user
    void kMeansClustering();

};

#endif
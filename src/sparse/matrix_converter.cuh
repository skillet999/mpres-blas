/*
 *  Sparse matrix helper routines
 *
 *  Copyright 2020 by Konstantin Isupov and Ivan Babeshko.
 *
 *  This file is part of the MPRES-BLAS library.
 *
 *  MPRES-BLAS is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  MPRES-BLAS is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with MPRES-BLAS.  If not, see <https://www.gnu.org/licenses/>.
 */


#ifndef MATRIX_CONVERTER_CUH
#define MATRIX_CONVERTER_CUH

#include <algorithm>
#include <vector>
#include <iostream>
#include <fstream>
#include "assert.h"

using namespace std;

/*!
 * Reads metadata from a file that contains a sparse matrix
 * @param filename - path to the file with the matrix
 *
 * @param m - number of rows in matrix (output parameter)
 * @param n - number of columns in matrix (output parameter)
 * @param lines - total number of lines with data (output parameter)
 * @param nzr - maximum number of nonzeros per row in the matrix (output parameter)
 * @param symmetric - true if the input matrix is to be treated as symmetrical; otherwise false
 * @param datatype - type of data according to the matrix market format - real, integer, binary
 */
void read_matrix_properties(const char filename[], int &m, int &n, int &lines, int &nzr, bool &symmetric, string &datatype) {

    //Create stream
    std::ifstream file(filename);

    //Read header
    string head, type, formats, dtype, symmetry;
    file >> head >> type >> formats >> dtype >> symmetry;

    //header checking
    assert(head == "%%MatrixMarket");
    assert((type == "matrix") || (type == "tensor"));
    assert((symmetry == "general") || (symmetry == "symmetric"));

    datatype = dtype;
    symmetric = (symmetry == "symmetric");

    file.seekg(0, ios::beg);

    // Ignore comments headers
    while (file.peek() == '%') {
        file.ignore(2048, '\n');
    }

    // Read number of rows and columns
    file >> m >> n >> lines;

    // Array for storing the number of non-zero elements in each row
    // For zero-initializing the array, we use value initialization in the constructor initialization list
    int *nonZeros = new int[m]();

    // Iterating over the matrix
    for (int l = 0; l < lines; l++) {
        double fileData = 0.0;
        int row = 0, col = 0;
        file >> row >> col >> fileData;
        nonZeros[(row - 1)] = nonZeros[(row - 1)] + 1;
        if (symmetric && (row != col)) {
            nonZeros[(col - 1)] = nonZeros[(col - 1)] + 1;
        }
    }
    nzr = *std::max_element(nonZeros, nonZeros + m);
    delete[] nonZeros;
    file.close();
}


//сортирует 3 массива одинакового размера относительно массива ia (COO rows)
static void sort_coo_rows(const int nnz, double* as, int* ia, int* ja) {
    struct coo {
        double data;
        int cols;
        int rows;
    };
    vector <coo> x(nnz);
    for (int i = 0; i < nnz; i++) {
        x[i].data = as[i];
        x[i].rows = ia[i];
        x[i].cols = ja[i];
    }
    sort(x.begin(), x.end(), [] (const coo a, const coo b) {
        return a.rows < b.rows;
    });
    for (int i = 0; i < nnz; i++) {
        as[i] = x[i].data;
        ia[i] = x[i].rows;
        ja[i] = x[i].cols;
    }
}

//метод, формирующий массив смещений строк IRP (row start pointers array) для CSR-формата из массива IA (COO rows)
static void make_irp_array(const int m, const int nnz, int *ia, int *irp) {
    int p = 0;
    for (int i = 0; i < (m + 1); i++) {
        while (i > ia[p] && p < nnz) {
            p++;
        }
        irp[i] = p;
    }
}

/*!
 * Converts a sparse matrix to the COO format
 * @param filename - path to the file with the matrix
 * @param m - number of rows in the matrix
 * @param lines - total number of lines with data
 * @param symmetric - true if the input matrix is to be treated as symmetrical; otherwise false

 * @param as - coefficients array (COO data): an array of size lines containing a matrix data in the COO format (output parameter)
 * @param ia - row indices array (COO rows): an array of size lines containing the row indices (output parameter)
 * @param ja - column indices array (COO cols): an array of size lines containing the column indices (output parameter)
 */
void convert_to_coo(const char filename[], const int m, const int lines, bool symmetric, double *as, int *ia, int *ja) {

    std::ifstream file(filename);

    // Ignore comments headers
    while (file.peek() == '%') file.ignore(2048, '\n');
    //Skip one line with the matrix properties
    file.ignore(std::numeric_limits<std::streamsize>::max(), '\n');

    int j = lines;

    // Iterating over the matrix
    for (int l = 0; l < lines; l++) {
        double fileData = 0.0;
        int row = 0, col = 0;
        file >> row >> col >> fileData;
        as[l] = fileData;
        ja[l] = col - 1;
        ia[l] = row - 1;
        if (symmetric && (row != col)) {
            as[j] = fileData;
            ja[j] = row - 1;
            ia[j] = col - 1;
            j++;
        }
    }
    file.close();

    int nnz = 0;
    if (symmetric){
        nnz = (lines - m) * 2 + m;
    } else {
        nnz = lines;
    }

    sort_coo_rows(nnz, as, ia, ja);
}

/*!
 * Converts a sparse matrix to the ELLPACK format
 * @param filename - path to the file with the matrix
 * @param m - number of rows in the matrix
 * @param nzr - maximum number of nonzeros per row in the matrix
 * @param lines - total number of lines with data
 * @param symmetric - true if the input matrix is to be treated as symmetrical; otherwise false
 * @param as - coefficients array (ELLPACK data): an array of size m * nzr containing a matrix in the ELLPACK format (output parameter)
 * @param ja - column indices array (ELLPACK indices): an array of size m * nzr containing the indices of nonzero elements in the matrix (output parameter)
 */
void convert_to_ellpack(const char filename[], const int m, const int nzr, const int lines, bool symmetric, double *as, int *ja) {

    //Set default values
    std::fill(ja, ja + m * nzr, -1);
    std::fill(as, as + m * nzr, 0);

    //Create stream
    std::ifstream file(filename);

    // Ignore comments headers
    while (file.peek() == '%') file.ignore(2048, '\n');
    //Skip one line with the matrix properties
    file.ignore(std::numeric_limits<std::streamsize>::max(), '\n');

    int *colNum = new int[m]();

    // Iterating over the matrix
    for (int l = 0; l < lines; l++) {
        double fileData = 0.0;
        int row = 0, col = 0;
        file >> row >> col >> fileData;
        as[colNum[(row - 1)] * m + (row - 1)] = fileData;
        ja[colNum[(row - 1)] * m + (row - 1)] = (col - 1);
        colNum[row - 1]++;
        if (symmetric && (row != col)) {
            as[colNum[(col - 1)] * m + (col - 1)] = fileData;
            ja[colNum[(col - 1)] * m + (col - 1)] = (row - 1);
            colNum[col - 1]++;
        }
    }
    delete[] colNum;
    file.close();
}

/*!
 * Converts a sparse matrix to the CSR format
 * @param filename - path to the file with the matrix
 * @param m - number of rows in the matrix
 * @param nnz - number of nonzeros in the matrix
 * @param lines - total number of lines with data
 * @param symmetric - true if the input matrix is to be treated as symmetrical; otherwise false
 * @param as - coefficients array (CSR data): an array of size lines containing a matrix data in the CSR format (output parameter)
 * @param irp - row start pointers array (CSR offsets): an array of size m + 1 containing the offset of i-th row in irp[i] (output parameter)
 * @param ja - column indices array (CSR column indices): an array of size lines containing the column indices (output parameter)
 */
void convert_to_csr(const char filename[], const int m, const int nnz, const int lines, bool symmetric, double *as, int *irp, int *ja) {
    int *ia = new int[nnz]();
    convert_to_coo(filename, m, lines, symmetric, as, ia, ja);
    make_irp_array(m, nnz, ia, irp);
    delete[] ia;
}

/*!
 * Prints a sparse matrix represented in the ELLPACK format
 */
void print_ellpack(const int m, const int nzr, double *as, int *ja) {
    std::cout << std::endl << "AS:";
    for (int i = 0; i < m; i++) {
        std::cout << std::endl;
        for (int j = 0; j < nzr; j++) {
            std::cout << as[i + m * j] << "\t";
        }
    }
    std::cout << std::endl << "JA:";
    for (int i = 0; i < m; i++) {
        std::cout << std::endl;
        for (int j = 0; j < nzr; j++) {
            std::cout << ja[i + m * j] << "\t";
        }
    }
}

/*!
 * Prints a sparse matrix represented in the CSR format
 */
void print_csr(const int m, const int nnz, double *as, int *irp, int *ja) {
    std::cout << std::endl << "AS:" << std::endl;
    for (int i = 0; i < nnz; i++) {
        std::cout << as[i] << "\t";
    }

    std::cout << std::endl << "IRP:" << std::endl;
    for (int i = 0; i < m + 1; i++) {
        std::cout << irp[i] << "\t";
    }

    std::cout << std::endl << "JA:" << std::endl;
    for (int i = 0; i < nnz; i++) {
        std::cout << ja[i] << "\t";
    }
}

#endif //MATRIX_CONVERTER_CUH

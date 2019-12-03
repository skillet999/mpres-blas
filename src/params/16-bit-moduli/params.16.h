/*
 *  Global parameters of MPRES-BLAS.
 *  16 moduli of the RNS system, each of 16 bits
 *  242-bit dynamic range of the RNS
 *  120 bits of precision
 *
 *  Copyright 2018, 2019 by Konstantin Isupov and Alexander Kuvaev.
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

#ifndef MPRES_PARAMS_H
#define MPRES_PARAMS_H

#define RNS_MODULI_SIZE 16

#define RNS_PARALLEL_REDUCTION_IDX 8

#define RNS_MODULI_PRODUCT_LOG2 242

#define RNS_P2_SCALING_THRESHOLD 30

#define RNS_EVAL_ACCURACY 0.0000001

#define RNS_EVAL_MIN_LIMIT 5.6843418860808015e-07

#define RNS_EVAL_OFFSET_VEC_SIZE 12

const int RNS_MODULI[] = {36051,36053,36055,36059,36061,36067,36071,36073,36077,36079,36083,36089,36091,36097,36101,36103};

#endif  //MPRES_PARAMS_H
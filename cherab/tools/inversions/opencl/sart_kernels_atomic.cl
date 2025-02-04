// Copyright 2016-2018 Euratom
// Copyright 2016-2018 United Kingdom Atomic Energy Authority
// Copyright 2016-2018 Centro de Investigaciones Energéticas, Medioambientales y Tecnológicas
//
// Licensed under the EUPL, Version 1.1 or – as soon they will be approved by the
// European Commission - subsequent versions of the EUPL (the "Licence");
// You may not use this work except in compliance with the Licence.
// You may obtain a copy of the Licence at:
//
// https://joinup.ec.europa.eu/software/page/eupl5
//
// Unless required by applicable law or agreed to in writing, software distributed
// under the Licence is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.
//
// See the Licence for the specific language governing permissions and limitations
// under the Licence.
//
// The following code is created by Vladislav Neverov (NRC "Kurchatov Institute") for Cherab Spectroscopy Modelling Framework

#ifndef BLOCK_SIZE
#define BLOCK_SIZE 256
#endif
#ifndef BLOCK_SIZE_ROW_MAJ
#define BLOCK_SIZE_ROW_MAJ 64
#endif
#ifndef STEPS_PER_THREAD
#define STEPS_PER_THREAD BLOCK_SIZE
#endif
#ifndef STEPS_PER_THREAD_ROW_MAJ
#define STEPS_PER_THREAD_ROW_MAJ BLOCK_SIZE_ROW_MAJ
#endif
#define ZERO_CUT 0.0000001f


inline void atomicAdd_g_f(volatile __global float *addr, float val) {
    // see https://streamhpc.com/blog/2016-02-09/atomic-operations-for-floats-in-opencl-improved/
    union {
        unsigned int u32;
        float        f32;
    } next, expected, current;
   	current.f32    = *addr;
    do {
   	    expected.f32 = current.f32;
            next.f32 = expected.f32 + val;
   		 current.u32 = atomic_cmpxchg( (volatile __global unsigned int *)addr, expected.u32, next.u32);
    } while( current.u32 != expected.u32 );
}


__kernel void zero_all(__global float * const a, const unsigned int n){
	const unsigned int i = BLOCK_SIZE * get_group_id(0) + get_local_id(0);
	if (i<n) a[i] = 0;
}


__kernel void zero_negative(__global float * const a, const unsigned int n){
	const unsigned int i = BLOCK_SIZE * get_group_id(0) + get_local_id(0);
	if (i<n) {
        if (a[i] < 0) a[i] = 0;
    }
}


__kernel void vec_scalar_mult(__global float * const a, const float b, const unsigned int n){
	const unsigned int i = BLOCK_SIZE * get_group_id(0) + get_local_id(0);
	if (i<n) a[i] *= b;
}


__kernel void mat_vec_mult_col_major(__global float * const restrict a, __global float * const restrict b, \
                                     __global float * const restrict result, const unsigned int nrows, const unsigned int ncols){
	//fast multiplication with coalesced memory reads
    const unsigned int tid = get_local_id(0);
    const unsigned int irow = get_group_id(0) * BLOCK_SIZE + tid;
    const unsigned int icol_first = get_group_id(1) * STEPS_PER_THREAD;
    __local float b_cache[STEPS_PER_THREAD];
    float res_loc = 0;
    unsigned int icol_block_max = ncols - icol_first;
    if (icol_block_max > STEPS_PER_THREAD) icol_block_max = STEPS_PER_THREAD;
    if (tid < icol_block_max) b_cache[tid] = b[icol_first + tid];
    barrier(CLK_LOCAL_MEM_FENCE);
    if (irow < nrows) {
        if (!(icol_block_max % 4)) { // unroll 4 if possible
            for (unsigned int icol_block = 0; icol_block < icol_block_max; icol_block += 4) {
                const unsigned int icol = icol_first + icol_block;
                res_loc += a[ icol      * nrows + irow] * b_cache[icol_block    ] + \
                           a[(icol + 1) * nrows + irow] * b_cache[icol_block + 1] + \
                           a[(icol + 2) * nrows + irow] * b_cache[icol_block + 2] + \
                           a[(icol + 3) * nrows + irow] * b_cache[icol_block + 3];
            }
        }
        else {
            for (unsigned int icol_block = 0; icol_block < icol_block_max; icol_block += 1) {
                res_loc += a[(icol_first + icol_block) * nrows + irow] * b_cache[icol_block];
            }
        }
        atomicAdd_g_f(&result[irow], res_loc);
    }
}


__kernel void mat_vec_mult_row_major(__global float * const restrict a, __global float * const restrict b, \
                                     __global float * const restrict result, const unsigned int nrows, const unsigned int ncols){
	//slow multiplication without coalesced memory reads
    const unsigned int tid = get_local_id(0);
    const unsigned int irow = get_group_id(0) * BLOCK_SIZE_ROW_MAJ + tid;
    const unsigned int icol_first = get_group_id(1) * STEPS_PER_THREAD_ROW_MAJ;
    __local float b_cache[STEPS_PER_THREAD_ROW_MAJ];
    float res_loc = 0;
    unsigned int icol_block_max = ncols - icol_first;
    if (icol_block_max > STEPS_PER_THREAD_ROW_MAJ) icol_block_max = STEPS_PER_THREAD_ROW_MAJ;
    barrier(CLK_LOCAL_MEM_FENCE);
    if (tid < icol_block_max) b_cache[tid] = b[icol_first + tid];
    barrier(CLK_LOCAL_MEM_FENCE);
    if (irow < nrows) {
        const unsigned int iflat_base = irow * ncols + icol_first;
        if (!(icol_block_max % 8)) { // unroll 8 if possible
            for (unsigned int i = 0; i < icol_block_max; i += 8) {
                const unsigned int icol = iflat_base + i;
                res_loc += a[icol]     * b_cache[i]     + a[icol + 1] * b_cache[i + 1] + a[icol + 2] * b_cache[i + 2] + \
                           a[icol + 3] * b_cache[i + 3] + a[icol + 4] * b_cache[i + 4] + a[icol + 5] * b_cache[i + 5] + \
                           a[icol + 6] * b_cache[i + 6] + a[icol + 7] * b_cache[i + 7];
            }
        }
        else {
            for (unsigned int i = 0; i < icol_block_max; i += 1) {
                res_loc += a[iflat_base + i] * b_cache[i];
            }
        }
        atomicAdd_g_f(&result[irow], res_loc);
    }
}


__kernel void sart_iteration(__global float * const restrict geometry_matrix, __global float * const restrict cell_ray_densities, \
                             __global float * const restrict ray_lengths, __global float * const restrict y_hat, \
                             __global float * const restrict detectors, __global float * const restrict solution, \
                             __global float * const restrict grad_penalty, const float relaxation, \
                             const unsigned int n_sources, const unsigned int m_detectors){
    const unsigned int tid = get_local_id(0);
    const unsigned int isource = get_group_id(0) * BLOCK_SIZE + tid;
    const unsigned int idet_first = get_group_id(1) * STEPS_PER_THREAD;
    const float cell_ray_density = (isource < n_sources) ? cell_ray_densities[isource] : 0;
    __local float inv_ray_lengths[STEPS_PER_THREAD];
    __local float diff_det[STEPS_PER_THREAD];
    float obs_diff = 0;
    unsigned int idet_block_max = m_detectors - idet_first;
    if (idet_block_max > STEPS_PER_THREAD) idet_block_max = STEPS_PER_THREAD;
    barrier(CLK_LOCAL_MEM_FENCE);
    if (tid < idet_block_max) {
        const unsigned int idet = idet_first + tid;
        inv_ray_lengths[tid] = ray_lengths[idet];
        if (inv_ray_lengths[tid] > ZERO_CUT) inv_ray_lengths[tid] = 1.f / inv_ray_lengths[tid]; // inverting ray lengths if possible
        diff_det[tid] = detectors[idet] - y_hat[idet];
    }
    barrier(CLK_LOCAL_MEM_FENCE);
    if (cell_ray_density > ZERO_CUT) {
       if (!(idet_block_max % 4)) { // unroll 4 if possible
            for (unsigned int idet_block = 0; idet_block < idet_block_max; idet_block += 4){
                const unsigned int idet_base = idet_first + idet_block;
                obs_diff += geometry_matrix[idet_base       * n_sources + isource] * inv_ray_lengths[idet_block]     * diff_det[idet_block] + \
                            geometry_matrix[(idet_base + 1) * n_sources + isource] * inv_ray_lengths[idet_block + 1] * diff_det[idet_block + 1] + \
                            geometry_matrix[(idet_base + 2) * n_sources + isource] * inv_ray_lengths[idet_block + 2] * diff_det[idet_block + 2] + \
                            geometry_matrix[(idet_base + 3) * n_sources + isource] * inv_ray_lengths[idet_block + 3] * diff_det[idet_block + 3];
            }
        }
        else {
            for (unsigned int idet_block = 0; idet_block < idet_block_max; idet_block += 1){
                obs_diff += geometry_matrix[(idet_first + idet_block) * n_sources + isource] * inv_ray_lengths[idet_block] * diff_det[idet_block];
            }
        }
        const float solution_add = (obs_diff * relaxation) / (cell_ray_density + ZERO_CUT);
        if (!get_group_id(1)) atomicAdd_g_f(&solution[isource], solution_add - grad_penalty[isource]);
        else atomicAdd_g_f(&solution[isource], solution_add);
        
    }
	else if ((isource < n_sources) && (!get_group_id(1))) atomicAdd_g_f(&solution[isource], -grad_penalty[isource]);
}


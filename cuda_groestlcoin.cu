// Auf Groestlcoin spezialisierte Version von Groestl

#include <cuda.h>
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include <memory.h>

#define USE_SHARED 1

// aus cpu-miner.c
extern int device_map[8];

// aus heavy.cu
extern cudaError_t MyStreamSynchronize(cudaStream_t stream, int situation, int thr_id);

// Folgende Definitionen sp�ter durch header ersetzen
typedef unsigned char uint8_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;

// globaler Speicher f�r alle HeftyHashes aller Threads
__constant__ uint32_t groestlcoin_pTarget[8]; // Single GPU
extern uint32_t *d_resultNonce[8];

__constant__ uint32_t groestlcoin_gpu_msg[32];

#define SPH_T32(x)    ((x) & SPH_C32(0xFFFFFFFF))

#define PC32up(j, r)   ((uint32_t)((j) + (r)))
#define PC32dn(j, r)   0
#define QC32up(j, r)   0xFFFFFFFF
#define QC32dn(j, r)   (((uint32_t)(r) << 24) ^ SPH_T32(~((uint32_t)(j) << 24)))

#define B32_0(x)    ((x) & 0xFF)
#define B32_1(x)    (((x) >> 8) & 0xFF)
#define B32_2(x)    (((x) >> 16) & 0xFF)
#define B32_3(x)    ((x) >> 24)

#define SPH_C32(x)	((uint32_t)(x ## U))
#define C32e(x)     ((SPH_C32(x) >> 24) \
                    | ((SPH_C32(x) >>  8) & SPH_C32(0x0000FF00)) \
                    | ((SPH_C32(x) <<  8) & SPH_C32(0x00FF0000)) \
                    | ((SPH_C32(x) << 24) & SPH_C32(0xFF000000)))

#if USE_SHARED
#define T0up(x) (*((uint32_t*)mixtabs + (    (x))))
#define T0dn(x) (*((uint32_t*)mixtabs + (256+(x))))
#define T1up(x) (*((uint32_t*)mixtabs + (512+(x))))
#define T1dn(x) (*((uint32_t*)mixtabs + (768+(x))))
#define T2up(x) (*((uint32_t*)mixtabs + (1024+(x))))
#define T2dn(x) (*((uint32_t*)mixtabs + (1280+(x))))
#define T3up(x) (*((uint32_t*)mixtabs + (1536+(x))))
#define T3dn(x) (*((uint32_t*)mixtabs + (1792+(x))))
#else
#define T0up(x) tex1Dfetch(t0up1, x)
#define T0dn(x) tex1Dfetch(t0dn1, x)
#define T1up(x) tex1Dfetch(t1up1, x)
#define T1dn(x) tex1Dfetch(t1dn1, x)
#define T2up(x) tex1Dfetch(t2up1, x)
#define T2dn(x) tex1Dfetch(t2dn1, x)
#define T3up(x) tex1Dfetch(t3up1, x)
#define T3dn(x) tex1Dfetch(t3dn1, x)
#endif
texture<unsigned int, 1, cudaReadModeElementType> t0up1;
texture<unsigned int, 1, cudaReadModeElementType> t0dn1;
texture<unsigned int, 1, cudaReadModeElementType> t1up1;
texture<unsigned int, 1, cudaReadModeElementType> t1dn1;
texture<unsigned int, 1, cudaReadModeElementType> t2up1;
texture<unsigned int, 1, cudaReadModeElementType> t2dn1;
texture<unsigned int, 1, cudaReadModeElementType> t3up1;
texture<unsigned int, 1, cudaReadModeElementType> t3dn1;

extern uint32_t T0up_cpu[];
extern uint32_t T0dn_cpu[];
extern uint32_t T1up_cpu[];
extern uint32_t T1dn_cpu[];
extern uint32_t T2up_cpu[];
extern uint32_t T2dn_cpu[];
extern uint32_t T3up_cpu[];
extern uint32_t T3dn_cpu[];

#if __CUDA_ARCH__ < 350 
    // Kepler (Compute 3.0)
    #define S(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
#else
    // Kepler (Compute 3.5)
    #define S(x, n) __funnelshift_r( x, x, n );
#endif
#define R(x, n)			((x) >> (n))
#define Ch(x, y, z)		((x & (y ^ z)) ^ z)
#define Maj(x, y, z)	((x & (y | z)) | (y & z))
#define S0(x)			(S(x, 2) ^ S(x, 13) ^ S(x, 22))
#define S1(x)			(S(x, 6) ^ S(x, 11) ^ S(x, 25))
#define s0(x)			(S(x, 7) ^ S(x, 18) ^ R(x, 3))
#define s1(x)			(S(x, 17) ^ S(x, 19) ^ R(x, 10))

#define SWAB32(x)		( ((x & 0x000000FF) << 24) | ((x & 0x0000FF00) << 8) | ((x & 0x00FF0000) >> 8) | ((x & 0xFF000000) >> 24) )


__device__ __forceinline__ void groestlcoin_perm_P(uint32_t *a, char *mixtabs)
{
	uint32_t t[32];

//#pragma unroll 14
	for(int r=0;r<14;r++)
	{
		switch(r)
		{
			case 0:
#pragma unroll 16
				for(int k=0;k<16;k++) a[(k*2)+0] ^= PC32up(k * 0x10, 0); break;
			case 1:
#pragma unroll 16
				for(int k=0;k<16;k++) a[(k*2)+0] ^= PC32up(k * 0x10, 1); break;
			case 2:
#pragma unroll 16
				for(int k=0;k<16;k++) a[(k*2)+0] ^= PC32up(k * 0x10, 2); break;
			case 3:
#pragma unroll 16
				for(int k=0;k<16;k++) a[(k*2)+0] ^= PC32up(k * 0x10, 3); break;
			case 4:
#pragma unroll 16
				for(int k=0;k<16;k++) a[(k*2)+0] ^= PC32up(k * 0x10, 4); break;
			case 5:
#pragma unroll 16
				for(int k=0;k<16;k++) a[(k*2)+0] ^= PC32up(k * 0x10, 5); break;
			case 6:
#pragma unroll 16
				for(int k=0;k<16;k++) a[(k*2)+0] ^= PC32up(k * 0x10, 6); break;
			case 7:
#pragma unroll 16
				for(int k=0;k<16;k++) a[(k*2)+0] ^= PC32up(k * 0x10, 7); break;
			case 8:
#pragma unroll 16
				for(int k=0;k<16;k++) a[(k*2)+0] ^= PC32up(k * 0x10, 8); break;
			case 9:
#pragma unroll 16
				for(int k=0;k<16;k++) a[(k*2)+0] ^= PC32up(k * 0x10, 9); break;
			case 10:
#pragma unroll 16
				for(int k=0;k<16;k++) a[(k*2)+0] ^= PC32up(k * 0x10, 10); break;
			case 11:
#pragma unroll 16
				for(int k=0;k<16;k++) a[(k*2)+0] ^= PC32up(k * 0x10, 11); break;
			case 12:
#pragma unroll 16
				for(int k=0;k<16;k++) a[(k*2)+0] ^= PC32up(k * 0x10, 12); break;
			case 13:
#pragma unroll 16
				for(int k=0;k<16;k++) a[(k*2)+0] ^= PC32up(k * 0x10, 13); break;
		}

		// RBTT
#pragma unroll 16
		for(int k=0;k<32;k+=2)
		{
			t[k + 0] =	T0up( B32_0(a[k & 0x1f]) ) ^ 
						T1up( B32_1(a[(k + 2) & 0x1f]) ) ^ 
						T2up( B32_2(a[(k + 4) & 0x1f]) ) ^ 
						T3up( B32_3(a[(k + 6) & 0x1f]) ) ^ 
						T0dn( B32_0(a[(k + 9) & 0x1f]) ) ^ 
						T1dn( B32_1(a[(k + 11) & 0x1f]) ) ^ 
						T2dn( B32_2(a[(k + 13) & 0x1f]) ) ^ 
						T3dn( B32_3(a[(k + 23) & 0x1f]) );

			t[k + 1] =	T0dn( B32_0(a[k & 0x1f]) ) ^ 
						T1dn( B32_1(a[(k + 2) & 0x1f]) ) ^ 
						T2dn( B32_2(a[(k + 4) & 0x1f]) ) ^ 
						T3dn( B32_3(a[(k + 6) & 0x1f]) ) ^ 
						T0up( B32_0(a[(k + 9) & 0x1f]) ) ^ 
						T1up( B32_1(a[(k + 11) & 0x1f]) ) ^ 
						T2up( B32_2(a[(k + 13) & 0x1f]) ) ^ 
						T3up( B32_3(a[(k + 23) & 0x1f]) );
		}
#pragma unroll 32
		for(int k=0;k<32;k++)
			a[k] = t[k];
	}
}

__device__ __forceinline__ void groestlcoin_perm_Q(uint32_t *a, char *mixtabs)
{	
//#pragma unroll 14
	for(int r=0;r<14;r++)
	{
		uint32_t t[32];

		switch(r)
		{
			case 0:
	#pragma unroll 16
				for(int k=0;k<16;k++) { a[(k*2)+0] ^= QC32up(k * 0x10, 0); a[(k*2)+1] ^= QC32dn(k * 0x10, 0);} break;
			case 1:
	#pragma unroll 16
				for(int k=0;k<16;k++) { a[(k*2)+0] ^= QC32up(k * 0x10, 1); a[(k*2)+1] ^= QC32dn(k * 0x10, 1);} break;
			case 2:
	#pragma unroll 16
				for(int k=0;k<16;k++) { a[(k*2)+0] ^= QC32up(k * 0x10, 2); a[(k*2)+1] ^= QC32dn(k * 0x10, 2);} break;
			case 3:
	#pragma unroll 16
				for(int k=0;k<16;k++) { a[(k*2)+0] ^= QC32up(k * 0x10, 3); a[(k*2)+1] ^= QC32dn(k * 0x10, 3);} break;
			case 4:
	#pragma unroll 16
				for(int k=0;k<16;k++) { a[(k*2)+0] ^= QC32up(k * 0x10, 4); a[(k*2)+1] ^= QC32dn(k * 0x10, 4);} break;
			case 5:
	#pragma unroll 16
				for(int k=0;k<16;k++) { a[(k*2)+0] ^= QC32up(k * 0x10, 5); a[(k*2)+1] ^= QC32dn(k * 0x10, 5);} break;
			case 6:
	#pragma unroll 16
				for(int k=0;k<16;k++) { a[(k*2)+0] ^= QC32up(k * 0x10, 6); a[(k*2)+1] ^= QC32dn(k * 0x10, 6);} break;
			case 7:
	#pragma unroll 16
				for(int k=0;k<16;k++) { a[(k*2)+0] ^= QC32up(k * 0x10, 7); a[(k*2)+1] ^= QC32dn(k * 0x10, 7);} break;
			case 8:
	#pragma unroll 16
				for(int k=0;k<16;k++) { a[(k*2)+0] ^= QC32up(k * 0x10, 8); a[(k*2)+1] ^= QC32dn(k * 0x10, 8);} break;
			case 9:
	#pragma unroll 16
				for(int k=0;k<16;k++) { a[(k*2)+0] ^= QC32up(k * 0x10, 9); a[(k*2)+1] ^= QC32dn(k * 0x10, 9);} break;
			case 10:
	#pragma unroll 16
				for(int k=0;k<16;k++) { a[(k*2)+0] ^= QC32up(k * 0x10, 10); a[(k*2)+1] ^= QC32dn(k * 0x10, 10);} break;
			case 11:
	#pragma unroll 16
				for(int k=0;k<16;k++) { a[(k*2)+0] ^= QC32up(k * 0x10, 11); a[(k*2)+1] ^= QC32dn(k * 0x10, 11);} break;
			case 12:
	#pragma unroll 16
				for(int k=0;k<16;k++) { a[(k*2)+0] ^= QC32up(k * 0x10, 12); a[(k*2)+1] ^= QC32dn(k * 0x10, 12);} break;
			case 13:
	#pragma unroll 16
				for(int k=0;k<16;k++) { a[(k*2)+0] ^= QC32up(k * 0x10, 13); a[(k*2)+1] ^= QC32dn(k * 0x10, 13);} break;
		}

		// RBTT
#pragma unroll 16
		for(int k=0;k<32;k+=2)
		{
			t[k + 0] =	T0up( B32_0(a[(k + 2) & 0x1f]) ) ^ 
						T1up( B32_1(a[(k + 6) & 0x1f]) ) ^ 
						T2up( B32_2(a[(k + 10) & 0x1f]) ) ^ 
						T3up( B32_3(a[(k + 22) & 0x1f]) ) ^ 
						T0dn( B32_0(a[(k + 1) & 0x1f]) ) ^ 
						T1dn( B32_1(a[(k + 5) & 0x1f]) ) ^ 
						T2dn( B32_2(a[(k + 9) & 0x1f]) ) ^ 
						T3dn( B32_3(a[(k + 13) & 0x1f]) );

			t[k + 1] =	T0dn( B32_0(a[(k + 2) & 0x1f]) ) ^ 
						T1dn( B32_1(a[(k + 6) & 0x1f]) ) ^ 
						T2dn( B32_2(a[(k + 10) & 0x1f]) ) ^ 
						T3dn( B32_3(a[(k + 22) & 0x1f]) ) ^ 
						T0up( B32_0(a[(k + 1) & 0x1f]) ) ^ 
						T1up( B32_1(a[(k + 5) & 0x1f]) ) ^ 
						T2up( B32_2(a[(k + 9) & 0x1f]) ) ^ 
						T3up( B32_3(a[(k + 13) & 0x1f]) );
		}
#pragma unroll 32
		for(int k=0;k<32;k++)
			a[k] = t[k];
	}
}
#if USE_SHARED
__global__ void  /* __launch_bounds__(256) */
#else
__global__ void 
#endif

 groestlcoin_gpu_hash(int threads, uint32_t startNounce, uint32_t *resNounce)
{
#if USE_SHARED
	extern __shared__ char mixtabs[];

	*((uint32_t*)mixtabs + (    threadIdx.x)) = tex1Dfetch(t0up1, threadIdx.x);
	*((uint32_t*)mixtabs + (256+threadIdx.x)) = tex1Dfetch(t0dn1, threadIdx.x);
	*((uint32_t*)mixtabs + (512+threadIdx.x)) = tex1Dfetch(t1up1, threadIdx.x);
	*((uint32_t*)mixtabs + (768+threadIdx.x)) = tex1Dfetch(t1dn1, threadIdx.x);
	*((uint32_t*)mixtabs + (1024+threadIdx.x)) = tex1Dfetch(t2up1, threadIdx.x);
	*((uint32_t*)mixtabs + (1280+threadIdx.x)) = tex1Dfetch(t2dn1, threadIdx.x);
	*((uint32_t*)mixtabs + (1536+threadIdx.x)) = tex1Dfetch(t3up1, threadIdx.x);
	*((uint32_t*)mixtabs + (1792+threadIdx.x)) = tex1Dfetch(t3dn1, threadIdx.x);

	__syncthreads();
#endif

	int thread = (blockDim.x * blockIdx.x + threadIdx.x);
	if (thread < threads)
	{
		// GROESTL
		uint32_t message[32];
		uint32_t state[32];

#pragma unroll 32
		for(int k=0;k<32;k++) message[k] = groestlcoin_gpu_msg[k];

		uint32_t nounce = startNounce + thread;
		message[19] = SWAB32(nounce);

#pragma unroll 32
		for(int u=0;u<32;u++) state[u] = message[u];
		state[31] ^= 0x20000;

		// Perm
#if USE_SHARED
		groestlcoin_perm_P(state, mixtabs);
		state[31] ^= 0x20000;
		groestlcoin_perm_Q(message, mixtabs);
#else
		groestlcoin_perm_P(state, NULL);
		state[31] ^= 0x20000;
		groestlcoin_perm_Q(message, NULL);
#endif
#pragma unroll 32
		for(int u=0;u<32;u++) state[u] ^= message[u];

#pragma unroll 32
		for(int u=0;u<32;u++) message[u] = state[u];

#if USE_SHARED
		groestlcoin_perm_P(message, mixtabs);
#else
		groestlcoin_perm_P(message, NULL);
#endif

#pragma unroll 32
		for(int u=0;u<32;u++) state[u] ^= message[u];

		////
		//// 2. Runde groestl
		////
#pragma unroll 16
		for(int k=0;k<16;k++) message[k] = state[k + 16];
#pragma unroll 14
		for(int k=1;k<15;k++)
			message[k+16] = 0;

		message[16] = 0x80;
		message[31] = 0x01000000;

#pragma unroll 32
		for(int u=0;u<32;u++)
			state[u] = message[u];
		state[31] ^= 0x20000;

		// Perm
#if USE_SHARED
		groestlcoin_perm_P(state, mixtabs);
		state[31] ^= 0x20000;
		groestlcoin_perm_Q(message, mixtabs);
#else
		groestlcoin_perm_P(state, NULL);
		state[31] ^= 0x20000;
		groestlcoin_perm_Q(message, NULL);
#endif
		
#pragma unroll 32
		for(int u=0;u<32;u++) state[u] ^= message[u];

#pragma unroll 32
		for(int u=0;u<32;u++) message[u] = state[u];

#if USE_SHARED
		groestlcoin_perm_P(message, mixtabs);
#else
		groestlcoin_perm_P(message, NULL);
#endif

#pragma unroll 32
		for(int u=0;u<32;u++) state[u] ^= message[u];

		// kopiere Ergebnis
		int i, position = -1;
		bool rc = true;

#pragma unroll 8
		for (i = 7; i >= 0; i--) {
			if (state[i+16] > groestlcoin_pTarget[i]) {
				if(position < i) {
					position = i;
					rc = false;
				}
	 		}
	 		if (state[i+16] < groestlcoin_pTarget[i]) {
				if(position < i) {
					position = i;
					rc = true;
				}
	 		}
		}

		if(rc == true)
			if(resNounce[0] > nounce)
				resNounce[0] = nounce;
	}
}

#define texDef(texname, texmem, texsource, texsize) \
	unsigned int *texmem; \
	cudaMalloc(&texmem, texsize); \
	cudaMemcpy(texmem, texsource, texsize, cudaMemcpyHostToDevice); \
	texname.normalized = 0; \
	texname.filterMode = cudaFilterModePoint; \
	texname.addressMode[0] = cudaAddressModeClamp; \
	{ cudaChannelFormatDesc channelDesc = cudaCreateChannelDesc<unsigned int>(); \
	  cudaBindTexture(NULL, &texname, texmem, &channelDesc, texsize ); } \

// Setup-Funktionen
__host__ void groestlcoin_cpu_init(int thr_id, int threads)
{
    cudaSetDevice(device_map[thr_id]);
	cudaDeviceSetCacheConfig( cudaFuncCachePreferShared );
// Texturen mit obigem Makro initialisieren
	texDef(t0up1, d_T0up, T0up_cpu, sizeof(uint32_t)*256);
	texDef(t0dn1, d_T0dn, T0dn_cpu, sizeof(uint32_t)*256);
	texDef(t1up1, d_T1up, T1up_cpu, sizeof(uint32_t)*256);
	texDef(t1dn1, d_T1dn, T1dn_cpu, sizeof(uint32_t)*256);
	texDef(t2up1, d_T2up, T2up_cpu, sizeof(uint32_t)*256);
	texDef(t2dn1, d_T2dn, T2dn_cpu, sizeof(uint32_t)*256);
	texDef(t3up1, d_T3up, T3up_cpu, sizeof(uint32_t)*256);
	texDef(t3dn1, d_T3dn, T3dn_cpu, sizeof(uint32_t)*256);

	// Speicher f�r Gewinner-Nonce belegen
	cudaMalloc(&d_resultNonce[thr_id], sizeof(uint32_t)); 
}

__host__ void groestlcoin_cpu_setBlock(int thr_id, void *data, void *pTargetIn)
{
	// Nachricht expandieren und setzen
	uint32_t msgBlock[32];

	memset(msgBlock, 0, sizeof(uint32_t) * 32);
	memcpy(&msgBlock[0], data, 80);

	// Erweitere die Nachricht auf den Nachrichtenblock (padding)
	// Unsere Nachricht hat 80 Byte
	msgBlock[20] = 0x80;
	msgBlock[31] = 0x01000000;

	// groestl512 braucht hierf�r keinen CPU-Code (die einzige Runde wird
	// auf der GPU ausgef�hrt)

	// Blockheader setzen (korrekte Nonce und Hefty Hash fehlen da drin noch)
	cudaMemcpyToSymbol(	groestlcoin_gpu_msg,
						msgBlock,
						128);

	cudaMemset(d_resultNonce[thr_id], 0xFF, sizeof(uint32_t));
	cudaMemcpyToSymbol(	groestlcoin_pTarget,
						pTargetIn,
						sizeof(uint32_t) * 8 );
}

__host__ void groestlcoin_cpu_hash(int thr_id, int threads, uint32_t startNounce, void *outputHashes, uint32_t *nounce)
{
#if USE_SHARED
	const int threadsperblock = 256; // Alignment mit mixtab Gr�sse. NICHT �NDERN
#else
	const int threadsperblock = 512; // so einstellen wie gew�nscht ;-)
#endif

	// berechne wie viele Thread Blocks wir brauchen
	dim3 grid((threads + threadsperblock-1)/threadsperblock);
	dim3 block(threadsperblock);

	// Gr��e des dynamischen Shared Memory Bereichs
#if USE_SHARED
	size_t shared_size = 8 * 256 * sizeof(uint32_t);
#else
	size_t shared_size = 0;
#endif

//	fprintf(stderr, "threads=%d, %d blocks, %d threads per block, %d bytes shared\n", threads, grid.x, block.x, shared_size);
	//fprintf(stderr, "ThrID: %d\n", thr_id);
	cudaMemset(d_resultNonce[thr_id], 0xFF, sizeof(uint32_t));
	groestlcoin_gpu_hash<<<grid, block, shared_size>>>(threads, startNounce, d_resultNonce[thr_id]);

	// Strategisches Sleep Kommando zur Senkung der CPU Last
	MyStreamSynchronize(NULL, 0, thr_id);

	cudaMemcpy(nounce, d_resultNonce[thr_id], sizeof(uint32_t), cudaMemcpyDeviceToHost);
}

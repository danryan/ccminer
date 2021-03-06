
if WANT_JANSSON
JANSSON_INCLUDES= -I$(top_srcdir)/compat/jansson
else
JANSSON_INCLUDES=
endif

# GENCODE_OPTS=-gencode arch=compute_50,code=sm_50
GENCODE_OPTS=-gencode=arch=compute_20,code=\"sm_20,compute_20\" -gencode=arch=compute_30,code=\"sm_30,compute_30\" -gencode=arch=compute_35,code=\"sm_35,compute_35\"
NVCC_OPTS=-dc -Xptxas -v --ptxas-options=-v
NVLINK_OPTS=-dlink -Xnvlink -v -Xlinker -v
CUDA_OBJ=ccminer-link.o

EXTRA_DIST		= autogen.sh README.txt LICENSE.txt \
			  cudaminer.sln cudaminer.vcxproj cudaminer.vcxproj.filters \
			  compat/gettimeofday.c compat/getopt/getopt_long.c cpuminer-config.h.in

SUBDIRS		= compat

bin_PROGRAMS	= ccminer

ccminer_SOURCES		= elist.h miner.h compat.h \
			  compat/inttypes.h compat/stdbool.h compat/unistd.h \
			  compat/sys/time.h compat/getopt/getopt.h \
			  cpu-miner.c util.c blake.c groestl.c hefty1.c keccak.c scrypt.c sha2.c \
			  sph_blake.h sph_groestl.h sph_keccak.h sph_types.h \
			  heavy.cu \
			  cuda_blake512.cu cuda_blake512.h \
			  cuda_combine.cu cuda_combine.h \
			  cuda_groestl512.cu cuda_groestl512.h \
			  cuda_hefty1.cu cuda_hefty1.h \
			  cuda_keccak512.cu cuda_keccak512.h \
			  cuda_sha256.cu cuda_sha256.h \
			  fuguecoin.cpp cuda_fugue256.cu fugue.c sph_fugue.h uint256.h \
			  groestlcoin.cpp cuda_groestlcoin.cu cuda_groestlcoin.h

ccminer_LDFLAGS		= $(PTHREAD_FLAGS) @CUDA_LDFLAGS@
ccminer_LDADD		= @LIBCURL@ @JANSSON_LIBS@ @PTHREAD_LIBS@ @WS2_LIBS@ @CUDA_LIBS@ @OPENMP_CFLAGS@ @LIBS@  -ldl
ccminer_CPPFLAGS	= -msse2 @LIBCURL_CPPFLAGS@ @OPENMP_CFLAGS@ $(PTHREAD_FLAGS) -fno-strict-aliasing $(JANSSON_INCLUDES) -DSCRYPT_KECCAK512 -DSCRYPT_CHACHA -DSCRYPT_CHOOSE_COMPILETIME

NVLINK_CMD=$(NVCC) $(NVLINK_OPTS) $(GENCODE_OPTS) *.o -o $(CUDA_OBJ)
CXXLINK_CMD=$(CXXLD) $(AM_CXXFLAGS) $(CXXFLAGS) $(ccminer_LDFLAGS) $(LDFLAGS) -o $@ $(CUDA_OBJ)

ccminer_LINK = $(NVLINK_CMD) && $(CXXLINK_CMD)

# we're now targeting all major compute architectures within one binary.
# $(NVCC) @CFLAGS@ -Xptxas "-abi=no -v" -gencode=arch=compute_20,code=\"sm_20,compute_20\" -gencode=arch=compute_30,code=\"sm_30,compute_30\" -gencode=arch=compute_35,code=\"sm_35,compute_35\" --maxrregcount=80 --ptxas-options=-v $(JANSSON_INCLUDES) -o $@ -c $<

# nvlink: .cu.o
# 	$(NVCC) $(NVCC_LINK_OPTS) $(GENCODE_OPTS) *.o -o ccminer-link.o

.cu.o:
	$(NVCC) @CFLAGS@ $(NVCC_OPTS) $(GENCODE_OPTS) $(JANSSON_INCLUDES) -o $@ -c $<

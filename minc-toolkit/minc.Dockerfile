FROM ubuntu:focal

ARG MINC_TOOLKIT_VERSION
ENV MINC_TOOLKIT_VERSION=${MINC_TOOLKIT_VERSION:-1.9.18}
ARG PARALLEL=8
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies.
RUN apt-get -y update && \
    apt-get -y dist-upgrade && \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        bc \
        bison flex \
        build-essential \
        ca-certificates \
        ccache \
        curl \
        g++ \
        gfortran \
        git \
        gnupg \
        libgl1-mesa-dev \
        libglu1-mesa-dev \
        libjpeg-dev \
        libssl-dev \
        libx11-dev \
        libxi6 \
        libxi-dev \
        libxmu6 \
        libxmu-dev \
        libxmu-headers \
        libxrandr-dev \
        libxrandr2 \
        libxxf86vm-dev \
        libxxf86vm1 \
        lsb-release \
        software-properties-common \
        sudo \
        unzip \
        wget \
        x11proto-core-dev && \
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null && \
    apt-add-repository 'deb https://apt.kitware.com/ubuntu/ focal main' -y && \
    apt -y update && \
    apt-get install -y --no-install-recommends cmake && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/*

ENV PATH=/usr/lib/ccache:$PATH
ENV CCACHE_DIR=/ccache

# Package output directory.
WORKDIR /root
RUN mkdir /root/packages

### Build MINC-Toolkit TestSuite ###
RUN git clone --recursive --branch master https://github.com/BIC-MNI/minc-toolkit-testsuite.git minc-toolkit-testsuite
RUN mkdir -p build/minc-toolkit-testsuite
WORKDIR /root/build/minc-toolkit-testsuite
RUN cmake ../../minc-toolkit-testsuite -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/opt/minc && \
    make -j${PARALLEL} && \
    cpack -G DEB && \
    cp *.deb /root/packages/

### Build BEaST Library ###
WORKDIR /root
RUN git clone --recursive --branch master https://github.com/BIC-MNI/BEaST_library.git BEaST_library
RUN mkdir -p build/BEaST_library
WORKDIR /root/build/BEaST_library
RUN cmake ../../BEaST_library -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/opt/minc && \
    make -j${PARALLEL} && \
    cpack -G DEB && \
    cp *.deb /root/packages/

### Build BIC MNI Models ###
WORKDIR /root
RUN git clone --recursive --branch master https://github.com/BIC-MNI/bic-mni-models.git bic-mni-models
RUN mkdir -p build/bic-mni-models
WORKDIR /root/build/bic-mni-models
RUN cmake ../../bic-mni-models -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/opt/minc && \
    make -j${PARALLEL} && \
    cpack -G DEB && \
    cp *.deb ~/build/

### Build MINC-Toolkit ###
WORKDIR /root
RUN git clone --recursive --branch release-${MINC_TOOLKIT_VERSION} https://github.com/BIC-MNI/minc-toolkit-v2.git minc-toolkit-v2
RUN mkdir -p build/minc-toolkit-v2 /opt/minc
WORKDIR /root/build/minc-toolkit-v2
RUN cmake ../../minc-toolkit-v2 \
        -DCMAKE_BUILD_TYPE:STRING=Release \
        -DCMAKE_CXX_FLAGS_RELEASE:STRING="-O3 -DNDEBUG -mtune=generic -fcommon" \
        -DCMAKE_C_FLAGS_RELEASE:STRING="-O3 -DNDEBUG -mtune=generic -fcommon" \
        -DCMAKE_Fortran_FLAGS_RELEASE:STRING="-O3 -DNDEBUG -mtune=generic -fcommon" \
        -DCMAKE_INSTALL_PREFIX:PATH=/opt/minc/\${MINC_TOOLKIT_VERSION} \
        -DMT_BUILD_ABC:BOOL=ON \
        -DMT_BUILD_ANTS:BOOL=ON \
        -DMT_BUILD_C3D:BOOL=OFF \
        -DMT_BUILD_ELASTIX:BOOL=ON \
        -DMT_BUILD_IM:BOOL=OFF \
        -DMT_BUILD_ITK_TOOLS:BOOL=ON \
        -DMT_BUILD_LITE:BOOL=OFF \
        -DMT_BUILD_SHARED_LIBS:BOOL=ON \
        -DMT_BUILD_VISUAL_TOOLS:BOOL=ON \
        -DMT_USE_OPENMP:BOOL=ON \
        -DMT_BUILD_OPENBLAS:BOOL=ON \
        -DMT_BUILD_SHARED_LIBS:BOOL=ON \
        -DBUILD_TESTING:BOOL=ON \
        -DMT_BUILD_LITE:BOOL=OFF \
        -DUSE_SYSTEM_GLUT:BOOL=OFF \
        -DUSE_SYSTEM_FFTW3D:BOOL=OFF \
        -DUSE_SYSTEM_FFTW3F:BOOL=OFF \
        -DUSE_SYSTEM_GLUT:BOOL=OFF \
        -DUSE_SYSTEM_GSL:BOOL=OFF \
        -DUSE_SYSTEM_HDF5:BOOL=OFF \
        -DUSE_SYSTEM_ITK:BOOL=OFF \
        -DUSE_SYSTEM_NETCDF:BOOL=OFF \
        -DUSE_SYSTEM_NIFTI:BOOL=OFF \
        -DUSE_SYSTEM_PCRE:BOOL=OFF \
        -DUSE_SYSTEM_ZLIB:BOOL=OFF
RUN make -j${PARALLEL}
RUN cpack -G DEB && \
    cp *.deb /root/build/
RUN make test > /root/build/test_minc-toolkit_v2.txt
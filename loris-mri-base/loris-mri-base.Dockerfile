FROM loris-base:latest
LABEL org.childmind.image.authors="Gabriel Schubiner <gabriel.schubiner@childmind.org>"

ARG MINC_TOOLKIT_VERSION
ENV MINC_TOOLKIT_VERSION=${MINC_TOOLKIT_VERSION:-1.9.18}
ARG MINC_TOOLKIT_RELEASE_VERSION
ENV MINC_TOOLKIT_RELEASE_VERSION=${MINC_TOOLKIT_RELEASE_VERSION:-1.9.18-20220625-Ubuntu_20.04}
ARG MINC_TOOLKIT_TESTSUITE_VERSION
ENV MINC_TOOLKIT_TESTSUITE_VERSION=${MINC_TOOLKIT_TESTSUITE_VERSION:-0.1.3-20131212}
ARG BEAST_LIBRARY_VERSION
ENV BEAST_LIBRARY_VERSION=${BEAST_LIBRARY_VERSION:-1.1.0-20121212}
ARG BIC_MNI_MODELS_VERSION
ENV BIC_MNI_MODELS_VERSION=${BIC_MNI_MODELS_VERSION:-0.1.1-20120421}

# Update and install dependencies.
RUN DEBIAN_FRONTEND=noninteractive \
    # add-apt-repository universe && \
    apt-get -qqq update && \
    apt-get -y install \
        cpanminus \
        dcmtk \
        gdebi-core \
        imagemagick \
        libc6 \
        libglx-mesa0 \
        # libgl1-mesa-glx \
        libglu1-mesa \
        libstdc++6 \
        octave \
        perl \
        pkg-config \
        python3-dev \
        python3-pip \
        virtualenv \
    && rm -rf /var/lib/apt/lists/*

# Install Perl dependencies.
# Copy patched version of Digest::BLAKE2 because CPAN version fails to build.
# Reference: https://github.com/Raptor3um/raptoreum/issues/48#issuecomment-969125200
COPY deps/Digest-BLAKE2-0.02.tar.gz /root/
RUN cpanm /root/Digest-BLAKE2-0.02.tar.gz
RUN cpanm \
        Archive::Extract \
        Archive::Zip \
        DateTime \
        DBI \
        DBD::mysql \
        File::Type \
        Getopt::Tabular \
        JSON \
        Math::Round \
        Moose \
        MooseX::Privacy \
        Path::Class \
        Pod::Perldoc \
        Pod::Markdown \
        Pod::Usage \
        String::ShellQuote \
        Time::JulianDay \
        TryCatch \
        Throwable

# Download MINC Toolkit and dependencies.
ADD --chown=lorisadmin:lorisadmin https://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/minc-toolkit-${MINC_TOOLKIT_RELEASE_VERSION}-x86_64.deb /home/lorisadmin/
ADD --chown=lorisadmin:lorisadmin https://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/minc-toolkit-testsuite-${MINC_TOOLKIT_TESTSUITE_VERSION}.deb /home/lorisadmin/
ADD --chown=lorisadmin:lorisadmin http://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/beast-library-${BEAST_LIBRARY_VERSION}.deb /home/lorisadmin/
ADD --chown=lorisadmin:lorisadmin http://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/bic-mni-models-${BIC_MNI_MODELS_VERSION}.deb /home/lorisadmin/

# Install MINC Toolkit and dependencies.
RUN dpkg -i /home/lorisadmin/minc-toolkit-${MINC_TOOLKIT_RELEASE_VERSION}-x86_64.deb \
            /home/lorisadmin/minc-toolkit-testsuite-${MINC_TOOLKIT_TESTSUITE_VERSION}.deb \
            /home/lorisadmin/bic-mni-models-${BIC_MNI_MODELS_VERSION}.deb \
            /home/lorisadmin/beast-library-${BEAST_LIBRARY_VERSION}.deb \
    && apt-get -f install -y
RUN gdebi /home/lorisadmin/minc-toolkit-${MINC_TOOLKIT_RELEASE_VERSION}-x86_64.deb
RUN gdebi /home/lorisadmin/minc-toolkit-testsuite-${MINC_TOOLKIT_TESTSUITE_VERSION}.deb 
RUN gdebi /home/lorisadmin/bic-mni-models-${BIC_MNI_MODELS_VERSION}.deb
RUN gdebi /home/lorisadmin/beast-library-${BEAST_LIBRARY_VERSION}.deb
RUN apt-get autoclean && rm -rf /var/lib/apt/lists/*

# Add TPCCLIB from local repository because download is rate-limited and takes a long time.
# ADD https://seafile.utu.fi/d/15843078fb/files/?p=%2Ftpcclib-0.8.0-Linux-x86_64.tar.gz&dl=1 /home/lorisadmin/
ADD deps/tpcclib-0.8.0-Linux-x86_64.tar.gz /home/lorisadmin/tpcclib

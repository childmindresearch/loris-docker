FROM loris-base:latest
LABEL org.childmind.image.authors="Gabriel Schubiner <gabriel.schubiner@childmind.org>"

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

# Add TPCCLIB from local repository because download is rate-limited and takes a long time.
# ADD https://seafile.utu.fi/d/15843078fb/files/?p=%2Ftpcclib-0.8.0-Linux-x86_64.tar.gz&dl=1 /home/lorisadmin/
ADD deps/tpcclib-0.8.0-Linux-x86_64.tar.gz /home/lorisadmin/tpcclib

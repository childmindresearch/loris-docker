FROM ubuntu:focal
LABEL org.childmind.image.authors="Gabriel Schubiner <gabriel.schubiner@childmind.org>"

ARG LORIS_VERSION=25.0.2
ARG LORIS_MRI_VERSION=24.1.16
ARG MINC_TOOLKIT_VERSION=1.9.18-20220625-Ubuntu_20.04
ARG MINC_TOOLKIT_TESTSUITE_VERSION=0.1.3-20131212
ARG BEAST_LIBRARY_VERSION=1.1.0-20121212
ARG BIC_MNI_MODELS_VERSION=0.1.1-20120421
ENV PROJECT_NAME="philani"
ENV TZ="America/New_York"

# Update, install some utilities, add R repo, and install rest of dependencies.
RUN apt-get -qqq update && \
    # Install software-properties-common and lsb-release for adding R repo.
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
    software-properties-common \
    lsb-release && \
    # Add R repo.
    add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/" && \
    # Install remaining dependencies.
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
    apache2 \
    apt-utils \
    bc \
    curl \
    cython3 \
    dirmngr \
    ed \ 
    gdebi-core \
    git \
    gnupg2 \
    imagemagick \
    libapache2-mod-php8.1 \
    libc6 \
    libcurl4-openssl-dev \
    libgl1-mesa-glx \
    libglu1-mesa \
    libjpeg8 \
    libmysqlclient-dev \
    libssl-dev \
    libstdc++6 \
    libxml2-dev \
    make \
    mysql-client \
    nodejs \
    npm \
    octave \
    perl \
    php8.1 \
    php-cli \
    php8.1-mysql \
    php8.1-xml \
    php8.1-mbstring \
    php8.1-gd \
    php8.1-zip \
    python3 \
    python3-cffi \
    python3-dev \
    python3-matplotlib \
    python3-numpy \
    python3-pil \
    python3-pip \
    python3-scipy \
    r-base \
    r-base-dev \
    tzdata \
    unzip \
    virtualenv \
    wget \
    zip \
    && rm -rf /var/lib/apt/lists/*

### Base Loris Install ###
# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Configure lorisadmin user
RUN useradd -U -m -G sudo,www-data -s /bin/bash -u 1001 lorisadmin
ADD --chown=lorisadmin:lorisadmin https://github.com/aces/Loris/archive/refs/tags/v${LORIS_VERSION}.tar.gz /home/lorisadmin/
RUN tar -xzf /home/lorisadmin/v${LORIS_VERSION}.tar.gz -C /home/lorisadmin/ \
    && mv /home/lorisadmin/Loris-${LORIS_VERSION} /var/www/loris
RUN chmod 755 /var/www/loris && chown -R lorisadmin:lorisadmin /var/www/loris
WORKDIR /var/www/loris

# Set up logs dir and permissions.
RUN mkdir -m 770 -p ./tools/logs \
    && chown lorisadmin:www-data ./tools/logs

# Set up initial project directory skeleton and permissions.
RUN mkdir -m 770 -p ./project/data ./project/libraries ./project/instruments \
                    ./project/templates ./project/tables_sql ./project/modules \
    && chown -R lorisadmin:www-data ./project

# Set up smarty cache directory
RUN mkdir -m 777 -p ./smarty/templates_c \
    && chown www-data:www-data ./smarty/templates_c \
    && chown -R lorisadmin:www-data ./smarty/templates

# Configure Apache
RUN sed -e "s#%LORISROOT%#/var/www/loris#g" \
        -e "s#%PROJECTNAME%#${PROJECT_NAME}#g" \
        -e "s#%LOGDIRECTORY%#/var/log/apache2#g" \
        <./docs/config/apache2-site \
        >/etc/apache2/sites-available/"${PROJECT_NAME}".conf \
    && ln -s /etc/apache2/sites-available/"${PROJECT_NAME}".conf \
                  /etc/apache2/sites-enabled/"${PROJECT_NAME}".conf \
    && a2dissite 000-default \
    && a2ensite "${PROJECT_NAME}".conf \
    && a2enmod rewrite \
    && a2enmod headers \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Configure PHP
RUN sed -i -e "s/^session.gc_maxlifetime =.*\$/session.gc_maxlifetime = 10800/" \
           -e "s/^max_execution_time =.*\$/max_execution_time = 10800/" \
           -e "s/^upload_max_filesize =.*\$/upload_max_filesize = 1024M/" \
           -e "s/^post_max_size =.*\$/post_max_size = 10800/" \
        /etc/php/8.1/apache2/php.ini 

# Install dependencies
RUN su lorisadmin -c make

# [X] Loris frontend admin account: env variable, pushed to DB in init script
# [X] Check config.xml doesn't exist: entrypoint script
# [X] Check Loris DB doesn't already exist: entrypoint script
# Loris Database Setup: 
# - [X] Database creation done in MySQL container via init SQL files
# - [X] MySQL user set up via MySQL container config
# [X] Write config.xml: entrypoint script
# TODO =: Remove CouchDB from Loris config

#ENV LORIS_SQL_DB=LorisDB
#ENV LORIS_SQL_HOST=mysql
#ENV LORIS_SQL_USER=loris
#ENV LORIS_SQL_PASSWORD=
#ENV LORIS_BASEURL=

### Loris-MRI ###

# Install R packages
# RUN Rscript -e 'update.packages(repos="https://cloud.r-project.org",ask=F)' && \
#     Rscript -e 'install.packages(c("lme4","tidyverse","batchtools","Rcpp","rjson","jsonlite","tidyr","shiny","visNetwork","DT"),repos="https://cloud.r-project.org")' && \
#     Rscript -e 'install.packages(c("gridBase","data.tree"),repos="https://cloud.r-project.org")' && \
#     Rscript -e 'install.packages(c("glmnet","doMC"),repos="https://cloud.r-project.org")' && \
#     Rscript -e 'install.packages(c("bigstatsr"),repos="https://cloud.r-project.org")'

# # install RMINC
# RUN . /opt/minc/1.9.18/minc-toolkit-config.sh && \
#     wget https://github.com/vfonov/RMINC/archive/v1.5.2.3tidy.tar.gz && \
#     R CMD INSTALL v1.5.2.3tidy.tar.gz --configure-args='--with-build-path=/opt/minc/1.9.18' && \
#     rm -f v1.5.2.3tidy.tar.gz && \
#     rm -f v1.5.2.3tidy.tar.gz

# # install patched version of scoop
# RUN . /opt/minc/1.9.18/minc-toolkit-config.sh && \
#     wget https://github.com/vfonov/scoop/archive/master.tar.gz && \
#     pip3 install master.tar.gz --no-cache-dir && \
#     rm -rf master.tar.gz

# # install pyezminc, pyminc, minc2-simple
# RUN . /opt/minc/1.9.18/minc-toolkit-config.sh && \
#     pip3 install pyminc --no-cache-dir && \
#     wget https://github.com/BIC-MNI/pyezminc/archive/release-1.2.01.tar.gz && \
#     pip3 install release-1.2.01.tar.gz --no-cache-dir && \
#     wget https://github.com/NIST-MNI/minc2-simple/archive/v2.2.30.tar.gz && \
#     tar zxf v2.2.30.tar.gz && \
#     python3 minc2-simple-2.2.30/python/setup.py install && \
#     rm -rf v2.2.30.tar.gz release-1.2.01.tar.gz minc2-simple-0 

WORKDIR /home/lorisadmin
ADD --chown=lorisadmin:lorisadmin https://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/minc-toolkit-${MINC_TOOLKIT_VERSION}-x86_64.deb /home/lorisadmin/
ADD --chown=lorisadmin:lorisadmin https://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/minc-toolkit-testsuite-${MINC_TOOLKIT_TESTSUITE_VERSION}.deb /home/lorisadmin/
ADD --chown=lorisadmin:lorisadmin http://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/beast-library-${BEAST_LIBRARY_VERSION}.deb /home/lorisadmin/
ADD --chown=lorisadmin:lorisadmin http://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/bic-mni-models-${BIC_MNI_MODELS_VERSION}.deb /home/lorisadmin/
RUN gdebi minc-toolkit-${MINC_TOOLKIT_VERSION}.deb && \
    gdebi minc-toolkit-testsuite-${MINC_TOOLKIT_TESTSUITE_VERSION}.deb && \
    gdebi bic-mni-models-${BIC_MNI_MODELS_VERSION}.deb && \
    gdebi beast-library-${BEAST_LIBRARY_VERSION}.deb && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data/${PROJECT_NAME} /opt/${PROJECT_NAME}/bin/mri \
    && chown -R lorisadmin:lorisadmin /data/${PROJECT_NAME} /opt/${PROJECT_NAME}

ADD --chown=lorisadmin:lorisadmin \
    https://github.com/aces/Loris-MRI/archive/refs/tags/v${LORIS_MRI_VERSION}.tar.gz /home/lorisadmin/
RUN tar -xzf /home/lorisadmin/v${LORIS_MRI_VERSION}.tar.gz -C /opt/${PROJECT_NAME}/bin/mri

# Install MINC toolkit from http://bic-mni.github.io/
# sudo dpkg -i minc-toolkit<version>.deb
# https://github.com/aces/Loris-MRI/blob/main/README.md


EXPOSE 80
VOLUME ["/var/www/loris/project", "/var/log/apache2"]
COPY --chown=lorisadmin:www-data --chmod=770 loris-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
#CMD ["apache2ctl", "-D", "FOREGROUND"]

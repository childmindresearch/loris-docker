FROM ubuntu:noble
LABEL org.childmind.image.authors="Gabriel Schubiner <gabriel.schubiner@childmind.org>"

ENV TZ="America/New_York"

# Use Bash as the default shell.
SHELL ["/bin/bash", "-c"]

# Update and install dependencies.
RUN apt-get -qqq update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install \
        apache2 \
        curl \
        git \
        libapache2-mod-php8.3 \
        libmysqlclient-dev \
        make \
        msmtp \
        mysql-client \
        nodejs \
        npm \
        php8.3 \
        php-cli \
        php8.3-mysql \
        php8.3-xml \
        php8.3-mbstring \
        php8.3-gd \
        php8.3-zip \
        software-properties-common \
        unzip \
        xmlstarlet \
        zip \
    && rm -rf /var/lib/apt/lists/*

### Base Loris Install ###
# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

FROM ubuntu:jammy
LABEL org.childmind.image.authors="Gabriel Schubiner <gabriel.schubiner@childmind.org>"

ARG LORIS_VERSION 25.0.2
ENV PROJECT_NAME="philani"
ENV TZ="America/New_York"

# Stock images come without apt archive -- needs an update
RUN apt-get -qqq update
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install \
    apache2 \
    curl \
    git \
    libapache2-mod-php8.1 \
    libmysqlclient-dev \
    make \
    mysql-client \
    nodejs \
    npm \
    php8.1 \
    php-cli \
    php8.1-mysql \
    php8.1-xml \
    php8.1-mbstring \
    php8.1-gd \
    php8.1-zip \
    python3 \
    python3-dev \
    python3-pip \
    software-properties-common \
    unzip \
    virtualenv \
    zip \
    && rm -rf /var/lib/apt/lists/*

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

##### Loris-MRI #####
# sudo mkdir -p /data/$projectname
# sudo mkdir -p /opt/$projectname/bin/mri
# sudo chown -R lorisadmin:lorisadmin /data/$projectname
# sudo chown -R lorisadmin:lorisadmin /opt/$projectname
# Download the latest release from the releases page and extract it to /opt/$projectname/bin/mri
# https://github.com/aces/Loris-MRI/releases
# Install MINC toolkit from http://bic-mni.github.io/
# sudo dpkg -i minc-toolkit<version>.deb
# https://github.com/aces/Loris-MRI/blob/main/README.md


EXPOSE 80
VOLUME ["/var/www/loris/project", "/var/log/apache2"]
COPY --chown=lorisadmin:www-data --chmod=770 loris-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
#CMD ["apache2ctl", "-D", "FOREGROUND"]

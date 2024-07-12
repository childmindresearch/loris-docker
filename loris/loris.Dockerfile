# LORIS_SOURCE can be either "release" or "git".
# If "release", LORIS_VERSION refers to the release version.
# If "git", pulls from HEAD.
ARG LORIS_SOURCE=release
ARG LORIS_BASE=${LORIS_BASE:-loris-base}
FROM ${LORIS_BASE}:latest AS base
LABEL org.childmind.image.authors="Gabriel Schubiner <gabriel.schubiner@childmind.org>"

## Declare default environment args and variables for installation. ##
# Loris Version
ARG LORIS_VERSION
ENV LORIS_VERSION=${LORIS_VERSION:-26.0.0}
ENV LORIS_VERSION_TAG=v${LORIS_VERSION}

# Project
ARG PROJECT_NAME
ENV PROJECT_NAME=${PROJECT_NAME:-loris}

## Variables used in initialization scripts ##
# Site / Visit
ENV BASE_PATH=/var/www/loris/
ENV SITE_NAME=Montreal
ENV SITE_ALIAS=MTL
ENV MRI_ALIAS=MTL
ENV STUDY_SITE_YN=Y
ENV VISIT_NAME=V1
ENV VISIT_LABEL=V1
ENV WINDOW_MIN_DAYS=0
ENV WINDOW_MAX_DAYS=100
ENV OPTIMUM_MIN_DAYS=40
ENV OPTIMUM_MAX_DAYS=60
ENV WINDOW_MIDPOINT_DAYS=50 

### Base Loris Install ###
# Configure lorisadmin user
RUN useradd -U -m -G sudo,www-data -s /bin/bash -u 1001 lorisadmin
RUN mkdir /home/lorisadmin/.npm && chown -R lorisadmin:lorisadmin /home/lorisadmin/.npm

# Install from Loris release
FROM base AS loris-release
RUN echo ${LORIS_VERSION_TAG}
ADD --chown=lorisadmin:lorisadmin https://github.com/aces/Loris/archive/refs/tags/${LORIS_VERSION_TAG}.tar.gz /home/lorisadmin/
RUN tar -xzf /home/lorisadmin/${LORIS_VERSION_TAG}.tar.gz -C /home/lorisadmin/ \
    && mv /home/lorisadmin/Loris-${LORIS_VERSION} /var/www/loris

# Install from loris git repository
FROM base AS loris-git
ADD --chown=lorisadmin:lorisadmin https://github.com/aces/Loris.git /var/www/loris

# Continue installation with appropriate source
FROM loris-${LORIS_SOURCE} AS loris

# Set permissions on Loris directory and set working directory
RUN chmod 755 /var/www/loris && chown -R lorisadmin:lorisadmin /var/www/loris
WORKDIR /var/www/loris

# Set up logs dir and permissions
RUN mkdir -m 770 -p ./tools/logs \
    && chown lorisadmin:www-data ./tools/logs

# Set up initial project directory skeleton and permissions
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
        /etc/php/8.3/apache2/php.ini 

# Install dependencies
RUN su lorisadmin -c make

# Install entrypoint scripts
RUN mkdir -p /etc/entrypoint.d
COPY --chown=lorisadmin:www-data --chmod=770 install-loris.sh /etc/entrypoint.d/install-loris.sh
COPY --chown=lorisadmin:www-data --chmod=770 loris-entrypoint.sh /entrypoint.sh

# Set image ports and volumes
EXPOSE 80
#VOLUME ["/var/www/loris/project", "/var/log/apache2"]
ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2ctl", "-D", "FOREGROUND"]

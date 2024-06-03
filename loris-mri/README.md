# Loris-MRI

Uses loris-base as base image and installs Loris-MRI module.

## ENV Variables

Includes all variables from loris-base, as well as:


### Build ARGs

LORIS_MRI_VERSION=24.1.16
MINC_TOOLKIT_VERSION=1.9.18
MINC_TOOLKIT_RELEASE_VERSION=1.9.18-20220625-Ubuntu_20.04
MINC_TOOLKIT_TESTSUITE_VERSION=0.1.3-20131212
BEAST_LIBRARY_VERSION=1.1.0-20121212
BIC_MNI_MODELS_VERSION=0.1.1-20120421

### Install Variables

MRI_BIN_DIR=/opt/${PROJECT_NAME}/bin/mri
PROD_FILENAME=prod
# Loris Docker

Docker build for Loris


## Containers

### Loris-Base

Image with Loris dependencies installed.

### Loris-MRI-Base

Image with Loris and Loris-MRI dependencies installed.

### Loris

Image with Loris installed, does not include Loris-MRI, but can be built with Loris and Loris-MRI dependencies installed.

To build with only Loris dependencies, use environment variable LORIS_BASE=loris-base.
To build with Loris and Loris-MRI dependencies, use LORIS_BASE=loris-mri-base.

Switching using this env var reduces code duplication, while allowing for faster builds because loris-mri dependencies don't need to be reinstalled when changes are made to loris.

### Loris-MRI

Image with Loris and Loris-MRI installed.

### MINC-toolkit (Not Functional)

Image to build MINC Toolkit. Not used currently, but available for MINC repository downtime.

## Building

Repository uses [Task](https://taskfile.dev/) to build the images. 

After installing Task, run `task <image_name>` to build. 

To tag the loris-mri image with an AWS ECR repository to enable pushing the image, set the following variables in secrets/aws-ecr.env

-  AWS_ECR_TAG=true
-  AWS_ECR_REGION
-  AWS_ACCOUNT_ID
-  AWS_ECR_REPO_NAME
-  AWS_ECR_IMAGE_TAG
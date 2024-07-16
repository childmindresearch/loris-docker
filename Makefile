
# Build configuration variables
PLATFORM = linux/amd64
LORIS_SOURCE = release
LORIS_VERSION = 26.0.0
ifdef NO_CACHE
	CACHE_ARG = --no-cache
endif

# Build artifact variables
IMAGES := loris loris-base loris-mri loris-mri-base loris-mri-deps
# buildstamp := docker-buildstamp
# BUILDSTAMPS := $(addsuffix /$(buildstamp), $(IMAGES))

.PHONY: all clean $(IMAGES)
all: $(IMAGES)

# Targets for each image depending on buildstamp target
# $(IMAGES): %: %/$(buildstamp)
# $(IMAGES): %:
# 	@echo "Building $@ container.."
# 	$(docker-build)

loris: loris-base
	@echo "Building loris container.."
	docker buildx build $(CACHE_ARG) --platform $(PLATFORM) --build-arg "LORIS_SOURCE=$(LORIS_SOURCE)" --build-arg "LORIS_BASE=loris-base" -t loris:latest -f loris/loris.Dockerfile loris 

loris-base:
	@echo "Building loris-base container.."
	docker buildx build $(CACHE_ARG) --platform $(PLATFORM) -t loris-base:latest -f loris-base/loris-base.Dockerfile loris-base

loris-mri-base: loris-base
	@echo "Building loris-mri-base container.."
	docker buildx build $(CACHE_ARG) --platform $(PLATFORM) -t loris-mri-base:latest -f loris-mri-base/loris-mri-base.Dockerfile loris-mri-base

loris-mri-deps: loris-mri-base
	@echo "Building loris-mri-deps container.."
	docker buildx build $(CACHE_ARG) --platform $(PLATFORM) --build-arg "LORIS_SOURCE=$(LORIS_SOURCE)" --build-arg "LORIS_BASE=loris-mri-base" -t loris-mri-deps:latest -f loris/loris.Dockerfile loris

loris-mri: loris-mri-deps
	@echo "Building loris-mri container.."
	docker buildx build $(CACHE_ARG) --platform $(PLATFORM) --build-arg "LORIS_SOURCE=$(LORIS_SOURCE)" -t loris-mri:latest -f loris-mri/loris-mri.Dockerfile loris-mri

# clean:
#     docker image rm -f $(IMAGES)
#     rm -f $(BUILDSTAMPS)

# $(@:%/.$(buildstamp)=%)
# $(dir $@)

# define from-buildstamp
# $(@:%/$(buildstamp)=%)
# endef

# define docker-build
# 	@echo "Building $@ container.."
# 	docker buildx build $(platform_arg) $(loris_source_arg) $(loris_base_arg) -t $(from-buildstamp):latest -f $(from-buildstamp)/$(from-buildstamp).Dockerfile $(from-buildstamp)
# endef
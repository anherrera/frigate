BOARDS += spark

# Pragmatic variant: CUDA 12.9 base, Jetson Zoo ORT 1.19 wheel.
SPARK_BASE ?= nvcr.io/nvidia/tensorrt:25.06-py3
SPARK_ARGS := ARCH=arm64 BASE_IMAGE=$(SPARK_BASE) SLIM_BASE=$(SPARK_BASE)

# Native variant: CUDA 13 base, onnxruntime built from source for sm_120/sm_121.
SPARK_NATIVE_BASE ?= nvcr.io/nvidia/tensorrt:26.03-py3
SPARK_NATIVE_ARGS := ARCH=arm64 BASE_IMAGE=$(SPARK_NATIVE_BASE) SLIM_BASE=$(SPARK_NATIVE_BASE)

local-spark: version
	$(SPARK_ARGS) docker buildx bake --file=docker/spark/spark.hcl spark \
		--set spark.tags=frigate:latest-spark \
		--load

local-spark-native: version
	$(SPARK_NATIVE_ARGS) docker buildx bake --file=docker/spark/spark.hcl spark-native \
		--set spark-native.tags=frigate:latest-spark-native \
		--load

build-spark:
	$(SPARK_ARGS) docker buildx bake --file=docker/spark/spark.hcl spark \
		--set spark.tags=$(IMAGE_REPO):${GITHUB_REF_NAME}-$(COMMIT_HASH)-spark

push-spark: build-spark
	$(SPARK_ARGS) docker buildx bake --file=docker/spark/spark.hcl spark \
		--set spark.tags=$(IMAGE_REPO):${GITHUB_REF_NAME}-$(COMMIT_HASH)-spark \
		--push

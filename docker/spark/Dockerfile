# syntax=docker/dockerfile:1.6
#
# DGX Spark / GB10 (aarch64 SBSA, CUDA 12.9, TRT 10, sm_120/sm_121).
# Pragmatic variant: Jetson Zoo ORT 1.19 wheel (CUDA 12 / cuDNN 8 / sm_87
# native + PTX JIT for sm_121). For native sm_121 kernels, see Dockerfile.native.

ARG DEBIAN_FRONTEND=noninteractive
ARG BASE_IMAGE

FROM deps AS frigate-spark

ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

# Jetson Zoo ORT 1.19 was built against cuDNN 8, but NGC 25.06 ships cuDNN 9.
# Install libcudnn8 alongside so the wheel finds its expected major version.
RUN apt-get -qq update \
    && apt-get -qq install -y --no-install-recommends libcudnn8 \
    && rm -rf /var/lib/apt/lists/*

# Swap CPU onnxruntime for the JetPack Zoo aarch64 GPU build. PyPI has no
# aarch64 onnxruntime-gpu wheels; this is the same wheel the jp6 image uses.
# sm_120/121 kernels come from PTX JIT on first inference (warmup in
# frigate/detectors/plugins/onnx.py:67 front-loads that cost).
ADD https://nvidia.box.com/shared/static/9yvw05k6u343qfnkhdv2x6xhygze0aq1.whl \
    /tmp/onnxruntime_gpu-1.19.0-cp311-cp311-linux_aarch64.whl
RUN pip3 uninstall -y onnxruntime \
    && pip3 install --no-cache-dir /tmp/onnxruntime_gpu-1.19.0-cp311-cp311-linux_aarch64.whl \
    && rm /tmp/onnxruntime_gpu-1.19.0-cp311-cp311-linux_aarch64.whl

WORKDIR /opt/frigate/
COPY --from=rootfs / /

# TRT 10 + CUDA 13 libs live in /usr/local/cuda and the driver lib dirs
# that the CDI mount provides at runtime. Make sure the linker finds them.
RUN echo "/usr/local/cuda/lib64" > /etc/ld.so.conf.d/cuda.conf \
    && ldconfig

HEALTHCHECK --start-period=600s --start-interval=5s --interval=15s --timeout=5s --retries=3 \
    CMD curl --fail --silent --show-error http://127.0.0.1:5000/api/version || exit 1

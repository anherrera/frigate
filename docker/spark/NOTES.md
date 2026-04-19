# Frigate on DGX Spark (GB10) — operational notes

Scratchpad of non-obvious things encountered while bringing this up on
`NVIDIA GB10` / `aarch64 SBSA` / `Ubuntu 24.04 host` / `driver 580.126.09`.

## Build variants

- `make local-spark` — pragmatic path, Jetson Zoo ORT 1.19 wheel on
  NGC `tensorrt:25.06-py3` (CUDA 12.9 + cuDNN 9). Gets detector on GPU
  via PTX JIT. Requires manually installing `libcudnn8` compat packages
  (Jetson wheel expects cuDNN 8). Not currently working end-to-end.
- `make local-spark-native` — from-source ORT 1.24.4 on NGC
  `tensorrt:26.03-py3` (CUDA 13.1 + cuDNN 9.10 + TRT 10). Targets
  `sm_121` natively. This is what we verified working — 3.2 ms/frame
  inference on YOLOv9t @ 320×320, 91.8% person detection confidence.

## Hardware decode (when cameras arrive)

Frigate logs `WARNING: Did not detect hwaccel, using a GPU for
accelerated video decoding is highly recommended` by default. To fix,
add per-camera:

```yaml
cameras:
  <name>:
    ffmpeg:
      hwaccel_args: "-hwaccel cuda -threads 1"
```

Critical: use the flag form above, **not** `preset-nvidia`. The preset
triggers
`Assertion !p->parent->stash_hwaccel failed` (CVE-2022-48434 pthread_frame
bug) on this ffmpeg + driver combo. The explicit `-threads 1` sidesteps
it.

Credit: github.com/blakeblackshear/frigate/issues/21002 comment by menemy.

## Defensive runtime patches baked into spark-native

`Dockerfile.native` sed-patches two lines in
`frigate/detectors/detection_runners.py` at image build:

- `CudaGraphRunner.is_model_supported(model_type)` → `False`
- `ONNXModelRunner.is_cpu_complex_model(model_type)` → `True`

These disable CUDA Graph optimization and force basic graph execution
mode. Source: piotr-siedlak/frigate-gb10. Observed symptom they avoid
(we have not reproduced): intermittent crashes on sm_121 under sustained
load, related to unsupported PTX ops during CUDA graph fusion.

## Upstream patches (could be a PR)

Two minor fixes in `docker/main/` for Ubuntu 24.04 (noble) support:

- `build_nginx.sh` and `build_sqlite_vec.sh`: the `else` branch assumed
  legacy `/etc/apt/sources.list`; noble uses deb822 at
  `/etc/apt/sources.list.d/ubuntu.sources`. The patches add an `elif`
  branch that detects and edits deb822. No behavior change for
  Debian 12 or Ubuntu 22.04 jammy.

## CDI setup (host, one-time)

GPU exposure uses Container Device Interface, not the legacy
`nvidia-container-runtime`:

```bash
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
# containers access GPU via:
#   docker run --device nvidia.com/gpu=all ...
#   or in compose: devices: ["nvidia.com/gpu=all"]
```

No `/etc/docker/daemon.json` edit, no `systemctl restart docker` — pure
file write. Works on Docker 28+ with nvidia-container-toolkit 1.17+.

## GPU memory budget on this host

GB10 has 128 GB unified LPDDR5X. Current resident tenants seen during
smoke test (not counting Frigate):

- `ollama` ~43 GiB
- `whisper-venv` ~9.6 GiB
- Frigate detector ~286 MiB (trivial)

Plenty of headroom for a dozen-plus cameras.

## Reference implementations

- piotr-siedlak/frigate-gb10 — Debian 12 base + host CUDA mount,
  otherwise similar strategy. Uses `--use_cuda` only (no TRT EP).
- This fork — NGC all-in-one base + `--use_cuda --use_tensorrt`.

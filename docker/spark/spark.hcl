variable "ARCH" {
  default = "arm64"
}
variable "BASE_IMAGE" {
  default = null
}
variable "SLIM_BASE" {
  default = null
}
variable "BASE_HOOK" {
  # NGC TRT images are Ubuntu-based; pull deadsnakes for python3.11
  default = <<EOT
if grep -iq \"ubuntu\" /etc/os-release; then
  . /etc/os-release

  echo "deb https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu $VERSION_CODENAME main" >> /etc/apt/sources.list.d/deadsnakes.list
  echo "deb-src https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu $VERSION_CODENAME main" >> /etc/apt/sources.list.d/deadsnakes.list

  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F23C5A6CF475977595C89F51BA6932366A755776

  # NGC TRT images ship a forest of dpkg-installed Python packages without
  # RECORD files. Strip every dist-info/egg-info so pip doesn't try to
  # uninstall anything it can't find a record for — actual package code
  # stays, just the install manifests go.
  find /usr/lib/python3/dist-packages -maxdepth 1 -type d \( -name '*.dist-info' -o -name '*.egg-info' \) -exec rm -rf {} + 2>/dev/null || true
fi
EOT
}

target "_build_args" {
  args = {
    BASE_IMAGE = BASE_IMAGE,
    SLIM_BASE = SLIM_BASE,
    BASE_HOOK = BASE_HOOK
  }
  platforms = ["linux/${ARCH}"]
}

target "deps" {
  dockerfile = "docker/main/Dockerfile"
  target = "deps"
  inherits = ["_build_args"]
}

target "rootfs" {
  dockerfile = "docker/main/Dockerfile"
  target = "rootfs"
  inherits = ["_build_args"]
}

target "wheels" {
  dockerfile = "docker/main/Dockerfile"
  target = "wheels"
  inherits = ["_build_args"]
}

target "spark" {
  dockerfile = "docker/spark/Dockerfile"
  context = "."
  contexts = {
    deps = "target:deps",
    rootfs = "target:rootfs",
    wheels = "target:wheels"
  }
  target = "frigate-spark"
  inherits = ["_build_args"]
}

target "spark-native" {
  dockerfile = "docker/spark/Dockerfile.native"
  context = "."
  contexts = {
    deps = "target:deps",
    rootfs = "target:rootfs",
    wheels = "target:wheels"
  }
  target = "frigate-spark-native"
  inherits = ["_build_args"]
}

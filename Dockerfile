# docker build -t shadertoy-render .
# docker run --rm -v "$(pwd)":/work    -e RES=2560x1440 -e FPS=60    shadertoy-render shader.glsl audio.mp3 out.mp4
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1️⃣  Core build/runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl ca-certificates build-essential python3 pkg-config \
        ffmpeg \
           libegl1-mesa libegl1-mesa-dev libgl1-mesa-dev libgl1-mesa-dri mesa-utils \
           libglfw3-dev \
           libx11-dev        libxcursor-dev  libxi-dev \
           libxinerama-dev   libxrandr-dev   libxxf86vm-dev \
    && rm -rf /var/lib/apt/lists/*

# 2️⃣  Go toolchain (latest stable)
ARG GO_VERSION=1.24.4
RUN curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xz
ENV GOPATH=/go
ENV PATH=/usr/local/go/bin:${GOPATH}/bin:$PATH

# 3️⃣  Build **shady** once inside the image
RUN go install github.com/polyfloyd/shady/cmd/shady@latest

# 4️⃣  Head-less EGL / Mesa software driver
ENV LIBGL_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri  \
    GALLIUM_DRIVER=llvmpipe                             \
    LIBGL_ALWAYS_SOFTWARE=true                          \
    EGL_PLATFORM=surfaceless                            \
    MESA_GL_VERSION_OVERRIDE=4.6
# 5️⃣  Helper script (same dir as Dockerfile)
COPY render_shader.sh /usr/local/bin/render_shader
RUN chmod +x /usr/local/bin/render_shader

WORKDIR /work
ENTRYPOINT ["render_shader"]

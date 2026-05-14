FROM ghcr.io/australian-imaging-service/ctp:v2025.03.26

# Upstream bug: linux-x86_64.zip extracts into a subdirectory, so the glob
# `ext/*.so` in the original Dockerfile never matched, leaving LD_LIBRARY_PATH
# (/JavaPrograms/lib) empty. Just copy them to where the JVM can find them.
RUN cp /JavaPrograms/ext/linux-x86_64/*.so /JavaPrograms/lib/

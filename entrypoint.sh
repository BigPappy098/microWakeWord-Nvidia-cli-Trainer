#!/bin/bash
# Keep the container alive for RunPod SSH / Web Terminal access.
# When users connect, RunPod opens a new bash session inside
# this running container — .bashrc handles environment setup.
exec sleep infinity

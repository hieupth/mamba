# Mamba
A minimal Ubuntu-based container image that ships with Miniforge, intended as a clean base for reproducible builds.

## Tags
| Tag | Meaning |
| --- | --- |
| `latest` | Newest Miniforge release, built on Canonical's newest LTS (`ubuntu:latest`) |
| `resolute` | Newest Miniforge release, built on Ubuntu 26.04 LTS |
| `noble` | Newest Miniforge release, built on Ubuntu 24.04 LTS |

Platforms: `linux/amd64`, `linux/arm64`.

## Extra packages
Inject additional apt packages at build time without touching the dockerfile:
```bash
docker build --build-arg PACKAGES="jq htop" .
```
Or set the `packages` input when dispatching the Build workflow.

## License
[Apache License 2.0](LICENSE).<br>
Copyright &copy; 2024 [Hieu Pham](https://github.com/hieupth). All rights reserved.

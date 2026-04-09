# Sub-Store Docker Umbrella Repo

This repository vendors the upstream source trees as Git subtrees so you can build a Sub-Store stack from source instead of relying on opaque prebuilt images.

## Layout

- `third_party/Sub-Store`: backend source
- `third_party/Sub-Store-Front-End`: frontend source
- `third_party/http-meta`: HTTP-META source
- `third_party/mihomo`: Mihomo core source on the `Meta` branch
- `third_party/shoutrrr`: push notification CLI source

## Initialize

Fresh clone:

```bash
git clone <this-repo-url>
cd sub-store-docker
```

No extra submodule step is required. The `third_party/*` directories are tracked directly in this repo.

## Imported Revisions

- `Sub-Store`: `a8afff161aad914ea949cf5dd93502cb7d0b34dd`
- `Sub-Store-Front-End`: `45a70952edeffb048dbfa7ec4155f2197d8f639d`
- `http-meta`: `e339aa7a3a5b9b95c7c5f66f876c5547452df065`
- `mihomo` (`Meta` branch): `97c526f4cdd61a94defd70891b03c1365de8b816`
- `shoutrrr`: `262ac52fc3b2cb30d414d24f8416302a6b60d4c6`

## Build Strategy

The top-level Dockerfile now builds all runtime components from source:

1. builds the frontend from `third_party/Sub-Store-Front-End`
2. builds the backend from `third_party/Sub-Store`
3. builds HTTP-META from `third_party/http-meta`
4. builds Mihomo from `third_party/mihomo`
5. builds `shoutrrr` from `third_party/shoutrrr`
6. copies the final runtime artifacts into a small final image

## Build

```bash
docker build -t sub-store-source .
```

If you want a custom version label embedded into the Mihomo binary metadata:

```bash
docker build \
  --build-arg MIHOMO_BUILD_VERSION=<label> \
  -t sub-store-source .
```

## Run

```bash
docker run --rm -p 3001:3001 -v sub-store-data:/opt/app/data sub-store-source
```

Container ports:

- `3001`: Sub-Store frontend
- `3000`: backend API
- `9876`: HTTP-META API

## Runtime Notes

- This Dockerfile builds `Sub-Store`, `Sub-Store-Front-End`, `http-meta`, `mihomo`, and `shoutrrr` from the vendored subtree sources under `third_party/`.
- No GitHub release assets are fetched during the Docker build anymore.
- The build still depends on external package registries and base images: npm/pnpm for the Node projects, Go modules for the Go projects, and the upstream Docker base images.

## Updating Upstream Code

Each vendored dependency can be updated with `git subtree pull --prefix=<path> <repo-url> <ref> --squash`.

Examples:

```bash
git subtree pull --prefix=third_party/Sub-Store https://github.com/sub-store-org/Sub-Store master --squash
git subtree pull --prefix=third_party/mihomo https://github.com/MetaCubeX/mihomo Meta --squash
```

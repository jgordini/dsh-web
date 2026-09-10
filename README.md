# dsh-web — DeepSeek Harness in a container

Packages `dsh web` (the DeepSeek Harness browser UI, `@deepseek-ai/dsh`) as a
self-contained image so it runs as a background service instead of a foreground
process in a terminal tab.

## Run it

```sh
docker compose up -d          # build + start, published on 127.0.0.1:3080
docker compose logs -f        # the login URL is printed here on first boot
docker compose down           # stop
```

Or without compose:

```sh
docker build -t dsh-web .
docker run -d --name dsh-web --restart unless-stopped \
  -p 127.0.0.1:3080:3080 \
  -e DEEPSEEK_API_KEY=sk-... \
  -v dsh-home:/home/dsh/.dsh \
  -v "$HOME/repos":/workspace \
  dsh-web
```

## Layout

| Path | Kind | Meaning |
|---|---|---|
| `/home/dsh/.dsh` | volume | harness home: profiles, sessions, settings, browser-session credentials |
| `/workspace` | bind/volume | the tree the agent edits (image default; `-w` / `working_dir:` to change) |
| `/pnpm` | image | pnpm global root holding `@deepseek-ai/dsh` |

Container state is deliberately separate from any host `~/.dsh`: host profiles
are pnpm symlinks into the host's global store and carry darwin-arm64 native
builds (node-pty, sharp), which cannot be mounted into a Linux container. The
container bootstraps its own `web` profile on first start.

## Auth

`dsh web` fences the UI behind a per-boot browser-session secret. The URL that
carries it is printed at startup:

```sh
docker logs dsh-web 2>&1 | grep -o 'http://[^ ]*' | head -1
```

Opening it once stores the session in the `dsh-home` volume, so later boots
don't ask again.

## Configuration

| Env | Default | Meaning |
|---|---|---|
| `DEEPSEEK_API_KEY` | — | required; LLM credential |
| `DEEPSEEK_BASE_URL` | `https://api.deepseek.com` | LLM endpoint |
| `DSH_HOME` | `/home/dsh/.dsh` | harness home |
| `DSH_VERSION` (build arg) | `0.1.2-rc.1` | pinned `@deepseek-ai/dsh` version |

## Coolify

Deployed from this repo as a **Dockerfile** build pack, port mapping
`8483:3080`, with `DEEPSEEK_API_KEY` set in the app's environment variables and
persistent storage for `/home/dsh/.dsh`.

## Notes

- The container user is uid/gid 501 (matches macOS hosts; irrelevant on Linux
  where only image-owned paths are written).
- Port publishing is loopback-only in the compose file on purpose — the UI is
  gated by a secret URL, not by a password.
- The harness's shell tool runs *inside* the container: expect its tooling
  (git, python3, ripgrep), not the host's.
- Bump with `DEEPSEEK_VERSION` → `DSH_VERSION=0.1.5-rc.1 docker compose build`.

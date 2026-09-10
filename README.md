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
  -p 8483:8080 \
  -e DEEPSEEK_API_KEY=sk-... \
  -e DSH_TRUSTED_HOSTS=138.26.48.197:8483 \
  -v dsh-home:/home/dsh/.dsh \
  -v dsh-work:/workspace \
  dsh-web
```

## Why there is a bridge in the entrypoint

`dsh web --host 0.0.0.0` is refused on purpose:

```
error: --host 0.0.0.0 is intentionally not supported yet for safety:
it would expose remote code execution to the network; use 127.0.0.1 instead
```

So the harness always binds loopback, and a published Docker port (which DNATs
to the container's `eth0`) can never reach it directly. `entrypoint.sh` starts
the harness on `127.0.0.1:3080` and runs `socat` on `0.0.0.0:8080` forwarding to
it. The exposure is therefore an explicit operator decision in front of the
harness, not a bypassed guard — but the effect is the same, so treat anything
behind that published port as remote code execution you have deliberately
opened. The gate is the harness's own token URL plus cookie session (see below),
host-bound to the authority it is served under.

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

`dsh web` fences the UI behind a per-process token. On boot it prints

```
dsh web: http://127.0.0.1:3080/?token=...
```

Open that URL **under the authority you reach the container by** — the token
exchange writes a cookie bound to that hostname and port, e.g. on a server
published at `8483`:

```
http://<server>:8483/?token=<the token from the logs>
```

The session lives in the `dsh-home` volume, so later boots don't ask again.
Any `/api` request whose `Host` is neither loopback nor a declared
`DSH_TRUSTED_HOSTS` authority gets a 403 before authentication.

## Configuration

| Env | Default | Meaning |
|---|---|---|
| `DEEPSEEK_API_KEY` | — | required; LLM credential |
| `DEEPSEEK_BASE_URL` | `https://api.deepseek.com` | LLM endpoint |
| `DSH_HOME` | `/home/dsh/.dsh` | harness home |
| `DSH_TRUSTED_HOSTS` | empty | comma/space separated authorities the browser-trust fence accepts (e.g. `138.26.48.197:8483`); loopback is always accepted |
| `DSH_LISTEN_PORT` | `3080` | loopback port the harness binds |
| `GATEWAY_PORT` | `8080` | published port served by the bridge |
| `DSH_VERSION` (build arg) | `0.1.2-rc.1` | pinned `@deepseek-ai/dsh` version |

## Coolify

Deployed from this repo as a **Dockerfile** build pack with:

- port mapping `8483:8080` (`ports_mappings`), container port `8080` (`ports_exposes`)
- `DEEPSEEK_API_KEY`, `DSH_HOME`, `DEEPSEEK_BASE_URL`, `DSH_TRUSTED_HOSTS=138.26.48.197:8483` as app environment variables
- persistent storage wired through custom docker run options:
  `--volume dsh-home:/home/dsh/.dsh --volume dsh-workspace:/workspace`
  (the API of this Coolify build exposes no storage endpoint; a redeploy that
  drops this option also drops sessions and credentials)

The UI's health is not exposed over HTTP without a session, so Coolify's HTTP
health check stays disabled and the container relies on the harness staying up.

## Notes

- The container user is uid/gid 501 (matches macOS hosts; irrelevant on Linux
  where only image-owned paths are written).
- On a host, publish to loopback (`-p 127.0.0.1:3080:8080`) unless the port is
  deliberately exposed; the compose file does exactly that.
- The harness's shell tool runs *inside* the container: expect its tooling
  (git, python3, ripgrep), not the host's.
- Bump with `DSH_VERSION=0.1.5-rc.1 docker compose build && docker compose up -d`.

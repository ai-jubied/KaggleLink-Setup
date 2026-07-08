# kagglelink

SSH and VS Code Remote access to Kaggle notebook instances, tunneled securely through [zrok](https://zrok.io).

## Overview

kagglelink turns a Kaggle notebook session into a remote development machine. It installs and configures an SSH server on the Kaggle instance, then publishes it through a private zrok tunnel so you can connect with plain `ssh`, VS Code Remote-SSH, or `rsync` — with Kaggle's GPUs and environment intact.

**Highlights**

- One-line setup pasted into a Kaggle cell
- Tunnel runs in the **background** — your notebook cell is released after setup
- **Auto-restart supervisor**: the tunnel recovers if it drops
- **Stable access token**: a reserved zrok share means the same `zrok access` command works across session restarts
- `kagglelink-status` health-check command on the instance
- Kaggle environment variables (CUDA paths, etc.) carried into SSH sessions

## Requirements

1. A zrok account token. Create an account at [myzrok.io](https://myzrok.io/) (Starter plan works with NetFoundry's public zrok instance).
2. Your SSH **public** key hosted at a URL Kaggle can reach (a public GitHub repo raw URL works).
3. A Kaggle notebook with **internet access enabled** (Notebook settings → Internet → On).

## Quick Setup

### 1. Create an SSH key (once, on your local machine)

```bash
ssh-keygen -t ed25519 -C "kaggle_remote_ssh" -f ~/.ssh/kaggle_rsa
```

Host the **`.pub`** file somewhere public — e.g. push `~/.ssh/kaggle_rsa.pub` to a public GitHub repo and copy the **Raw** URL (`https://raw.githubusercontent.com/<user>/<repo>/main/kaggle_rsa.pub`). Never publish the private key.

> Tip: GitHub already serves all your account's public keys at `https://github.com/<username>.keys` — you can use that URL directly and skip the repo.

### 2. Run the setup in a Kaggle cell

```bash
!curl -sS https://raw.githubusercontent.com/ai-jubied/KaggleLink-Setup/main/setup.sh | bash -s -- -k <public_key_url> -t <zrok_token>
```

When it finishes it prints the command to run on your local machine, e.g.:

```
zrok access private kagglelink
```

The cell is released once setup completes — the tunnel keeps running in the background and restarts automatically if it drops.

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-k, --keys-url` | URL to your authorized_keys / public key file | *(required)* |
| `-t, --token` | zrok account token | *(required)* |
| `-r, --repo` | Repository to clone (use your fork) | this repo |
| `-b, --branch` | Branch to clone | `main` |
| `-p, --port` | SSH port on the instance | `22` |
| `-z, --zrok-version` | Pin a zrok version (e.g. `v2.0.4`) | `latest` |
| `-n, --share-name` | Reserved share name / access token | `kagglelink` |
| `-s, --shell` | Preferred shell (`bash`, `zsh`) | `bash` |
| `-F, --foreground` | Run the tunnel in the foreground (blocks the cell) | off |
| `-f, --force` | Force a fresh clone of the repo | off |
| `-v, --verbose` | Verbose output | off |

> **Version match:** the zrok version on the Kaggle side and your local machine should be the same major version. Pin with `-z` if needed.

## Client Setup (local machine)

1. [Install zrok](https://docs.zrok.io/docs/guides/install/) (Arch: `yay -S zrok-bin`).
2. Enable it once with your account token:

   ```bash
   zrok enable <zrok_account_token>
   ```

3. Open the tunnel using the token printed by the Kaggle setup:

   ```bash
   zrok access private kagglelink
   ```

   This binds a local address such as `127.0.0.1:9191`.

4. SSH in:

   ```bash
   ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/kaggle_rsa -p 9191 root@127.0.0.1
   ```

Or do steps 3–4 in one go with the helper script:

```bash
./connect.sh            # uses share 'kagglelink', port 9191, key ~/.ssh/kaggle_rsa
./connect.sh mytoken 9292 ~/.ssh/other_key
```

### SSH config (recommended)

Add to `~/.ssh/config`, then connect with just `ssh Kaggle` (also makes VS Code Remote-SSH show a "Kaggle" host):

```
Host Kaggle
    HostName 127.0.0.1
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
    IdentityFile ~/.ssh/kaggle_rsa
    Port 9191
    User root
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

## VS Code

1. Install the **Remote-SSH** extension locally.
2. With the tunnel open, connect to host `Kaggle` (or `root@127.0.0.1:9191`).
3. Inside the remote session, run `install_extensions` in the terminal to install a curated extension set (Python, Jupyter, GitLens, …).

## File Transfer

```bash
# Local -> Kaggle
rsync -avP -e "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/kaggle_rsa -p 9191" <local_path> root@127.0.0.1:/kaggle/working/

# Kaggle -> local
rsync -avP -e "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/kaggle_rsa -p 9191" root@127.0.0.1:<remote_path> <local_path>
```

## On-instance tools

| Command | Purpose |
|---------|---------|
| `kagglelink-status` | Health check: sshd, zrok enablement, tunnel, auto-restart, access token |
| `install_extensions` | Install the curated VS Code extension set |
| `tail -f /var/log/kagglelink/zrok.log` | Watch the tunnel log |

## Troubleshooting

- **`zrok enable` fails / environment limit reached** — the Starter plan allows a limited number of environments. Release stale ones from your zrok dashboard, or run `zrok disable` on the Kaggle instance before the session ends.
- **Tunnel dies when the notebook goes idle** — Kaggle stops idle sessions; keep the browser tab active or use Kaggle's "persistence" options. The supervisor only survives while the session itself is alive.
- **Reserved share creation fails** — the setup falls back to an ephemeral share automatically; the access token is then printed from the log and changes on each restart.
- **Permission denied (publickey)** — confirm your keys URL serves the raw public key (open it in a browser) and that you're using the matching private key with `-i`.

## Testing

Run the Docker-based test harness locally:

```bash
export AUTH_KEYS_URL="<your_keys_url>"
export ZROK_TOKEN="<your_token>"
make test
```

CI runs ShellCheck and a Docker build on every push.

## License

Apache License 2.0 — see [LICENSE](LICENSE).

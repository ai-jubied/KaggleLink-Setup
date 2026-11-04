# KaggleLink: The Complete Step-by-Step Guide

This guide walks you through connecting your local computer to a Kaggle GPU/TPU notebook instance using **KaggleLink**.

---

## Quick Reference (Your Personalized Values)

| Item | Value |
| :--- | :--- |
| **Your Public Key** | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHHYtphBWAlnjHEqYkN9Rq1atILz1Ltu/beWG2+WISzv kaggle_remote_ssh` |
| **Your Private Key** | `~/.ssh/kaggle_rsa` |
| **Your zrok Token** | `W6ar2oeKpPSw` |
| **Default Tunnel Name** | `kagglelink` |
| **Local Port** | `9191` |

---

## Part 1: Start the Session on Kaggle

### Step 1.1: Configure Your Kaggle Notebook
1. Open or create a Kaggle notebook.
2. In the right-hand sidebar (**Notebook settings**):
   - **Internet:** Turn **ON** (Required to download packages and open tunnel).
   - **Accelerator:** Choose **GPU T4 x2**, **GPU P100**, or **CPU** depending on your workload.

### Step 1.2: Run the Setup Command
Paste this single command into a code cell and click **Run**:

```bash
!curl -sS https://raw.githubusercontent.com/ai-jubied/KaggleLink-Setup/main/setup.sh | bash -s -- -f -K "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHHYtphBWAlnjHEqYkN9Rq1atILz1Ltu/beWG2+WISzv kaggle_remote_ssh" -t W6ar2oeKpPSw -F
```

#### What each flag does:
- **`-f` (force fresh)**: Ensures a clean download of the latest KaggleLink scripts.
- **`-K "<key>"`**: Injects your SSH public key directly into `/root/.ssh/authorized_keys`.
- **`-t "<token>"`**: Authenticates with your zrok account.
- **`-F` (foreground)**: Keeps the cell actively running and streaming logs. This prevents Kaggle from shutting down your notebook due to inactivity.

### Step 1.3: Verify Output
When setup succeeds, you will see output ending with:
```text
Reserved share 'kagglelink' created.
Starting zrok share in the foreground on port 22...
Tunnel running in the foreground - stop the cell to end it.
```
> **Important:** Leave this notebook cell running while you work. If you stop the cell, the tunnel will close.

---

## Part 2: Connect from Your Mac

You can connect in any of the following ways:

### Method A: Desktop VS Code (Recommended)

1. **Open the tunnel on your Mac:**
   Open a terminal window and run:
   ```bash
   cd "/Users/emon/0. Jubied/1. Work/ComfyHelper/Development/Kaggle-Link"
   ./connect.sh -t
   ```
   You will see:
   ```text
   ========================================================
   ✅ Tunnel is active on 127.0.0.1:9191!
   ========================================================
   You can now connect via VS Code Remote - SSH:
     Host: kaggle (or root@127.0.0.1:9191)
   ```
   *(Keep this terminal window open while you work in VS Code)*.

2. **Connect in VS Code:**
   - In VS Code, install the official **Remote - SSH** extension (`ms-vscode-remote.remote-ssh`) if not already installed.
   - Press <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd> (or <kbd>F1</kbd>).
   - Select **Remote-SSH: Connect to Host...**
   - Click **`kaggle`**.
   - A new VS Code window will open connected to Kaggle.

3. **Open the Workspace:**
   - In the new VS Code window, go to **File → Open Folder...**
   - Select `/kaggle/working`.
   - Open a terminal inside VS Code (<kbd>Ctrl</kbd> + <kbd>`</kbd>). Run `nvidia-smi` to verify GPU access!

---

### Method B: Terminal SSH

If you just need a bash prompt inside Kaggle:

1. Open your Mac terminal:
   ```bash
   cd "/Users/emon/0. Jubied/1. Work/ComfyHelper/Development/Kaggle-Link"
   ./connect.sh
   ```
2. The script opens the tunnel and drops you directly into `root@kaggle:~#`.
3. When you are done, simply type `exit`. The tunnel will shut down automatically.

---

### Method C: In-Browser VS Code (`code-server`)

If you are away from your main computer and want full VS Code inside Chrome/Safari with zero local setup:

1. In your Kaggle cell, add the **`-c`** flag:
   ```bash
   !curl -sS https://raw.githubusercontent.com/ai-jubied/KaggleLink-Setup/main/setup.sh | bash -s -- -f -K "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHHYtphBWAlnjHEqYkN9Rq1atILz1Ltu/beWG2+WISzv kaggle_remote_ssh" -t W6ar2oeKpPSw -c -F
   ```
2. The script will output a public URL and password:
   ```text
   Browser VS Code (code-server):
       URL:      https://xxxxxxxx.share.zrok.io
       Password: a1b2c3d4e5f6...
   ```
3. Open the URL in any browser, enter the password, and you have VS Code running on Kaggle!

---

## Part 3: Transferring Files Between Mac & Kaggle

Use `rsync` over the active tunnel (while `./connect.sh -t` is running):

### Send files from Mac to Kaggle:
```bash
rsync -avP -e "ssh -p 9191 -i ~/.ssh/kaggle_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
  /path/to/local/file.safetensors root@127.0.0.1:/kaggle/working/
```

### Download files from Kaggle to Mac:
```bash
rsync -avP -e "ssh -p 9191 -i ~/.ssh/kaggle_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
  root@127.0.0.1:/kaggle/working/output.png ~/Desktop/
```

---

## Part 4: Keeping Kaggle Alive (Avoiding Timeouts)

Kaggle has two session types:

### 1. Interactive Sessions (Up to 12 hours)
- Kaggle checks for browser activity. If a notebook appears idle for ~40–60 minutes, Kaggle asks *"Are you still there?"* and stops the VM.
- **Solution:** Always run with the **`-F`** flag. The running cell keeps the session classified as active.

### 2. Background "Commit" Runs (Up to 9 hours - Most Robust)
If you are doing a long training run or rendering job:
1. In the notebook editor, click **Save Version**.
2. Select **Save & Run All (Commit)**.
3. Because the last cell runs with `-F`, it stays running in the background.
4. You can close your browser tab completely! The container will keep running for up to 9 hours.

---

## Part 5: On-Instance Helper Tools

Once you are connected to Kaggle via SSH or VS Code terminal, you have these helper commands:

| Command | Description |
| :--- | :--- |
| `kagglelink-status` | Checks status of SSH daemon, zrok tunnel, and supervisors |
| `install_extensions` | Automatically installs popular VS Code extensions (Python, Jupyter, C++, GitLens) |
| `nvidia-smi` | Shows GPU status and VRAM usage |

---

## Part 6: Troubleshooting

- **Issue: `[ERROR]: unable to create private access ([POST /access][401] accessUnauthorized)`**
  - **Cause:** The local computer's cached zrok identity in `~/.zrok/` is expired or out of sync with the zrok controller.
  - **Fix:** Refresh your local zrok identity by running in your Mac terminal:
    ```bash
    zrok disable
    zrok enable W6ar2oeKpPSw
    ```

- **Issue: `sshd: no hostkeys available -- exiting`**
  - **Cause:** Fresh Kaggle containers don't have default SSH host keys pre-generated.
  - **Fix:** KaggleLink now automatically generates them (`ssh-keygen -A`). If Kaggle ever shows this, add `-f` to your Kaggle cell command to force the latest script version.

- **Issue: `zrok enable failed / environment limit reached`**
  - **Cause:** Free zrok accounts allow up to 3-5 active environments. If you start many fresh Kaggle notebooks without disabling previous ones, old environments linger.
  - **Fix:** Go to [myzrok.io](https://myzrok.io/), open the web console, and delete any old / dead environments.

- **Issue: Local port 9191 is already occupied**
  - **Cause:** A previous `./connect.sh` or `zrok access` process didn't terminate.
  - **Fix:** `./connect.sh` now automatically cleans up stale listeners on port 9191. You can also manually run:
    ```bash
    pkill -f "zrok access private"
    ```

- **Issue: `Host key verification failed`**
  - **Cause:** Kaggle creates a brand new container with a new host key every time.
  - **Fix:** Your `~/.ssh/config` is configured with `StrictHostKeyChecking no` and `UserKnownHostsFile /dev/null` specifically to prevent this error.

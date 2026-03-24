# microWakeWord Trainer (CLI / RunPod)

Train **microWakeWord** detection models from the command line on **RunPod GPU pods**.

No custom Docker image. No Jupyter notebooks. Just clone, set up, and train.

---

## RunPod Setup (Step by Step)

### Step 1: Create a RunPod Account

Go to [runpod.io](https://www.runpod.io/) and create an account. Add credits or connect a payment method.

### Step 2: Create a Network Volume

Datasets and models need persistent storage (~100GB). Without a network volume, everything is lost when the pod stops.

1. In the RunPod dashboard, go to **Storage**
2. Click **+ Network Volume**
3. Set the size to **100 GB** (or more)
4. Pick a datacenter region (remember which one — your pod must be in the same region)
5. Name it something like `mww-data`
6. Click **Create**

### Step 3: Deploy a GPU Pod

1. Go to **Pods** → **+ Deploy**
2. Choose a GPU — any NVIDIA GPU works (RTX 3090, RTX 4090, A40, etc.)
3. Under **Template**, pick **RunPod Pytorch 2.4.0** (or any stock template with Python 3 and CUDA)
4. Under **Volume**, attach your network volume from Step 2 and set the mount path to `/data`
5. **(Optional)** Under **Environment Variables**, add these for auto-pushing models to GitHub:
   - `GITHUB_TOKEN` = your GitHub personal access token (see [GitHub Integration](#github-integration))
   - `GITHUB_REPO` = `owner/repo` (e.g., `myuser/my-wakewords`)
6. Click **Deploy**

### Step 4: Connect via SSH or Web Terminal

Once the pod shows **Running**:

- **Web Terminal**: Click **Connect** → **Start Web Terminal** → **Connect to Web Terminal**
- **SSH**: Click **Connect**, copy the SSH command, and run it in your local terminal:
  ```bash
  ssh root@<pod-ip> -p <port> -i ~/.ssh/id_rsa
  ```

### Step 5: Clone This Repo

```bash
git clone https://github.com/BigPappy098/microWakeWord-Trainer-Nvidia-Docker.git /root/mww-scripts
```

This puts all the training scripts into `/root/mww-scripts/`.

### Step 6: Set Up Your Shell

Copy the custom `.bashrc` which adds the scripts to your PATH and sets up the environment:

```bash
cp /root/mww-scripts/.bashrc ~/.bashrc
source ~/.bashrc
```

You should see the **microWakeWord Trainer** welcome message with available commands.

### Step 7: Run Setup (First Time Only)

```bash
setup
```

This does two things:
1. **Creates the Python virtual environment** — installs TensorFlow, PyTorch, and all training dependencies into `/data/.venv`
2. **Downloads training datasets** — background noise, speech corpora, room impulse responses (~50GB)

This takes a while on the first run (30-60+ minutes depending on network speed). Everything is cached on your network volume at `/data`, so it **persists across pod restarts**. You only run this once.

### Step 8: Train a Wake Word

```bash
train_wake_word "hey jarvis"
```

That's it! The training pipeline will:
1. **Generate** synthetic voice samples using TTS
2. **Augment** samples with background noise, room effects, pitch shifts, etc.
3. **Train** a neural network (TensorFlow)
4. **Output** a quantized `.tflite` model + `.json` metadata
5. **Push to GitHub** (if configured)

Your trained model will be in `/data/output/`.

---

## When You Come Back Later

If you stop your pod and restart it later (or create a new pod with the same network volume), you just need to re-clone and source:

```bash
git clone https://github.com/BigPappy098/microWakeWord-Trainer-Nvidia-Docker.git /root/mww-scripts
cp /root/mww-scripts/.bashrc ~/.bashrc
source ~/.bashrc
```

The heavy stuff (Python venv + datasets) is already on your network volume. You can go straight to training:

```bash
train_wake_word "hey jarvis"
```

---

## Training Options

```bash
train_wake_word [options] <wake_word> [<wake_word_title>]

Options:
  --samples=<N>           Number of TTS samples to generate (default: 50000)
  --batch-size=<N>        Samples per generation batch (default: 100)
  --training-steps=<N>    Training iterations (default: 40000)
  --language=<lang>       TTS language: "en", "nl", etc. (default: en)
  --cleanup-work-dir      Delete intermediate files after training
```

Examples:
```bash
# Quick test run (smaller sample/step count)
train_wake_word --samples=1000 --training-steps=500 "hey jarvis"

# Full training with custom title
train_wake_word --samples=50000 --training-steps=40000 "hey jarvis" "Hey Jarvis"

# Dutch wake word
train_wake_word --language=nl "hallo computer"
```

---

## Output Files

After training, your model files are saved to:

```
/data/output/<timestamp>-<wake_word>-<samples>-<steps>/
  <wake_word>.tflite    # Quantized model for microcontrollers
  <wake_word>.json      # ESPHome-compatible metadata
  logs/                 # Training logs and TensorBoard data
```

The `.tflite` file is what you flash to your ESP32 or other device via ESPHome.

---

## Personal Voice Samples (Optional)

Recording your own voice improves accuracy. Since there's no microphone on RunPod, record `.wav` files on your local machine and upload them.

### Requirements
- 16kHz sample rate
- WAV format (PCM 16-bit)
- One wake word utterance per file

### Upload to RunPod

```bash
# From your local machine:
scp -P <port> speaker01_take*.wav root@<pod-ip>:/data/personal_samples/
```

### File naming convention

```
/data/personal_samples/
  speaker01_take01.wav
  speaker01_take02.wav
  speaker02_take01.wav
  ...
```

Personal samples are automatically detected and given **3x sampling weight** during training — no extra configuration needed.

---

## GitHub Integration

Automatically push trained model files to a GitHub repository after training completes.

### Create a GitHub Token

1. Go to [GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)](https://github.com/settings/tokens)
2. Click **Generate new token (classic)**
3. Give it a name like `mww-trainer`
4. Select the `repo` scope
5. Copy the token

### Set Environment Variables

You can set these in RunPod's pod **Environment Variables** (so they persist across restarts), or export them in your SSH session:

```bash
export GITHUB_TOKEN=ghp_your_token_here
export GITHUB_REPO=yourusername/your-wakewords-repo
```

| Variable | Required | Default | Description |
|---|---|---|---|
| `GITHUB_TOKEN` | Yes | — | GitHub Personal Access Token with `repo` scope |
| `GITHUB_REPO` | Yes | — | Target repo in `owner/repo` format |
| `GITHUB_BRANCH` | No | `main` | Branch to push to |
| `GITHUB_PATH` | No | `.` | Directory within the repo for model files |
| `GITHUB_COMMIT_MSG` | No | Auto-generated | Custom commit message |

After training completes, the `.tflite` and `.json` files are automatically committed and pushed. If the env vars aren't set, this step is silently skipped.

---

## Other Useful Commands

```bash
setup                    # Run full setup (venv + datasets)
setup_python_venv        # Set up just the Python environment
setup_training_datasets  # Download just the training datasets
cudainfo                 # Show GPU information
system_summary           # Show system stats (CPU, RAM, disk, GPU)
nvidia-smi               # NVIDIA GPU status
```

---

## Re-training and Multiple Wake Words

- Train **multiple wake words** back-to-back — no cleanup needed between runs
- Each run creates a **new timestamped output directory**
- Old models are preserved
- Intermediate work files in `/data/work/` are reused when possible

---

## Resetting Everything

To start completely fresh, delete the data volume contents:

```bash
rm -rf /data/*
```

Then run `setup` again. This removes cached datasets, the Python venv, and all trained models.

---

## Storage Requirements

| Directory | Purpose | Size |
|---|---|---|
| `/data/.venv/` | Python environment | ~5 GB |
| `/data/training_datasets/` | Audio corpora | ~40 GB |
| `/data/tools/` | Git clones + TTS models | ~3 GB |
| `/data/work/` | Temporary training artifacts | ~10 GB |
| `/data/output/` | Trained models | ~10 MB per model |
| **Total** | | **~60 GB minimum** |

A **100 GB network volume** is recommended for comfortable headroom.

---

## Credits

Built on top of [microWakeWord](https://github.com/kahrendt/microWakeWord) by Kevin Ahrendt.

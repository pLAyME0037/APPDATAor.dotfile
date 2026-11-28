# Running Colibri MoE LLMs on Arch Linux (Asus 16 GB RAM + GTX 1060 Mobile)

## System Specs & Environment
```sh
hostnamectl

## Output ##
#   Static hostname: archlinux
#         Icon name: computer-laptop
#           Chassis: laptop 💻
#  Operating System: Arch Linux
#            Kernel: Linux 7.3.4-arch1-2
#      Architecture: x86-64
#   Hardware Vendor: ASUSTeK COMPUTER INC.
#    Hardware Model: GL502VML
#      Hardware SKU: ASUS-NotebookSKU
#  Hardware Version: 1.0
#  Firmware Version: GL502VML.306
#     Firmware Date: Mon 2019-04-29
#      Firmware Age: 7y 6month 2w 5d

lspci -nn | /usr/bin/grep -E "VGA|3D|Audio"

## Output ##
# 00:1f.3 Audio device [0403]: Intel Corporation 100/C230 Series Chipset Family HD Audio [8086:a170] (rev 31)
# 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP106M [GeForce GTX 1060 Mobile] [10de:1c20] (rev a1)
# 01:00.1 Audio device [0403]: NVIDIA Corporation GP106 High Definition Audio Controller [10de:10f1] (rev a1)
```

## Step 1: Hardware & Driver Audit
```sh
uname -r
lspci -k -d ::03xx
lsblk -d -o NAME,ROTA,TRAN,SIZE,MODEL
df -h
free -h
command -v vulkaninfo >/dev/null && vulkaninfo --summary || echo "vulkaninfo not installed"
nvidia-smi 2>/dev/null || echo "nvidia-smi unavailable"

#--------#
# Output #
#--------#
# 7.3.5-arch1-1
# 01:00.0 VGA compatible controller: NVIDIA Corporation GP106M [GeForce GTX 1060 Mobile] (rev a1)
# 	Subsystem: ASUSTeK Computer Inc. Device 16d0
# 	Kernel driver in use: nvidia
# 	Kernel modules: nouveau, nvidia_drm, nvidia
# NAME  ROTA TRAN     SIZE MODEL
# sda      0 sata   238.5G MTFDDAV256TBN
# sdb      1 sata   931.5G HGST HTS721010A9E630
# zram0    0          7.8G
# Filesystem      Size  Used Avail Use% Mounted on
# dev             7.6G     0  7.6G   0% /dev
# run             7.8G  1.6M  7.8G   1% /run
# efivarfs        128K   65K   59K  53% /sys/firmware/efi/efivars
# /dev/sda2        59G   44G   13G  79% /
# tmpfs           7.8G  968K  7.8G   1% /dev/shm
# none            1.0M     0  1.0M   0% /run/credentials/systemd-journald.service
# tmpfs           7.8G   62M  7.8G   1% /tmp
# /dev/sda7       175G   66G  101G  40% /home
# /dev/sda1       511M  376M  136M  74% /boot
# /dev/sdb2       437G  200G  236G  46% /mnt/disk3
# /dev/sdb1       424G  260G  143G  65% /mnt/disk2
# none            1.0M  4.0K 1020K   1% /run/credentials/libvirtd.service
# tmpfs           1.6G  464K  1.6G   1% /run/user/1000
#                total        used        free      shared  buff/cache   available
# Mem:            15Gi       3.1Gi       8.0Gi       134Mi       4.9Gi        12Gi
# Swap:          7.8Gi          0B       7.8Gi
# vulkaninfo not installed
# Fri Nov 27 13:03:06 2026
# +-----------------------------------------------------------------------------------------+
# | NVIDIA-SMI 580.196.07             Driver Version: 580.196.07     CUDA Version: 13.0     |
# +-----------------------------------------+------------------------+----------------------+
# | GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
# | Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
# |                                         |                        |               MIG M. |
# |=========================================+========================+======================|
# |   0  NVIDIA GeForce GTX 1060        Off |   00000000:01:00.0  On |                  N/A |
# | N/A   51C    P8             10W /   78W |     305MiB /   3072MiB |     15%      Default |
# |                                         |                        |                  N/A |
# +-----------------------------------------+------------------------+----------------------+
# 
# +-----------------------------------------------------------------------------------------+
# | Processes:                                                                              |
# |  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
# |        ID   ID                                                               Usage      |
# |=========================================================================================|
# |    0   N/A  N/A            1065      G   Hyprland                                 55MiB |
# |    0   N/A  N/A            1098      G   quickshell                                7MiB |
# |    0   N/A  N/A            1134      G   kitty                                    85MiB |
# |    0   N/A  N/A            1142      G   Xwayland                                  1MiB |
# |    0   N/A  N/A          133023    C+G   ...rack-uuid=3190708988185955192         81MiB |
# +-----------------------------------------------------------------------------------------+
```

### Step 1 Findings
- **GPU & Driver:** NVIDIA GeForce GTX 1060 Mobile (`3072 MiB` VRAM, ~2.7 GiB
  free under Hyprland) running `nvidia` driver `580.196.07` (CUDA 13.0). No
  driver downgrade/AUR work needed.
- **Memory:** 15 GiB RAM (12 GiB available) + 7.8 GiB `zram0`.
- **Storage Layout:**
  - **`/dev/sda` (`MTFDDAV256TBN`, 238.5G SATA SSD, `ROTA=0`):**
    `/` has 13G free; `/home` (`/dev/sda7`) has **101G free**. All Colibri files and
    models must go in `/home`.
  - **`/dev/sdb` (`HGST HTS721010A9E630`, 931.5G HDD, `ROTA=1`):**
    `/mnt/disk2` and `/mnt/disk3`. Unusable for streamed MoE weights due to slow
    random I/O.
- **Missing Tooling:** `vulkaninfo` is not installed yet.

## Step 2: Dependencies & GPU Setup
```sh
sudo pacman -S --needed base-devel git python vulkan-icd-loader vulkan-tools vulkan-headers shaderc
vulkaninfo --summary

#--------#
# Output #
#--------#
# ==========
# VULKANINFO
# ==========
# 
# Vulkan Instance Version: 1.4.363
# 
# 
# Instance Extensions: count = 27
# -------------------------------
# VK_EXT_acquire_drm_display             : extension revision 1
# VK_EXT_acquire_xlib_display            : extension revision 1
# VK_EXT_debug_report                    : extension revision 10
# VK_EXT_debug_utils                     : extension revision 2
# VK_EXT_direct_mode_display             : extension revision 1
# VK_EXT_display_surface_counter         : extension revision 1
# VK_EXT_headless_surface                : extension revision 1
# VK_EXT_layer_settings                  : extension revision 2
# VK_EXT_surface_maintenance1            : extension revision 1
# VK_EXT_swapchain_colorspace            : extension revision 5
# VK_KHR_device_group_creation           : extension revision 1
# VK_KHR_display                         : extension revision 23
# VK_KHR_external_fence_capabilities     : extension revision 1
# VK_KHR_external_memory_capabilities    : extension revision 1
# VK_KHR_external_semaphore_capabilities : extension revision 1
# VK_KHR_get_display_properties2         : extension revision 1
# VK_KHR_get_physical_device_properties2 : extension revision 2
# VK_KHR_get_surface_capabilities2       : extension revision 1
# VK_KHR_portability_enumeration         : extension revision 1
# VK_KHR_surface                         : extension revision 25
# VK_KHR_surface_maintenance1            : extension revision 1
# VK_KHR_surface_protected_capabilities  : extension revision 1
# VK_KHR_wayland_surface                 : extension revision 6
# VK_KHR_xcb_surface                     : extension revision 6
# VK_KHR_xlib_surface                    : extension revision 6
# VK_LUNARG_direct_driver_loading        : extension revision 1
# VK_NV_display_stereo                   : extension revision 1
# 
# Instance Layers: count = 3
# --------------------------
# VK_LAYER_MESA_device_select Linux device selection layer 1.4.303  version 1
# VK_LAYER_NV_optimus         NVIDIA Optimus layer         1.4.312  version 1
# VK_LAYER_NV_present         NVIDIA GR2608 layer          1.4.312  version 1
# 
# Devices:
# ========
# GPU0:
# 	apiVersion         = 1.4.312
# 	driverVersion      = 580.196.7.0
# 	vendorID           = 0x10de
# 	deviceID           = 0x1c20
# 	deviceType         = PHYSICAL_DEVICE_TYPE_DISCRETE_GPU
# 	deviceName         = NVIDIA GeForce GTX 1060
# 	driverID           = DRIVER_ID_NVIDIA_PROPRIETARY
# 	driverName         = NVIDIA
# 	driverInfo         = 580.196.07
# 	conformanceVersion = 1.4.1.3
# 	deviceUUID         = 45e1433b-ac4c-4607-b9e6-c0a6b137b864
# 	driverUUID         = 75d4e284-3c58-509f-9ec3-29f8fc7eb00a
```

### Step 2 Findings
- Installed `base-devel`, `git`, `python`, `vulkan-icd-loader`, `vulkan-tools`,
  `vulkan-headers`, and `shaderc`.
- `vulkaninfo --summary` confirmed `NVIDIA GeForce GTX 1060` (`0x10de:0x1c20`)
  active on `Vulkan 1.4.312` (`DRIVER_ID_NVIDIA_PROPRIETARY` `580.196.07`).

## Step 3: Clone & Inspect Colibri
```sh
cd ~/github
git clone https://github.com/JustVugg/colibri.git
cd colibri
./start-here.sh --list


#--------#
# Output #
#--------#
# Cloning into 'colibri'...
# remote: Enumerating objects: 41984, done.
# remote: Total 41984 (delta 0), reused 0 (delta 0), pack-reused 41984 (from 1)
# Receiving objects: 100% (41984/41984), 58.76 MiB | 1.00 MiB/s, done.
# Resolving deltas: 100% (32194/32194), done.
# colibri setup
# 
#  * inkling2-mini-iq2                9 GB  ~7.5 tok/s Vulkan    every weight in RAM (9 of 13 GB), the CPU
#    qwen36-35b                      23 GB  ~2.16 tok/s Vulkan   the dense part and 10 GB of experts in RAM, the rest from the disk
#    inkling2-mini                   18 GB  ~1.73 tok/s Vulkan   the dense part and 11 GB of experts in RAM, the rest from the disk
#    qwen3-coder-30b                 19 GB  ~1.94 tok/s Vulkan   the dense part and 11 GB of experts in RAM, the rest from the disk
#    qwen38-flash-next-iq2xs         80 GB  ~0.94 tok/s Vulkan   the dense part and 4 GB of experts in RAM, the rest from the disk
#    qwen38-flash-next-iq3           88 GB  ~0.81 tok/s Vulkan   the dense part and 4 GB of experts in RAM, the rest from the disk
#    deepseek-v4-flash-reap          85 GB  ~0.16 tok/s Vulkan   the dense part and 5 GB of experts in RAM, the rest from the disk
#    qwen-image-2.1-turbo            32 GB  tight                runs with a small expert cache (needs 12 GB, runs best with 18 GB)
#    qwen-image-2.1                  33 GB  tight                runs with a small expert cache (needs 12 GB, runs best with 18 GB)
#    deepseek-v4-flash              167 GB  needs-disk           needs 172 GB free for the download; 108 GB free there
#    mimo-v2.6-flash                172 GB  needs-ram            needs 32 GB of RAM (dense part 24 GB plus the expert cache); this machine has 16.7 GB
#    qwen38-flash-next              186 GB  needs-ram            needs 24 GB of RAM (dense part 8 GB plus the expert cache); this machine has 16.7 GB
#    glm-5.3                        419 GB  needs-disk           needs 430 GB free for the download; 108 GB free there
#    glm-5.2                        429 GB  needs-disk           needs 440 GB free for the download; 108 GB free there
#    inkling                        514 GB  needs-ram            needs 120 GB of RAM (dense part 49.4 GB plus the expert cache); this machine has 16.7 GB
#    mimo-v2.6-pro                  564 GB  needs-ram            needs 54 GB of RAM (dense part 32.4 GB plus the expert cache); this machine has 16.7 GB
#    kimi-k3                       1561 GB  needs-ram            needs 32 GB of RAM (dense part 20 GB plus the expert cache); this machine has 16.7 GB
#    kimi-k3.1-pro                 1561 GB  needs-ram            needs 32 GB of RAM (dense part 20.2 GB plus the expert cache); this machine has 16.7 GB
```

### Step 3 Findings
- Cloned `JustVugg/colibri` into `~/Projects/github/colibri`.
- `./start-here.sh --list` detected `Vulkan` support and `108 GB` free space in
  the default model path (`~/colibri-models` on `/dev/sda7`).
- **RAM-only option:** `inkling2-mini-iq2` (9 GB, ~7.5 tok/s Vulkan, recommended `*`).
- **Balanced disk-streaming options:** `qwen36-35b` (23 GB, ~2.16 tok/s),
  `qwen3-coder-30b` (19 GB, ~1.94 tok/s), and `inkling2-mini` (18 GB, ~1.73 tok/s).
- **Tight 100B+ class options:** `qwen38-flash-next-iq2xs` (80 GB, ~0.94 tok/s)
  and `deepseek-v4-flash-reap` (85 GB, ~0.16 tok/s).
- **Blocked:** `deepseek-v4-flash` (167 GB), `glm-5.2` (429 GB), and `glm-5.3`
  (419 GB) fail on disk space; 172 GB–1.5 TB models fail on 16.7 GB RAM.

## Step 4: Model Selection & Download
- **Chosen Model:** `qwen36-35b` (Qwen3.6-35B-A3B)
- **Backend:** Vulkan (`NVIDIA GeForce GTX 1060`)
- **Model Path:** `~/colibri-models` (`/dev/sda7` SATA SSD)
- **Command Run:**
```sh
./start-here.sh --yes --model <model-id> --backend vulkan

e.g.
./start-here.sh --yes --model qwen36-35b --backend vulkan
```

### Commands to Run After Setup Finishes
Once `start-here.sh` completes (and prints the `http://127.0.0.1:8000/` URL or
prompt), run these read-only checks in a second terminal inside
`~/Projects/github/colibri` (do not run a second model server while port 8000 is
active):

```bash
du -sh ~/colibri-models/qwen36-35b
./c/coli doctor --model ~/colibri-models/qwen36-35b
./c/coli plan --model ~/colibri-models/qwen36-35b
pgrep -af coli || echo "no coli process running"


#--------#
# Output #
#--------#
# 22G	/home/playme/colibri-models/qwen36-35b
# colibri doctor · /home/playme/colibri-models/qwen36-35b
# [  ok] model.path         model directory is readable
# [  ok] model.config       config.json is valid
# [  ok] model.family       Qwen3.6-35B-A3B family is registered
# [  ok] model.tokenizer    tokenizer.json found
# [  ok] storage.persistence model directory can store usage and KV state
# [  ok] engine.binary      engine executable is ready
# [  ok] accelerator.gpu    Vulkan engine; the loader is installed (COLI_VULKAN=1 runs the expert tier and the dense chain on the GPU)
# [  ok] model.shards       safetensors headers are valid
# [  ok] storage.disk       model backing store is available
# [fail] memory.ram         RAM budget cannot hold one expert slot per sparse layer
# [warn] placement.plan     RAM budget cannot hold one expert slot per sparse layer; cold expert misses may reach disk; normal decode speed depends on hit rate
# [skip] storage.ssd_probe  no cached probe yet; measured on the first Metal+darwin engine start
# 
# policy quality · quality-preserving yes
# model  41 shards · 23.0 GB
# disk   18.1 GB cold experts · 84.9 GB free
# RAM    1.4 GB budget · 4.0 GB dense · 4.0 GB runtime · 0.0 GB warm experts · cap 0/layer
# VRAM   Vulkan · NVIDIA GeForce GTX 1060 (discrete) · the expert tier and the dense chain size themselves from its free memory at start
# limit  disk expert misses
# hit    0% projected expert residency
# 
# next actions:
#   [required] measure-storage: cold experts remain on disk and no trusted storage probe is available; from a source checkout, replace <model-shard> with an existing model weight file of at least 38 MiB on the model drive
#     make -C c iobench && ./c/iobench "<model-shard>" 19 64 8 1
#   [recommended] measure-residency: projected expert residency is 0%
#     coli tune --model <model>
# warn   RAM budget cannot hold one expert slot per sparse layer
# warn   cold expert misses may reach disk; normal decode speed depends on hit rate
# 
# result error
# 
#      ▄▀▀▀▄  ▄        colibri v2.2.0
#   ▄▄▄▄▀▀▀▀▄▀▀        tiny engine, immense model
#       ▀▀▀▀▀▀▀        Qwen3.6-35B-A3B · 35B MoE · 23 GB on disk
#         ▀▀▀▀         plan · Disk / RAM / VRAM
#           ▀
#   ──────────────────────────────────────────────────────────
#   policy quality · quality-preserving yes
#   model  41 shards · 23.0 GB
#   disk   18.1 GB cold experts · 84.9 GB free
#   RAM    1.4 GB budget · 2.0 GB dense · 4.0 GB runtime · 0.0 GB warm experts · cap 0/layer
#   VRAM   0.0 GB hot tier · ~0 experts · 0:NVIDIA GeForce GTX 1060
#   limit  disk expert misses
#   hit    0% projected expert residency
# 
#   next actions:
#     [required] measure-storage: cold experts remain on disk and no trusted storage probe is available; from a source checkout, replace <model-shard> with an existing model weight file of at least 38 MiB on the model drive
#       make -C c iobench && ./c/iobench "<model-shard>" 19 64 8 1
#     [recommended] measure-residency: projected expert residency is 0%
#       coli tune --model <model>
#   warn   RAM budget cannot hold one expert slot per sparse layer
#   warn   2.5 GB of VRAM is already in use (only 0.7 GB of 3.2 GB free): this plan plans against the remainder. Stop the running engine for a representative plan.
#   warn   cold expert misses may reach disk; normal decode speed depends on hit rate
# 
# 861708 python3 /home/playme/github/colibri/c/coli setup --yes --model qwen36-35b --backend vulkan
# 920004 /usr/bin/python3 /home/playme/github/colibri/c/coli web --model /home/playme/colibri-models/qwen36-35b --host 127.0.0.1 --port 8000 --auto-tier
# 920012 /usr/bin/python3 /home/playme/github/colibri/ui/server.py --host 127.0.0.1 --port 8790 --backend http://127.0.0.1:8000 --exit-with-stdin
# 920072 /home/playme/github/colibri/c/qwen36 66
```

### Step 4 Findings
- Downloaded `qwen36-35b` (`Qwen3.6-35B-A3B`, 41 shards, 23.0 GB catalog / 22G
  actual `du -sh`) into `/home/playme/colibri-models/qwen36-35b`, leaving
  80G–84.9 GB free on `/dev/sda7`.
- `start-here.sh` automatically started the inference stack:
  - `coli web` on `http://127.0.0.1:8000` (OpenAI-compatible API)
  - `ui/server.py` on `http://127.0.0.1:8790` (browser chat UI)
  - `c/qwen36` engine process (`PID 920072`)
- `coli doctor` and `coli plan` flagged low remaining RAM/VRAM only because
  `c/qwen36` was already loaded in memory when those checks ran.

## Step 5: First Inference & Benchmark Results
Before stopping the running engine, inspect its live RAM/VRAM footprint, startup
logs, and run one timed API test against

> `http://127.0.0.1:8000/v1/chat/completions`
> (you can also open http://127.0.0.1:8790 in a browser)

```sh
free -h
nvidia-smi
./c/coli logs -n 40
time curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen36-35b","messages":[{"role":"user","content":"Reply with one short sentence: what is Mixture of Experts?"}],"max_tokens":128}'


#--------#
# Output #
#--------#
#                total        used        free      shared  buff/cache   available
# Mem:            15Gi        14Gi       581Mi        82Mi       1.3Gi       1.5Gi
# Swap:          7.8Gi       667Mi       7.1Gi
# Fri Nov 27 14:43:09 2026
# +-----------------------------------------------------------------------------------------+
# | NVIDIA-SMI 580.196.07             Driver Version: 580.196.07     CUDA Version: 13.0     |
# +-----------------------------------------+------------------------+----------------------+
# | GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
# | Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
# |                                         |                        |               MIG M. |
# |=========================================+========================+======================|
# |   0  NVIDIA GeForce GTX 1060        Off |   00000000:01:00.0  On |                  N/A |
# | N/A   54C    P8             10W /   78W |    2348MiB /   3072MiB |      0%      Default |
# |                                         |                        |                  N/A |
# +-----------------------------------------+------------------------+----------------------+
# 
# +-----------------------------------------------------------------------------------------+
# | Processes:                                                                              |
# |  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
# |        ID   ID                                                               Usage      |
# |=========================================================================================|
# |    0   N/A  N/A            1065      G   Hyprland                                 55MiB |
# |    0   N/A  N/A            1098      G   quickshell                                7MiB |
# |    0   N/A  N/A            1134      G   kitty                                    85MiB |
# |    0   N/A  N/A            1142      G   Xwayland                                  1MiB |
# |    0   N/A  N/A          133023    C+G   ...rack-uuid=3190708988185955192         84MiB |
# |    0   N/A  N/A          920072    C+G   ...layme/github/colibri/c/qwen36       2036MiB |
# +-----------------------------------------------------------------------------------------+
# 
# --- start 2026-11-27 14:09:39 in the foreground (pid 920004): /usr/bin/python3 /home/playme/github/colibri/c/coli web --model /home/playme/colibri-models/qwen36-35b --host 127.0.0.1 --port 8000 --auto-tier
# --- its output goes to the terminal that started it, not to this log; `coli start --background` writes it here
# {"error":{"message":"The model `qwen36-35b` does not exist.","type":"invalid_request_error","param":"model","code":"model_not_found"}}
# real	0m0.041s
# user	0m0.004s
# sys	0m0.006s
```

- *run test:*
```sh
curl -s http://127.0.0.1:8000/v1/models
MODEL_ID=$(curl -s http://127.0.0.1:8000/v1/models | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])")
echo "Using model id: $MODEL_ID"
time curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"$MODEL_ID\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with one short sentence: what is Mixture of Experts?\"}],\"max_tokens\":256}"

#--------#
# Output #
#--------#
# {"object":"list","data":[{"id":"qwen3.6-colibri","object":"model","created":1795763380,"owned_by":"colibri","input_modalities":["text"],"capabilities":["chat","systemone"],"context_length":65536,"max_model_len":65536}],"models":[{"name":"qwen3.6-colibri","description":"Qwen3.6-35B-A3B, served by colibri; POST /v1/systemone answers typed questions.","release_date":"2026-11-27"}]}Using model id: qwen3.6-colibri
# {"id":"chatcmpl-cd5a59b329a44b9fb16e03a331842f8f","object":"chat.completion","created":1795768160,"model":"qwen3.6-colibri","choices":[{"index":0,"message":{"role":"assistant","content":"Mixture of Experts is a machine learning architecture that uses a gating network to dynamically route inputs to specialized sub-models for efficient processing.","refusal":null},"logprobs":null,"finish_reason":"stop"}],"usage":{"prompt_tokens":25,"completion_tokens":27,"total_tokens":52}}
# real	0m24.006s
# user	0m0.004s
# sys	0m0.004s
```

### Step 5 Findings
- **Live Memory Footprint (before query):**
  - System RAM: `14 GiB` used / `15 GiB` total (`1.5 GiB` available, `667 MiB` in `zram0`).
  - GPU VRAM (GTX 1060): `c/qwen36` used `2036 MiB` (`2348 MiB` total / `3072 MiB`).
- **Registered Model ID:** `qwen3.6-colibri` (`Qwen3.6-35B-A3B`,
  `context_length: 65536`, capabilities: `["chat", "systemone"]`).
- **Cold Inference Smoke Test (`POST /v1/chat/completions`):**
  - Prompt: `25` tokens, Completion: `27` tokens, `finish_reason: "stop"`.
  - Wall-clock time: `24.006s` (`~1.12 tok/s` end-to-end on cold first turn).

## Step 6: Agent & SKILL Integration
All LLM math, Vulkan GPU shaders, and SSD weight streaming still run inside the
c/qwen36 C engine on http://127.0.0.1:8000. Python only sends tiny JSON over
localhost and runs local tools.

c/qwen36 generation takes ~10–30 seconds per turn.
Python HTTP + JSON parsing takes 1–3 milliseconds (<0.02% overhead).
Writing the client in C would save ~2 milliseconds out of 25,000 milliseconds.

### Step 6a: Probe Tool Calling Format First
Before writing the agent code, verify how qwen3.6-colibri formats tool_calls
(clean OpenAI JSON vs raw XML tags, and whether thinking runs by default). Run
this tiny probe (~90 prompt tokens, also measures warm speed):

```sh
time curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen3.6-colibri",
    "messages": [{"role": "user", "content": "Check free disk space on /home using the check_disk tool."}],
    "tools": [{
      "type": "function",
      "function": {
        "name": "check_disk",
        "description": "Check free disk space for a mount path.",
        "parameters": {
          "type": "object",
          "properties": {"path": {"type": "string"}},
          "required": ["path"]
        }
      }
    }],
    "tool_choice": "auto",
    "max_tokens": 256
  }'

#--------#
# Output #
#--------#
# {"id":"chatcmpl-f371e52649b044cea9e36cb15cfe37a3","object":"chat.completion","created":1795769624,"model":"qwen3.6-colibri","choices":[{"index":0,"message":{"role":"assistant","content":null,"refusal":null,"tool_calls":[{"id":"call_73634e0e8ca94719b5117fd8","type":"function","function":{"name":"check_disk","arguments":"{\"path\": \"/home\"}"}}]},"logprobs":null,"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":285,"completion_tokens":25,"total_tokens":310}}
# real	2m4.460s
# user	0m0.008s
# sys	0m0.006s
```

### Step 6 Findings
- **Tool-Calling Probe:** Confirmed native OpenAI `tool_calls` JSON support on
  `qwen3.6-colibri` (`285` prompt tokens + `25` completion tokens in `124.46s`).
- **Agent Implementation (`agent.py` + `test_agent.py`):**
  - Python stdlib only (`urllib.request`, `json`, `subprocess`, `shlex`), zero
    external RAM overhead, `300s` HTTP timeout.
  - Security gates: `resolve_safe_path` locks file tools inside `workspace/`
    (blocking `..` traversal, external absolute paths, and symlink escapes);
    `validate_shell_command` enforces `30s` timeout, `12 KB` output cap,
    scrubbed `HOME`, and destructive-command blocking with no `[y/N]` prompt.
  - Unit tests: `4/4` passed in `0.012s`.
- **Live `SKILL.md` Benchmark (`qwen3.6-colibri`):**
  - Prompt 1 (`caveman` skill + `write_file` + `run_shell` for `hello.py`):
    - Round 1 (`load_skill`): `130.81s` (`prompt=606`, `out=27`, `0.21 tok/s`)
    - Round 2 (`write_file`): `113.47s` (`prompt=1588`, `out=55`, `0.48 tok/s`)
    - Round 3 (`run_shell`): `35.60s` (`prompt=1671`, `out=33`, `0.93 tok/s`)
    - Round 4 (final reply `4`): `12.81s` (`prompt=1728`, `out=5`, `0.39 tok/s`)
  - Prompt 2 (`caveman-review` skill + `read_file` on `hello.py`):
    - Round 1 (parallel `load_skill` + `read_file`): `42.62s` (`prompt=588`, `out=54`, `1.27 tok/s`)
    - Round 2 (review output): `87.09s` (`prompt=1372`, `out=29`, `0.33 tok/s`)

- *use agent*
```sh
 colibri.ask "use python3 command to calulate 3.50Ghz compare to the speed of light"
usage: agent.py [-h] [--url URL] [--model MODEL] [--workspace WORKSPACE] [--skills SKILLS] [--max-tokens MAX_TOKENS] [--prompt PROMPT]
agent.py: error: unrecognized arguments: use python3 command to calulate 3.50Ghz compare to the speed of light
```

## Final Notes & Cleanup
- Keep `~/github/colibri` clean by optionally moving `agent.py`,
  `test_agent.py`, `SKILL/`, and `workspace/` to `~/github/colibri-agent/`.
- Start Colibri server manually any time with:
```sh
cd ~/github/colibri && \
COLI_VULKAN=1 ./c/coli web --model ~/colibri-models/qwen36-35b --host 127.0.0.1 --port 8000 --auto-tier
```

```sh
colibri.ask() {
    if [ "$#" -eq 0 ]; then
        printf 'usage: colibri.ask <prompt>\n' >&2
        return 1
    fi

    local host="127.0.0.1"
    local port="8000"
    local base_url="http://${host}:${port}"
    local log_file="/tmp/colibri-web.log"

    if ! curl -sf "${base_url}/v1/models" >/dev/null 2>&1; then
        if ! ss -tln | awk -v addr="${host}:${port}" 'nr > 1 && $4 == addr { found = 1 } end { exit !found }'; then
            (
                cd ~/github/colibri || exit 1
                nohup env coli_vulkan=1 ./c/coli web \
                    --model ~/colibri-models/qwen36-35b \
                    --host "${host}" \
                    --port "${port}" \
                    --auto-tier >"${log_file}" 2>&1 &
            )
        fi

        local wait_s=0
        while ! curl -sf "${base_url}/v1/models" >/dev/null 2>&1; do
            wait_s=$((wait_s + 1))
            if [ "${wait_s}" -ge 120 ]; then
                printf 'colibri server not ready on %s; check %s\n' "${base_url}" "${log_file}" >&2
                return 1
            fi
            sleep 1
        done
    fi

    local ifs=' '
    local prompt="$*"
    python3 ~/github/colibri-agent/agent.py --prompt "use caveman skill. ${prompt}"
}
```


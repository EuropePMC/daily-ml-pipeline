# 🧬 Daily ML Entity Annotation Pipeline – Europe PMC

Production Slurm HPC pipeline for processing Europe PMC abstracts and full-text data using shell orchestration and Python-based NLP components.

---

## 📦 Overview

This repository contains a SLURM-compatible machine learning pipeline that:

* Processes large-scale biomedical text (abstract + full text)
* Runs annotation, tagging, and entity linking
* Supports batch execution on HPC clusters
* Includes monitoring and job control utilities

---

## 🏗️ Project Structure

```
.
├── main-ml-pipeline-v08.sh        # Main pipeline entrypoint
├── backlog_main_pipeline-v01.sh   # Backlog processing
├── create_test_data.sh            # Test data generator
├── check_pipeline_progress.sh     # Monitor jobs
├── cancel_pipeline_jobs.sh        # Cancel jobs
├── job_count_summary.sh           # Job statistics
├── submission_only.sh             # Submission helper
│
├── lib/
│   ├── python_scripts/            # Core ML/NLP logic
│   └── *.sh                       # Supporting scripts
│
├── models/                        # Model files (if used)
├── envs/                          # Environment configs
├── .env_paths                     # Environment variables
```

---

## ⚙️ Requirements

* Linux HPC environment
* SLURM scheduler
* Python 3.x
* Access to shared storage:

  ```
  /hps/software/users/literature/textmining-ml
  ```

---

## 🚀 Running the Pipeline

### Option 1 — Direct execution

```bash
bash main-ml-pipeline-v08.sh
```

---

### Option 2 — SLURM (recommended)

Create `run_pipeline.slurm`:

```bash
#!/bin/bash
#SBATCH --job-name=ml-pipeline
#SBATCH --mem=16G
#SBATCH --time=03:00:00
#SBATCH --output=logs/pipeline.log

cd /hps/software/users/literature/textmining-ml
bash main-ml-pipeline-v08.sh
```

Submit:

```bash
sbatch run_pipeline.slurm
```

---

## 🔍 Monitoring & Control

### Check progress

```bash
bash check_pipeline_progress.sh
```

### Job summary

```bash
bash job_count_summary.sh
```

### Cancel jobs

```bash
bash cancel_pipeline_jobs.sh
```

---

## 🧪 Testing

```bash
bash create_test_data.sh
```

---

## 🔄 Deployment Workflow (GitHub → HPC)

This project uses GitHub Actions for CI/CD.

### Flow:

```
git push
   ↓
GitHub Actions
   ↓
SSH → HPC login node
   ↓
become lit_adm
   ↓
git pull
   ↓
sbatch pipeline
```

---

## ⚙️ CI/CD Setup

### 1. SSH Key

Generate locally:

```bash
ssh-keygen -t ed25519
```

Add:

* Public key → HPC (`~/.ssh/authorized_keys`)
* Private key → GitHub Secrets (`SSH_KEY`)

---

### 2. Required GitHub Secret

| Name    | Description                        |
| ------- | ---------------------------------- |
| SSH_KEY | Private SSH key for cluster access |

---

## ⚠️ Important Notes

* Do NOT run heavy jobs on login nodes
* Always use SLURM for execution
* Ensure scripts are idempotent before automation
* Avoid modifying shared directories without permission

---

## 📜 License

MIT License

---

## 👤 Maintainer

Santosh Tirunagari (Europe PMC)

---


# BRIDGE: Behavioral Risk Indicators Driving Gap Estimations  
### CAT12 → BrainAGE Pipeline & BAG Prediction from Behavioral Features

This repository documents the complete workflow used to estimate **brain age** using the **CAT12 / BrainAGE framework** and to evaluate whether **behavioral measures** can predict Brain Age Gap (BAG).  
It includes preprocessing steps, feature extraction, brain-age modeling, BAG computation, and machine-learning analyses.

---

# 📦 Repository Overview

BRIDGE/
│
├── scripts/ # MATLAB & Python pipelines
├── data/ # (empty in repo) Place your own MRI/feature files here
├── docs/ # Documentation & notes
├── results/ # Output tables, figures (not committed)
└── README.md

# 1️⃣ MRI Preprocessing (using CAT12)

 **SPM12 + CAT12** are used to preprocess T1-weighted MRI scans and this generates the tissue maps required for BrainAGE.

### **1.1 Required data structure**
Each subject folder must contain their raw T1w file:

{Subject_ID}/T1_{Subject_ID}.nii
Example: ABC1001/T1_ABC1001.nii


### **1.2 Generate a subject list file**
From the directory containing all subject folders:

```bash
find "$PWD" -maxdepth 2 -type f -name "T1_*.nii" | sort > subj_list_paths.txt
'
```
Check:
```bash
head subj_list_paths.txt
wc -l subj_list_paths.txt
```

### **1.3 Configure CAT12 in MATLAB**

addpath('/path/to/spm12');
addpath('/path/to/spm12/toolbox/cat12');

macOS users must do this to avoide security errors:
```bash
sudo xattr -r -d com.apple.quarantine "/path/to/spm/toolbox/cat12"
```
### **1.4 CAT12 batch template**

You can use the cat12_batch_template.mat from this repository or use the CAT12 GUI to prepare a batch template:

Enable

    Gray matter → DARTEL export → Affine

    White matter → DARTEL export → Affine

Save as: cat12_batch_template.mat

### **1.5 Run CAT12 preprocessing**

    scripts/run_cat12_batch.m

This script:

    Loads the subject list
    Applies the saved batch template
    Logs processing into cat12_run_log.txt

Inspect outputs for each subject:
```bash
${ID}/mri/
${ID}/report/
${ID}/label/
```
Confirm that rp1 (GM) and rp2 (WM) affine-registered maps are available for all subjects.

# 2️⃣ Organize CAT12 Outputs & Prepare BrainAGE Input Tables

After preprocessing:

### **2.1 Gather rp1/rp2 files**

Use:
```bash
scripts/organize_cat12_output.sh
```
This organizes CAT12 output into two folders: rp1_CAT12.9/  and  rp2_CAT12.9/

### **2.2 Create required tables for BrainAGE**

BrainAGE requires:

    ages.txt (age per subject, one value per line)
    male.txt (optional sex coding)

Use:
```bash
scripts/cat12_BrAge_tables.py
```
These files must be sorted in the same order as rp1/rp2 filenames.

# 3️⃣ Feature Extraction (BA_data2mat)

Using `BA_data2mat.m` script from the official CAT12/BrainAGE GitHub to 
This step:

    Reads rp1/rp2 maps
    Applies smoothing and resampling (4mm / 8mm)
    Produces .mat feature files (e.g., s8rp1_8mm_session1_CAT12.9.mat)

These .mat files contain the matrix Y that BrainAGE uses for prediction.

# 4️⃣ BrainAGE Prediction (GPR Model)

Use the script `run_BA_gpr_ui.m` to estimate the brain age for each subject. 
This script uses the BA_gpr.m from the BrainAGE toolbox.
It loads the .mat feature files. Applies Gaussian Process Regression ensemble models. And outputs predicted brain age and BAG for each subject. 

Brain Age Gap is calculated by:
        
                                BAG = Predicted Brain Age – Chronological Age


BAG > 0 → accelerated brian aging

BAG < 0 → decelerated brain aging

The final output from this step is a table:

                                Subject_ID | Age | Predicted_BrainAge | BAG

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






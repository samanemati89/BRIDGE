#!/usr/bin/env python3
import os, glob, numpy as np, pandas as pd

# Paths - adjust if needed
session1 = "/Users/snemati/Documents/ABC_BrainAge/Data/Images/unprocessed/T1w_organized/session1"
outbase = "/Users/snemati/Documents/ABC_BrainAge/Data/Images/processed/CAT12_BrainAge/BrainAge_input"
rp1_folder = os.path.join(outbase, "rp1_CAT12.9")
ages_csv = "/Users/snemati/Documents/ABC_BrainAge/Data/Images/processed/CAT12_BrainAge/BrainAge_input/ages.csv"  # path to your table (ID,Age,Sex)
tables_dir = os.path.join(outbase, "tables")
os.makedirs(tables_dir, exist_ok=True)

# Read ages CSV (change names if different)
df = pd.read_csv(ages_csv, dtype=str)  # read as strings initially
# normalize column names
cols = [c.strip() for c in df.columns]
df.columns = cols
# Expect columns 'ID', 'Age', 'Male' or 'Sex' (male=1, female=0)
if 'ID' not in df.columns or 'Age' not in df.columns:
    raise SystemExit("ages.csv must contain at least columns 'ID' and 'Age'")

# map ID->age and ID->male
df['ID'] = df['ID'].astype(str).str.strip()
age_map = dict(zip(df['ID'], df['Age'].astype(float)))
male_map = {}
if 'Male' in df.columns:
    male_map = dict(zip(df['ID'], df['Male'].astype(int)))
elif 'Sex' in df.columns:
    # try to map Sex strings to 1/0
    s = df['Sex'].astype(str).str.lower().str.strip()
    male_map = dict(zip(df['ID'], (s == 'male').astype(int)))
else:
    # if male not provided, create zeros (or ask user) -> default 0
    male_map = dict(zip(df['ID'], [0]*len(df)))

# Get ordered subject IDs from rp1 filenames (parent dir names in sorted order)
rp1_files = sorted(glob.glob(os.path.join(rp1_folder, "*")))
if len(rp1_files) == 0:
    raise SystemExit(f"No files found in {rp1_folder}")

ordered_ids = []
for p in rp1_files:
    # parent folder name may be lost since we copied files; derive subject id from filename
    # filenames like rp1T1_1001_affine.nii -> we will extract the numeric or ABC id
    fname = os.path.basename(p)
    # try to extract ABCxxxx pattern
    import re
    m = re.search(r'ABC\d{4}', fname)
    if m:
        sid = m.group(0)
    else:
        # fallback: if filename contains _1001 use that
        m2 = re.search(r'_(\d{3,4})', fname)
        sid = None
        if m2:
            sid = "ABC" + m2.group(1)
        else:
            # last fallback: use filename (without ext)
            sid = os.path.splitext(fname)[0]
    ordered_ids.append(sid)

# Build ages and male lists in this order, error if missing
ages_list = []
male_list = []
missing = []
for sid in ordered_ids:
    if sid in age_map:
        ages_list.append(age_map[sid])
        male_list.append(male_map.get(sid, 0))
    else:
        missing.append(sid)
        ages_list.append(np.nan)
        male_list.append(0)
if missing:
    print("WARNING: the following IDs weren't found in ages.csv; they will be NaN in ages.txt:", missing)

# Save tables: plain whitespace-separated numbers (BrainAGE load will use load())
ages_out = os.path.join(tables_dir, "ages.txt")
male_out = os.path.join(tables_dir, "male.txt")
np.savetxt(ages_out, ages_list, fmt='%.2f')
np.savetxt(male_out, male_list, fmt='%d')

# Also save ordered IDs for inspection
with open(os.path.join(tables_dir, "ordered_ids.txt"), 'w') as f:
    f.write("\n".join(ordered_ids))

print("Wrote:", ages_out, male_out, "ordered IDs saved")

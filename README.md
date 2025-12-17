# BRIDGE (Behavioral Risk Indicators Driving Gap Estimations

This repository collects the code and documentation used to estimate brain age with the CAT12 / BrainAGE pipeline and to analyze whether behavioral measures predict Brain Age Gap (BAG).

## Overview

1. **MRI preprocessing (CAT12)**  
   We preprocessed T1-weighted MRI scans with the CAT12 toolbox (SPM/CAT12). CAT12 produces segmented tissue maps (affinely registered GM/WM maps `rp1` and `rp2`), normalization, and optional smoothing.
   If you have MATLAB, install SPM12 + CAT12 and use the batch code () to run preprocessing.

   **Prepare your data** 
   The structure of data on your computer should be like below:
   ${subject_ID}/T1_${subject_ID}.nii
   example: ABC1001/T1_ABC1001.nii
   
   To create subject_list_paths.txt, cd to the directory contains all your subject folders and use the below code:
   find "$PWD" -maxdepth 2 -type f -name "T1_*.nii" | sort > subj_list_paths.txt
   You can check the first few lines with: head -n 10 subj_list_paths.txt
   To make sure counts match the expected number of subjects: wc -l subj_list_paths.txt

   ** Start preprocessing**
   1. Open MATLAB, add SPM12 and CAT12 to the MATLAB path:
         addpath('/path/to/spm12');
         addpath('/path/to/spm12/toolbox/cat12');
      
      If you are on MAC, open terminal and type the below command to pre-approve all CAT12 binaries via terminal
          # adjust the path to your CAT12 folder
          sudo xattr -r -d com.apple.quarantine "/Users/snemati/Documents/toolbox/spm/toolbox/cat12"

         
   3. Save cat12_batch_template.mat on your own computer.
   4. Open the MATLAB script named "run_cat12_batch". Before running this script, you need to change the first few innitial lines and set the paths based on your computer. 
   5. Watch the log file (cat12_run_log.txt) for progress and errors.
   6. After processing a couple of subjects, inspect the output folders (CAT12 creates mri/, cat_* files, summary reports). Confirm the expected files (DARTEL affine exports) are present before running the whole list.

    After preprocessing for all participants are done, use the bash script `organize_cat12_output` to organize the required output needed for the next steps
   
   If you like to create your own batch template, follow below steps:
   1. Launch CAT12 GUI using cat12 command
   2. In the GUI:
         Set the options exactly as the CAT12 GitHub recommended checklist:
             Enable: Grey matter -> DARTEL export -> Affine
             Enable: White matter -> DARTEL export -> Affine
             Disable surface/thickness estimation if you don’t want that.
   3. Instead of running, use the GUI to save the batch (there is a "Save" or "Save batch" button). Save it as cat12_batch_template.mat in the path you want.
   4. Close GUI. Open cat12_batch_template.mat in MATLAB workspace to confirm it contains matlabbatch.
   

2. **Feature extraction**  
   We converted the CAT12 segmentations into MATLAB feature matrices using `BA_data2mat` (CAT12 BrainAGE helper). These matrices contain voxelwise/voxel-aggregated features at a standardized spatial resolution suitable for the BrainAGE model.
  
3. **BrainAGE prediction (GPR)**  
   Predicted brain age was estimated using the BrainAGE toolbox (GPR implementation: `BA_gpr.m`) developed by the Structural Brain Mapping Group (Christian Gaser). The toolbox accepts the extracted feature matrices and returns predicted brain age for each subject.

4. **Brain Age Gap (BAG)**  
   BAG is computed as:

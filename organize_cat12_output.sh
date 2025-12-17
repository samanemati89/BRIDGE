cd /Users/snemati/Documents/ABC_BrainAge/Data/Images/unprocessed/T1w_organized/session1  # set the path to your subject folders on your computer

# set variables
CATVER="CAT12.9"   # change if different
OUTDIR="../BrainAGE_input"   # sibling folder where we'll assemble inputs
mkdir -p "$OUTDIR"/rp1_"$CATVER"
mkdir -p "$OUTDIR"/rp2_"$CATVER"
mkdir -p "$OUTDIR"/tables


cases=$(echo $(ls | grep "ABC*")); 

for c in ${cases}; do
	cp ${c}/mri/rp1*_affine.nii ../BrainAGE_input/rp
	rp1_CAT12.9/ rp2_CAT12.9/ 
	cp ${c}/mri/rp1*_affine.nii ../BrainAGE_input/rp1_CAT12.9/
	cp ${c}/mri/rp2*_affine.nii ../BrainAGE_input/rp2_CAT12.9/
done

# Show counts
echo "rp1 count:" $(ls -1 "$OUTDIR"/rp1_"$CATVER" | wc -l)
echo "rp2 count:" $(ls -1 "$OUTDIR"/rp2_"$CATVER" | wc -l)

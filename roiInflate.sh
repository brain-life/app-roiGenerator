#!/bin/bash
##
## Inflate ROIs limiting artifacts that can occlude the white-matter tissue within the gyri.
##
## This script uses AFNI's (Taylor PA, Saad ZS (2013).  
## - FATCAT: (An Efficient) Functional And Tractographic Connectivity Analysis Toolbox. Brain Connectivity 3(5):523-535. https://afni.nimh.nih.gov/) 
## - 3dROIMaker function to 
##    a) remove the white matter mask from the cortical segmentation inputted (i.e. freesurfer or parcellation, BE CAREFUL: REMOVES SUBCORTICAL ROIS) and 
##    b) inflate the ROIs by n voxels into the white matter based on user input (option for no inflation is also built in). 
##
## The output of this will then passed into a matlab function (roiGeneration.m) to create nifti's for each ROI requested by the user, which can then be fed into a ROI to ROI tracking app (brainlife.io; www.github.com/brain-life/
## app-roi2roitracking).

INFLATE=`jq -r '.inflate' config.json`
#t1=`jq -r '.t1' config.json`
dtiinit=`jq -r '.dtiinit' config.json`
brainmask=${dtiinit}/dti/bin/brainMask.nii.gz;
mkdir parc
#cp $t1 ${PWD}/parc/t1.nii.gz

if [[ ${INFLATE} == 'null' ]]; then
	echo "no inflation";
	l2='-prefix parc_inflate';
else
	echo "${INFLATE} voxel inflation applied to every cortical label in parcellation";
	l2="-inflate ${INFLATE} -prefix parc_inflate";
fi

## Inflate ROI
if [ -f parc_diffusion.nii.gz ]; then
	3dROIMaker \
		-inset parc_diffusion.nii.gz \
		-refset parc_diffusion.nii.gz \
		-mask ${brainmask} \
		-wm_skel wm_anat.nii.gz \
		-skel_thr 0.5 \
		-skel_stop \
		-trim_off_wm \
		${l2} \
		-nifti \
		-overwrite;
else
	3dROIMaker \
		-inset aparc+aseg.nii.gz \
		-refset aparc+aseg.nii.gz \
		-mask ${brainmask} \
		-wm_skel wm_anat.nii.gz \
		-skel_thr 0.5 \
		-skel_stop \
		-trim_off_wm \
		${l2} \
		-nifti \
		-overwrite;
fi


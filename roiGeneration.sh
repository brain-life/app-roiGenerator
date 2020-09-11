#!/bin/bash

set -x

## This script uses AFNI's (Taylor PA, Saad ZS (2013).  FATCAT: (An Efficient) Functional And Tractographic Connectivity Analysis Toolbox. Brain 
## Connectivity 3(5):523-535. https://afni.nimh.nih.gov/) 3dROIMaker function to a) remove the white matter mask from the cortical segmentation 
## inputted (i.e. freesurfer or parcellation; BE CAREFUL: REMOVES SUBCORTICAL ROIS) and b) inflates the ROIs by n voxels into the white matter 
## based on user input (option for no inflation is also built in). The output of this will then passed into a matlab function (roiGeneration.m) to 
## create nifti's for each ROI requested by the user, which can then be fed into a ROI to ROI tracking app (brainlife.io; www.github.com/brain-life/
## app-roi2roitracking).

# bl config inputs
inputparc=`jq -r '.inputparc' config.json`
thalamusinflate=`jq -r '.thalamusInflate' config.json`
# visInflate=`jq -r '.visInflate' config.json`
freesurferInflate=`jq -r '.freesurferInflate' config.json`
#subcorticalROIs=`jq -r '.subcorticalROIs' config.json`

# hard coded roi numbers for optic radiation tracking
brainmask=mask.nii.gz;
freesurferROIs="41 42 7 8 4 2 3 46 47 43 28 60"
subcorticalROIs="85"
thalamicROIs="8109 8209"
mergeROIsL="41 42 7 8 4 28"
mergeROIsR="2 3 46 47 43 60"
mergeL=($mergeROIsL)
mergeR=($mergeROIsR)
mergename="exclusion"

# parse inflation if desired by user
if [[ ${freesurferInflate} == 'null' ]]; then
        echo "no freesurfer inflation";
        l5="-prefix ${inputparc}+aseg_inflate";
else
        echo "${fsurfInflate} voxel inflation applied to every freesurfer label";
        l5="-inflate ${fsurfInflate} -prefix ${inputparc}+aseg_inflate";
fi

if [[ ${thalamusinflate} == 'null' ]]; then
	echo "no thalamic inflation";
	l3="-prefix thalamus_inflate";
else
	echo "${thalamusinflate} voxel inflation applied to every thalamic label";
	l3="-inflate ${thalamusinflate} -prefix thalamus_inflate";
fi

# if [[ ${visInflate} == 'null' ]]; then
#         echo "no visual area inflation";
#         l4="-prefix visarea_inflate";
# else
#         echo "${visInflate} voxel inflation applied to every visual area label";
#         l4="-inflate ${visInflate} -prefix visarea_inflate";
# fi

# stop inflation into white matter
l1="-skel_stop";

## Inflate freesurfer ROIs
if [[ -z ${freesurferROIs} ]]; then
	echo "no freesurfer inflation"
else
	3dROIMaker \
                -inset ${inputparc}+aseg.nii.gz \
                -refset ${inputparc}+aseg.nii.gz \
                -mask ${brainmask} \
                -wm_skel wm_anat.nii.gz \
                -skel_thr 0.5 \
                ${l1} \
                ${l5} \
                -nifti \
                -overwrite;
	
	#generate rois
        FREEROIS=`echo ${freesurferROIs} | cut -d',' --output-delimiter=$'\n' -f1-`
        for FREE in ${FREEROIS}
        do
                3dcalc -a ${inputparc}+aseg_inflate_GMI.nii.gz -expr 'equals(a,'${FREE}')' -prefix ROI0000${FREE}.nii.gz
        done

fi

# inflate thalamus
if [[ -z ${thalamicROIs} ]]; then
	echo "no thalamic nuclei segmentation"
else
	3dROIMaker \
		-inset thalamicNuclei.nii.gz \
		-refset thalamicNuclei.nii.gz \
		-mask ${brainmask} \
		-wm_skel wm_anat.nii.gz \
		-skel_thr 0.5 \
		${l1} \
		${l3} \
		-nifti \
		-overwrite;

	#generate rois
        THALROIS=`echo ${thalamicROIs} | cut -d',' --output-delimiter=$'\n' -f1-`
        for THAL in ${THALROIS}
        do
                3dcalc -a thalamus_inflate_GMI.nii.gz -expr 'equals(a,'${THAL}')' -prefix ROI00${THAL}.nii.gz
        done
fi

# # inflate visual areas
# if [[ -z ${visROIs} ]]; then
#         echo "no visual area inflation"
# else
#         3dROIMaker \
#                 -inset parc_dwi.nii.gz \
#                 -refset parc_dwi.nii.gz \
#                 -mask ${brainmask} \
#                 -wm_skel wm_anat.nii.gz \
#                 -skel_thr 0.5 \
#                 ${l1} \
#                 ${l4} \
#                 -nifti \
#                 -overwrite;

# 	#generate rois
# 	VISROIS=`echo ${visROIs} | cut -d',' --output-delimiter=$'\n' -f1-`
#         for VIS in ${VISROIS}
#         do
#                 3dcalc -a visarea_inflate_GMI.nii.gz -expr 'equals(a,'${VIS}')' -prefix ROI000${VIS}.nii.gz
#         done
# fi

if [[ -z ${subcorticalROIs} ]]; then
        echo "no subcortical rois"
else
        #generate rois
        SUBROIS=`echo ${subcorticalROIs} | cut -d',' --output-delimiter=$'\n' -f1-`
        for SUB in ${SUBROIS}
        do
                3dcalc -a ${inputparc}+aseg.nii.gz -expr 'equals(a,'${SUB}')' -prefix ROI0${SUB}.nii.gz
        done
fi

# create parcellation of all rois
3dcalc -a ${inputparc}+aseg.nii.gz -prefix zeroDataset.nii.gz -expr '0'
3dTcat -prefix all_pre.nii.gz zeroDataset.nii.gz *ROI*.nii.gz
3dTstat -argmax -prefix allroiss.nii.gz all_pre.nii.gz
3dcalc -byte -a allroiss.nii.gz -expr 'a' -prefix allrois_byte.nii.gz

if [[ -z ${mergeROIsL} ]] || [[ -z ${mergeROIsR} ]]; then
        echo "no merging of rois"
else
        #merge rois
	if [[ ! -z ${mergeROIsL} ]]; then
		mergeArrayL=""
		for i in "${mergeL[@]}"
		do
			mergeArrayL="$mergeArrayL `echo ROI*0"$i".nii.gz`"
		done
		
		3dTcat -prefix merge_preL.nii.gz zeroDataset.nii.gz `ls ${mergeArrayL}`
        	3dTstat -argmax -prefix ${mergename}L_nonbyte.nii.gz merge_preL.nii.gz
        	3dcalc -byte -a ${mergename}L_nonbyte.nii.gz -expr 'a' -prefix ${mergename}L_allbytes.nii.gz
        	3dcalc -a ${mergename}L_allbytes.nii.gz -expr 'step(a)' -prefix ROI${mergename}_L.nii.gz
	fi
	if [[ ! -z ${mergeROIsR} ]]; then
		mergeArrayR=""
		for i in "${mergeR[@]}"
		do
			mergeArrayR="$mergeArrayR `echo ROI*0"$i".nii.gz`"
		done
                3dTcat -prefix merge_preR.nii.gz zeroDataset.nii.gz `ls ${mergeArrayR}`
                3dTstat -argmax -prefix ${mergename}R_nonbyte.nii.gz merge_preR.nii.gz
                3dcalc -byte -a ${mergename}R_nonbyte.nii.gz -expr 'a' -prefix ${mergename}R_allbytes.nii.gz
                3dcalc -a ${mergename}R_allbytes.nii.gz -expr 'step(a)' -prefix ROI${mergename}_R.nii.gz
	fi
fi

# create key.txt for parcellation
FILES=(`echo "*ROI*.nii.gz"`)
for i in "${!FILES[@]}"
do
	oldval=`echo "${FILES[$i]}" | sed 's/.*ROI\(.*\).nii.gz/\1/'`
	newval=$((i + 1))
	echo "${oldval} -> ${newval}" >> key.txt
done

# clean up
mkdir parc;
mkdir rois;
mkdir rois/rois;
mv allrois_byte.nii.gz ./parc/parc.nii.gz;
mv key.txt ./parc/key.txt;
mv *ROI*.nii.gz ./rois/rois/;
mv ./rois/rois/ROI008109.nii.gz ./rois/rois/ROIlgn_L.nii.gz
mv ./rois/rois/ROI008209.nii.gz ./rois/rois/ROIlgn_R.nii.gz
mv ./rois/rois/ROI085.nii.gz ./rois/rois/ROIoptic-chiasm.nii.gz
rm -rf *.niml.*
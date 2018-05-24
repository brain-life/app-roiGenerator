#!/bin/bash
module load matlab/2017a

mkdir -p ROI

cat > build.m <<END
addpath(genpath('/N/u/brlife/git/vistasoft'))
addpath(genpath('/N/u/brlife/git/encode'))
addpath(genpath('/N/u/brlife/git/jsonlab'))
addpath(genpath('/N/u/brlife/git/spm'))
mcc -m -R -nodisplay -d ROI roiGeneration
exit
END
matlab -nodisplay -nosplash -r build

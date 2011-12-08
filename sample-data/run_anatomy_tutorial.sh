#!/usr/bin/env bash

if [ $# -ne 1 ] ; then
    echo "Usage: $0 <sample data directory>"
    exit 1
fi

MNE_sample=$1

cd ${MNE_sample}/subjects && export SUBJECTS_DIR=`pwd`
cd -
cd ${MNE_sample}/MEG/sample && export MEG_DIR=`pwd`
cd -

export SUBJECT=sample

# Compute BEM model using Flash sequences
# assumes mef05.mgz and mef30.mgz are in the mri/flash folder
mne_flash_bem --noconvert

# The BEM surfaces should now be the bem/flash folder
cd ${SUBJECTS_DIR}/sample/bem
ln -s flash/inner_skull.surf .
ln -s flash/outer_skin.surf .
ln -s flash/outer_skull.surf .

# MRI (this is not really needed for anything)
# mne_setup_mri --overwrite

# Make high resolution head surface
mkheadsurf -s sample
mne_surf2bem --surf ${SUBJECTS_DIR}/sample/surf/lh.seghead --id 4 --check --fif ${SUBJECTS_DIR}/sample/bem/sample-head.fif

# Generate morph maps for morphing between sample and fsaverage
mne_make_morph_maps --from sample --to fsaverage

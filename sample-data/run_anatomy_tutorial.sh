#!/usr/bin/env bash

if [ $# -ne 1 ] ; then
    echo "Usage: $0 <sample data directory>"
    exit 1
fi

MNE_sample=$1
export SUBJECT=sample

cd ${MNE_sample}/subjects && export SUBJECTS_DIR=`pwd`
cd -
cd ${MNE_sample}/MEG/${SUBJECT} && export MEG_DIR=`pwd`
cd -

# Compute BEM model using Flash sequences
# assumes mef05.mgz and mef30.mgz are in the mri/flash folder
mne_flash_bem --noconvert

# The BEM surfaces should now be the bem/flash folder
cd ${SUBJECTS_DIR}/${SUBJECT}/bem
ln -s flash/inner_skull.surf .
ln -s flash/outer_skin.surf .
ln -s flash/outer_skull.surf .

# MRI (this is not really needed for anything)
# mne_setup_mri --overwrite

# Make high resolution head surface
mkheadsurf -s ${SUBJECT}
mne_surf2bem --surf ${SUBJECTS_DIR}/${SUBJECT}/surf/lh.seghead --id 4 --check --fif ${SUBJECTS_DIR}/${SUBJECT}/bem/${SUBJECT}-head.fif

# Generate morph maps for morphing between sample and fsaverage
mne_make_morph_maps --from ${SUBJECT} --to fsaverage

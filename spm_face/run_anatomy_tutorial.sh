#!/usr/bin/env bash

if [ $# -ne 1 ] ; then
    echo "Usage: $0 <sample data directory>"
    exit 1
fi

MNE_sample=$1
export SUBJECT=spm_smri

cd ${MNE_sample}/subjects && export SUBJECTS_DIR=`pwd`
cd -

# without FLASH images use
cd ${SUBJECTS_DIR}/${SUBJECT}/bem
mne_watershed_bem
ln -s watershed/${SUBJECT}_inner_skull_surface ${SUBJECT}-inner_skull.surf
ln -s watershed/${SUBJECT}_outer_skin_surface ${SUBJECT}-outer_skin.surf
ln -s watershed/${SUBJECT}_outer_skull_surface ${SUBJECT}-outer_skull.surf

# MRI (this is not really needed for anything)
# mne_setup_mri --overwrite

# Make high resolution head surface
mkheadsurf -s ${SUBJECT}
mne_surf2bem --surf ${SUBJECTS_DIR}/${SUBJECT}/surf/lh.seghead --id 4 --check --fif ${SUBJECTS_DIR}/${SUBJECT}/bem/${SUBJECT}-head.fif
# if the previous command fails you can use the --force option.

# Generate morph maps for morphing between sample and fsaverage
mne_make_morph_maps --from ${SUBJECT} --to fsaverage
mne_make_morph_maps --from ${SUBJECT} --to ${SUBJECT}
mne_make_morph_maps --from fsaverage --to fsaverage

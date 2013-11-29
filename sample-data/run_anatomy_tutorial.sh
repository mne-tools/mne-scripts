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

# without FLASH images you should use
# mne_watershed_bem
# ln -s watershed/${SUBJECT}_inner_skull_surface ${SUBJECT}-inner_skull.surf
# ln -s watershed/${SUBJECT}_outer_skin_surface ${SUBJECT}-outer_skin.surf
# ln -s watershed/${SUBJECT}_outer_skull_surface ${SUBJECT}-outer_skull.surf

# Make high resolution head surface
head=${SUBJECTS_DIR}/${SUBJECT}/bem/${SUBJECT}-head.fif
if [ -e $head ]; then
	echo deleting existing head surface ${head}
	rm -f $head
fi

mne make_scalp_surfaces -s ${SUBJECT} -o
echo linking ${head_medium} as main head surface
head_medium=${SUBJECTS_DIR}/${SUBJECT}/bem/${SUBJECT}-head-medium.fif
ln -s $head_medium $head  # on failure use --force option.

# Generate morph maps for morphing between sample and fsaverage
mne_make_morph_maps --from ${SUBJECT} --to fsaverage
mne_make_morph_maps --from ${SUBJECT} --to ${SUBJECT}
mne_make_morph_maps --from fsaverage --to fsaverage

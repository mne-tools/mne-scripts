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

# MRI (this is not really needed for anything)
# mne_setup_mri --overwrite

# Make high resolution head surface
head=${SUBJECTS_DIR}/${SUBJECT}/bem/${SUBJECT}-head.fif
if [ -e $head ]; then
	printf '\ndeleting existing head surface %s\n' $head
	rm -f $head
fi

# XXX declare MNE_PYTHON install path in your .bashrc or before running this script.
if [ ! "$MNE_PYTHON" ]; then
	echo "\nMNE_PYTHON not set. Using fallback strategy without decimating head surfaces.\n"
	mkheadsurf -s ${SUBJECT}
	mne_surf2bem --surf ${SUBJECTS_DIR}/${SUBJECT}/surf/lh.seghead --id 4 --check --fif $head
else
	# XXX new alternative to MATLAB based mne_make_scalp_surfaces
	${MNE_PYTHON}/bin/mne make_scalp_surfaces -s ${SUBJECT} -o
	head_medium=${SUBJECTS_DIR}/${SUBJECT}/bem/${SUBJECT}-head-medium.fif
	printf '\nlinking %s as main head surface\n' $head_medium
	ln -s $head_medium $head
fi
# if the previous command fails you can use the --force option.

# Generate morph maps for morphing between sample and fsaverage
mne_make_morph_maps --from ${SUBJECT} --to fsaverage
mne_make_morph_maps --from ${SUBJECT} --to ${SUBJECT}
mne_make_morph_maps --from fsaverage --to fsaverage

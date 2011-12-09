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

# Source space
mne_setup_source_space --ico -6 --overwrite

# Prepare for forward computation
mne_setup_forward_model --homog --surf --ico 4
mne_setup_forward_model --surf --ico 4

cd $MEG_DIR

# Need a bad channel file

echo 'MEG 2443' > sample_bads.bad
echo 'EEG 053' >> sample_bads.bad

mne_mark_bad_channels --bad sample_bads.bad sample_audvis_raw.fif

# Filter initial raw data and save decimated raw file.
mne_process_raw --raw sample_audvis_raw.fif --lowpass 40 \
        --save sample_audvis_filt-0-40.fif --projoff --decim 4

# Generate events
mne_process_raw --raw sample_audvis_raw.fif \
        --eventsout sample_audvis_raw-eve.fif
mne_process_raw --raw sample_audvis_filt-0-40_raw.fif \
        --eventsout sample_audvis_filt-0-40_raw-eve.fif

# Averaging
mne_process_raw --raw sample_audvis_raw.fif --lowpass 40 --projon \
        --saveavetag -ave --ave audvis.ave

# Averaging with no filter
mne_process_raw --raw sample_audvis_raw.fif --filteroff --projon \
        --saveavetag -no-filter-ave --ave audvis.ave

# Compute the noise covariance matrix
mne_process_raw --raw sample_audvis_raw.fif --lowpass 40 --projon \
        --savecovtag -cov --cov audvis.cov

###############################################################################
# Compute forward solution a.k.a. lead field

# for MEG only
mne_do_forward_solution --mindist 5 --spacing oct-6 \
        --meas sample_audvis_raw.fif --bem sample-5120 --megonly --overwrite \
        --fwd sample_audvis-meg-oct-6-fwd.fif

# for EEG only
mne_do_forward_solution --mindist 5 --spacing oct-6 \
        --meas sample_audvis_raw.fif --bem sample-5120-5120-5120 --eegonly \
        --fwd sample_audvis-eeg-oct-6-fwd.fif

# add for EEG only info on cortical points
mne_add_patch_info --src sample_audvis-eeg-oct-6-fwd.fif \
        --srcp sample_audvis-eeg-oct-6p-fwd.fif

# for both EEG and MEG
mne_do_forward_solution --mindist 5 --spacing oct-6 \
        --meas sample_audvis_raw.fif --bem sample-5120-5120-5120 \
        --fwd sample_audvis-meg-eeg-oct-6-fwd.fif

# Look at SSPs sensitivity maps
mne_sensitivity_map --fwd sample_audvis-meg-oct-6-fwd.fif --map 1 \
        --w sample_audvis-meg-oct-6-fwd-sensmap

# Generate transformation matrices
mne_collect_transforms --meas ${MEG_DIR}/sample_audvis_raw.fif \
    --mri ${MEG_DIR}/sample_audvis_raw-trans.fif --out ${MEG_DIR}/all-trans.fif

###############################################################################
# Compute MNE inverse operators
#
# Note: The MEG/EEG forward solution could be used for all
#
mne_do_inverse_operator --fwd sample_audvis-meg-oct-6-fwd.fif \
        --depth --loose 0.2 --meg

mne_do_inverse_operator --fwd sample_audvis-eeg-oct-6-fwd.fif \
        --depth --loose 0.2 --eeg

mne_do_inverse_operator --fwd sample_audvis-meg-eeg-oct-6-fwd.fif \
        --depth --loose 0.2 --eeg --meg

# Produce stc files

mods="meg eeg meg-eeg"

for mod in $mods ; do

mne_make_movie --inv sample_audvis-${mod}-oct-6-${mod}-inv.fif \
    --meas sample_audvis-ave.fif \
    --tmin 0 --tmax 250 --tstep 10 --spm \
    --smooth 5 --bmin -100 --bmax 0 --stc sample_audvis-${mod}

done

exit 0

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

# Store the current version of the sample data
echo "0.8.git" >> ${MNE_sample}/version.txt

# Source space
mne_setup_source_space --ico -6 --overwrite

# If one wanted to use other source spaces, these types of options are available
mne_setup_source_space --subject fsaverage --ico 5 --morph sample --overwrite
mne_setup_source_space --subject sample --all --overwrite

# This is the default fsaverage source space:
mne_setup_source_space --subject fsaverage --ico 5 --overwrite

# Add distances to source space (if desired, takes a long time)
BEM_DIR=$SUBJECTS_DIR/sample/bem
mv $BEM_DIR/sample-oct-6-src.fif $BEM_DIR/sample-oct-6-orig-src.fif
mne_add_patch_info --dist 7 --src $BEM_DIR/sample-oct-6-orig-src.fif --srcp $BEM_DIR/sample-oct-6-src.fif

# Prepare for forward computation
mne_setup_forward_model --homog --surf --ico 4
mne_setup_forward_model --surf --ico 4

cd $MEG_DIR

# Need a bad channel file

echo 'MEG 2443' > sample_bads.bad
echo 'EEG 053' >> sample_bads.bad

mne_mark_bad_channels --bad sample_bads.bad sample_audvis_raw.fif

# Mark bad channels for empty-room noise

echo 'MEG 2443' > ernoise_bads.bad

mne_mark_bad_channels --bad ernoise_bads.bad ernoise_raw.fif

# Compute ECG SSP projection vectors. The produced file will also include the SSP projection vectors currently in the raw file
mne compute_proj_ecg -i sample_audvis_raw.fif -c "MEG 1531" --l-freq 1 --h-freq 100 --rej-grad 3000 --rej-mag 4000 --rej-eeg 100

# Do the same for EOG. Also include the projection vectors from the previous step, so that the file contains all projection vectors
mne compute_proj_eog -i sample_audvis_raw.fif --l-freq 1 --h-freq 35 --rej-grad 3000 --rej-mag 4000 --rej-eeg 100 --no-proj --proj sample_audvis_ecg_proj.fif

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

# Compute the empty-room noise covariance matrix
mne_process_raw --raw ernoise_raw.fif --lowpass 40 --projon \
        --savecovtag -cov --cov ernoise.cov
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

# Create various sensitivity maps
mne_sensitivity_map --fwd sample_audvis-meg-eeg-oct-6-fwd.fif \
    --map 1 --w sample_audvis-grad-oct-6-fwd-sensmap
mne_sensitivity_map --fwd sample_audvis-meg-eeg-oct-6-fwd.fif \
    --map 1 --w sample_audvis-mag-oct-6-fwd-sensmap --mag
mne_sensitivity_map --fwd sample_audvis-meg-eeg-oct-6-fwd.fif \
    --map 1 --w sample_audvis-eeg-oct-6-fwd-sensmap --eeg
mne_sensitivity_map --fwd sample_audvis-meg-eeg-oct-6-fwd.fif \
    --map 2 --w sample_audvis-grad-oct-6-fwd-sensmap-2
mne_sensitivity_map --fwd sample_audvis-meg-eeg-oct-6-fwd.fif \
    --map 3 --w sample_audvis-mag-oct-6-fwd-sensmap-3 --mag

# Compute some with the EOG + ECG projectors
for map_type in 4 5 6 7; do
    mne_sensitivity_map --fwd sample_audvis-meg-eeg-oct-6-fwd.fif \
        --map $map_type --w sample_audvis-eeg-oct-6-fwd-sensmap-$map_type \
        --eeg --proj sample_audvis_eog_proj.fif
done

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

# produce 2 with fixed orientation (depth or not for testing)
mne_do_inverse_operator --fwd sample_audvis-meg-oct-6-fwd.fif \
        --depth --meg --fixed

mne_do_inverse_operator --fwd sample_audvis-meg-oct-6-fwd.fif --fixed \
        --meg --inv sample_audvis-meg-oct-6-meg-nodepth-fixed-inv.fif

# produce two with diagonal noise (for testing)
mne_do_inverse_operator --fwd sample_audvis-meg-oct-6-fwd.fif --depth \
        --loose 0.2 --meg --diagnoise \
        --inv sample_audvis-meg-oct-6-meg-diagnoise-inv.fif

mne_do_inverse_operator --fwd sample_audvis-meg-eeg-oct-6-fwd.fif --depth \
        --loose 0.2 --eeg --meg --diagnoise \
        --inv sample_audvis-meg-eeg-oct-6-meg-eeg-diagnoise-inv.fif

# Produce stc files

mods="meg eeg meg-eeg"

for mod in $mods ; do

mne_make_movie --inv sample_audvis-${mod}-oct-6-${mod}-inv.fif \
    --meas sample_audvis-ave.fif \
    --tmin 0 --tmax 250 --tstep 10 --spm \
    --smooth 5 --bmin -100 --bmax 0 --stc sample_audvis-${mod}

# let's also morph to fsaverage
mne_make_movie --stcin sample_audvis-${mod} --morph fsaverage \
    --smooth 12 --morphgrade 3 --stc fsaverage_audvis-${mod}

done

###############################################################################
# Do one dipole fitting
mne_dipole_fit --meas sample_audvis-ave.fif --set 1 --meg --tmin 40 --tmax 95 \
    --bmin -200 --bmax 0 --noise sample_audvis-cov.fif \
    --bem ../../subjects/sample/bem/sample-5120-bem-sol.fif \
    --origin 0:0:40 --mri sample_audvis-meg-oct-6-fwd.fif \
    --dip sample_audvis_set1.dip

exit 0

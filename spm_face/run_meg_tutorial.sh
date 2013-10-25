#!/usr/bin/env bash

if [ $# -ne 1 ] ; then
    echo "Usage: $0 <sample data directory>"
    exit 1
fi

SPM_sample=$1

cd ${SPM_sample}/subjects && export SUBJECTS_DIR=`pwd`
cd -
cd ${SPM_sample}/MEG/spm && export MEG_DIR=`pwd`
cd -

export SUBJECT=spm

# Source space
mne_setup_source_space --ico -6 --overwrite

BEM_DIR=$SUBJECTS_DIR/${SUBJECT}/bem

# Prepare for forward computation
mne_setup_forward_model --homog --surf --ico 4
# mne_setup_forward_model --surf --ico 4

cd $MEG_DIR

# # Compute ECG SSP projection vectors. The produced file will also include the SSP projection vectors currently in the raw file
# mne_compute_proj_ecg.py -i sample_audvis_raw.fif -c "MEG 1531" --l-freq 1 --h-freq 100 --rej-grad 3000 --rej-mag 4000 --rej-eeg 100
# 
# # Do the same for EOG. Also include the projection vectors from the previous step, so that the file contains all projection vectors
# mne_compute_proj_eog.py -i sample_audvis_raw.fif --l-freq 1 --h-freq 35 --rej-grad 3000 --rej-mag 4000 --rej-eeg 100 --no-proj --proj sample_audvis_ecg_proj.fif

###############################################################################
# Compute forward solution a.k.a. lead field

# for MEG only
mne_do_forward_solution --mindist 5 --spacing oct-6 \
        --meas SPM_CTF_MEG_example_faces1_3D_raw.fif --bem ${SUBJECT}-5120 \
        --megonly --overwrite \
        --fwd SPM_CTF_MEG_example_faces1_3D-meg-oct-6-fwd.fif

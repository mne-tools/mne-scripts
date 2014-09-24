#!/bin/bash -ef

SUBJECTS_DIR=/home/larsoner/custombuilds/mne-python/examples/MNE-testing-data/subjects
SUBJECT=sample

# Use a lower ICO here to (greatly) reduce file size
mne_setup_forward_model --subject sample --surf --homog --ico 3
mne_setup_forward_model --subject sample --surf --ico 3
# mri_convert -vs 3 3 3 -i aseg_orig.mgz -o aseg.mgz

# SRC and Fwd
mne_setup_source_space --oct 4 --overwrite
mne_add_patch_info --src sample-oct-4-src.fif --srcp sample-oct-4-src.fif
mne_setup_source_space --oct 2 --overwrite
NAME=sample_audvis_trunc
FWD=${NAME}-meg-eeg-oct-6-fwd.fif
FWD_SMALL=${NAME}-meg-eeg-oct-4-fwd.fif
FWD_TINY_GRAD=${NAME}-meg-eeg-oct-2-grad-fwd.fif
mne_do_forward_solution --mindist 5 --spacing oct-6 --meas ${NAME}_raw.fif --bem sample-1280-1280-1280 --overwrite --fwd ${FWD}
mne_do_forward_solution --mindist 5 --spacing oct-4 --meas ${NAME}_raw.fif --bem sample-1280-1280-1280 --overwrite --fwd ${FWD_SMALL}
mne_do_forward_solution --mindist 5 --spacing oct-2 --meas ${NAME}_raw.fif --bem sample-1280-1280-1280 --overwrite --grad --fwd ${FWD_TINY_GRAD}

# Ave/cov
mne_process_raw --raw ../../../MNE-sample-data/MEG/sample/sample_audvis_raw.fif --lowpass 80 --save sample_audvis_trunc_raw.fif --projoff --decim 2
python -c "import mne; mne.io.RawFIFF('sample_audvis_trunc_raw.fif', preload=True).crop(0, 20).save('sample_audvis_trunc_raw.fif', overwrite=True)"
mne_process_raw --raw ${NAME}_raw.fif --projon --filteroff --savecovtag -cov --cov audvis.cov
mne_process_raw --raw ${NAME}_raw.fif --filteroff --projon --saveavetag -ave --ave audvis.ave

# Sensitivity maps
mne_sensitivity_map --fwd ${FWD_SMALL} --map 1 --w ${NAME}-grad-oct-4-fwd-sensmap
mne_sensitivity_map --fwd ${FWD_SMALL} --map 2 --w ${NAME}-grad-oct-4-fwd-sensmap-2
mne_sensitivity_map --fwd ${FWD_SMALL} --map 1 --w ${NAME}-mag-oct-4-fwd-sensmap --mag
mne_sensitivity_map --fwd ${FWD_SMALL} --map 3 --w ${NAME}-mag-oct-4-fwd-sensmap-3 --mag
mne_sensitivity_map --fwd ${FWD_SMALL} --map 1 --w ${NAME}-eeg-oct-4-fwd-sensmap --eeg
for map_type in 4 5 6 7; do
    mne_sensitivity_map --fwd ${FWD_SMALL} \
        --map $map_type --w ${NAME}-eeg-oct-4-fwd-sensmap-$map_type \
        --eeg --proj sample_audvis_eog_proj.fif
done

# Inverse ops
mne_do_inverse_operator --fwd ${FWD} --depth --loose 0.2 --meg
mne_do_inverse_operator --fwd ${FWD_SMALL} --depth --loose 0.2 --meg
mne_do_inverse_operator --fwd ${FWD_SMALL} --fixed --meg --inv ${NAME}-meg-eeg-oct-4-meg-nodepth-fixed-inv.fif
mne_do_inverse_operator --fwd ${FWD_SMALL} --depth --loose 0.2 --eeg --meg --diagnoise --inv ${NAME}-meg-eeg-oct-4-meg-eeg-diagnoise-inv.fif

mne_make_movie --inv ${NAME}-meg-eeg-oct-6-meg-inv.fif --meas ${NAME}-ave.fif \
    --tmin 0 --tmax 250 --tstep 10 --spm --smooth 5 --bmin -100 --bmax 0 --stc ${NAME}-meg
mne_make_movie --stcin ${NAME}-meg --morph fsaverage \
    --smooth 12 --morphgrade 3 --stc fsaverage_audvis_trunc-meg

# dipole fitting
mne_dipole_fit --meas ${NAME}-ave.fif --set 1 --meg --tmin 40 --tmax 95 \
    --bmin -200 --bmax 0 --noise ${NAME}-cov.fif \
    --bem $SUBJECTS_DIR/sample/bem/sample-1280-1280-1280-bem-sol.fif \
    --origin 0:0:40 --mri ${FWD} \
    --dip ${NAME}_set1.dip

mne_volume_source_space --bem $SUBJECTS_DIR/$SUBJECT/bem/sample-1280-bem.fif \
    --grid 7 --mri $SUBJECTS_DIR/sample/mri/T1.mgz \
    --src $SUBJECTS_DIR/sample/bem/sample-volume-7mm-src.fif

mne_do_forward_solution --mindist 5 \
        --src $SUBJECTS_DIR/sample/bem/sample-volume-7mm-src.fif \
        --meas sample_audvis_trunc_raw.fif --bem sample-1280 --megonly --overwrite \
        --fwd sample_audvis_trunc-meg-vol-7-fwd.fif

mne_sensitivity_map --fwd sample_audvis_trunc-meg-vol-7-fwd.fif \
    --map 1 --w sample_audvis_trunc-grad-vol-7-fwd-sensmap

mne_do_inverse_operator --fwd sample_audvis_trunc-meg-vol-7-fwd.fif --depth --meg
exit(0)

echo "
# This was used to create the lower-res sample_ds surfaces
from os import path as op
import numpy as np
import mne

subjects_dir = ('/home/larsoner/custombuilds/mne-python/examples/'
                'MNE-testing-data/subjects')
for subj in ('sample', 'fsaverage'):
    src = mne.setup_source_space(subj, None, 'ico5', add_dist=False,
                                 subjects_dir=subjects_dir)
    for s, hemi in zip(src, ['lh', 'rh']):
        print('Subject %s hemi %s' % (subj, hemi))
        rr = mne.read_surface(op.join(subjects_dir, subj, 'surf',
                                      hemi + '.sphere.reg'))[0]
        assert len(rr) == len(s['rr'])
        rr = rr[s['vertno']]
        tris = s['use_tris']
        rev_idx = len(s['rr']) * np.ones(len(s['rr']), int)
        rev_idx[s['vertno']] = np.arange(len(rr))
        tris = rev_idx[tris]
        mne.write_surface(op.join(subjects_dir, subj + '_ds', 'surf',
                                  hemi + '.sphere.reg'), rr, tris)
"

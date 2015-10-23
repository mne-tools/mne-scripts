import os
from os.path import join
import sys

import mne
from mne.source_space import setup_volume_source_space
from mne.forward._make_forward import make_forward_solution
from mne.minimum_norm import make_inverse_operator, write_inverse_operator


def run():

    args = sys.argv
    if len(args) <= 1:
        print 'Usage: run_anatomy_tutorial.sh <sample data directory>'
        return

    sample_dir = args[1]
    subjects_dir = join(sample_dir, 'subjects')
    meg_dir = join(sample_dir, 'MEG', 'sample')

    os.environ['SUBJECTS_DIR'] = subjects_dir
    os.environ['MEG_DIR'] = meg_dir

    subject = 'sample'

    bem = join(subjects_dir, subject, 'bem', 'sample-5120-bem-sol.fif')
    mri = join(subjects_dir, subject, 'mri', 'T1.mgz')
    fname = join(subjects_dir, subject, 'bem', 'volume-7mm-src.fif')
    src = setup_volume_source_space(subject, fname=fname, pos=7, mri=mri,
                                    bem=bem, overwrite=True,
                                    subjects_dir=subjects_dir)

###############################################################################
    # Compute forward solution a.k.a. lead field

    raw = mne.io.Raw(join(meg_dir, 'sample_audvis_raw.fif'))
    fwd_fname = join(meg_dir, 'sample_audvis-meg-vol-7-fwd.fif')
    trans = join(meg_dir, 'sample_audvis_raw-trans.fif')
    # for MEG only
    fwd = make_forward_solution(raw.info, trans=trans, src=src, bem=bem,
                                fname=fwd_fname, meg=True, eeg=False,
                                overwrite=True)

    # Make a sensitivity map
    smap = mne.sensitivity_map(fwd, ch_type='grad', mode='free')
    smap.save(join(meg_dir, 'sample_audvis-grad-vol-7-fwd-sensmap'), ftype='w')

###############################################################################
    # Compute MNE inverse operators
    #
    # Note: The MEG/EEG forward solution could be used for all
    #
    noise_cov = mne.read_cov(join(meg_dir, 'sample_audvis-cov.fif'))
    inv = make_inverse_operator(raw.info, fwd, noise_cov)
    fname = join(meg_dir, 'sample_audvis-meg-vol-7-meg-inv.fif')
    write_inverse_operator(fname, inv)

is_main = (__name__ == '__main__')
if is_main:
    run()

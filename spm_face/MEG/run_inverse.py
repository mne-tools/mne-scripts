import pylab as pl

import mne
from mne.minimum_norm import apply_inverse, make_inverse_operator, \
                             write_inverse_operator

###############################################################################
# Set parameters

ave_fname = 'evoked-ave.fif'
fwd_fname = 'SPM_CTF_MEG_example_faces1_3D-meg-oct-6-fwd.fif'
cov_fname = 'noise-cov.fif'

snr = 3.0
lambda2 = 1.0 / snr ** 2
dSPM = True

# Load data
evoked = mne.fiff.read_evoked(ave_fname, setno=[0, 1], baseline=None)
info = evoked[0].info
noise_cov = mne.read_cov(cov_fname)
forward = mne.read_forward_solution(fwd_fname, surf_ori=True)
inverse_operator = make_inverse_operator(info, forward, noise_cov,
                                              loose=0.2, depth=0.8)

write_inverse_operator('spm-inv.fif', inverse_operator)

# Compute inverse solution
for e in evoked:
    stc = apply_inverse(e, inverse_operator, lambda2, dSPM, pick_normal=False)
    stc.save('spm_%s_dSPM_inverse' % e.comment)

# Constrast
constrast = evoked[1] - evoked[0]
stc = apply_inverse(constrast, inverse_operator, lambda2, dSPM,
                    pick_normal=False)
stc.save('spm_%s_dSPM_inverse' % constrast.comment)

# plot constrast
constrast.plot()

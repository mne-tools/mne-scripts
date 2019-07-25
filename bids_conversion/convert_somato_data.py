"""Convert the MNE-somato-data to BIDS format.

Requirements
------------
The Python dependencies to run this script are:

- numpy>=1.16
- scipy>=1.2
- mne<0.19
- mne-bids>=0.3
- nibabel>=2.4.1

FreeSurfer
----------
Next to the Python requirements, you will need FreeSurfer installed on your
system. Once FreeSurfer is installed and you want to run this script, make sure
to initialize FreeSurfer first:

$ export FREESURFER_HOME=/path/to/FreeSurfer
$ source $FREESURFER_HOME/SetUpFreeSurfer.sh

Helpful links
-------------
- https://mne-tools.github.io/stable/index.html
- https://mne-tools.github.io/mne-bids/
- https://mne-tools.github.io/stable/manual/datasets_index.html?#somatosensory
- https://surfer.nmr.mgh.harvard.edu/fswiki/FreeSurferWiki
- https://mne-tools.github.io/stable/auto_tutorials/source-modeling/plot_background_freesurfer.html  # noqa: E501

"""
# Authors: Stefan Appelhoff <stefan.appelhoff@mailbox.org>
#          Mainak Jas <mainakjas@gmail.com>
#
# License: BSD (3-clause)
import os
import os.path as op
import shutil as sh
import json

import numpy as np

import mne
from mne.utils import check_version, run_subprocess
import mne.datasets.somato as somato

from mne_bids import write_raw_bids, make_bids_basename, write_anat
from mne_bids.utils import print_dir_tree

# Create READMEs for the BIDS dataset
# Prepare the text for the central README
main_readme = """MNE-somato-data-bids
====================

This dataset contains the MNE-somato-data in BIDS format.

The conversion can be reproduced through the Python script stored in the
`/code` directory of this dataset. See the README in that directory.

The `/derivaties` directory contains the outputs of running the FreeSurfer
pipeline `recon-all` on the MRI data with no additional commandline options
(only defaults were used):

$ recon-all -i $bids_nifti -s sub-01 -all

After the `recon-all` call, there were further FreeSurfer calls from the MNE
API:

$ mne make_scalp_surfaces -s sub-01 --force
$ mne watershed_bem -s sub-01

The derivatives also contain the forward model `*-fwd.fif`, which was produced
using the source space definition, a `*-trans.fif` file, and the boundary
element model (=conductor model) that lives in
`freesurfer/subjects/sub-01/bem/*-bem-sol.fif`.

The `*-trans.fif` file is not saved, but can be recovered from the anatomical
landmarks in the `sub-01/anat/T1w.json` file and MNE-BIDS' function
`get_head_mri_transform`.

See: https://github.com/mne-tools/mne-bids for more information.

Notes on FreeSurfer
===================
the FreeSurfer pipeline `recon-all` was run new for the sake of converting the
somato data to BIDS format. This needed to be done to change the "somato"
subject name to the BIDS subject label "01". Note, that this is NOT "sub-01",
because in BIDS, the "sub-" is just a prefix, whereas the "01" is the subject
label.

"""

# Prepare the text for the README in the /code directory
code_readme = """`convert_somato_data.py` is a Python script that converts the
MNE-somato-data into BIDS format. See https://bids.neuroimaging.io for more
information.

For installation, we recommend the Anaconda distribution. find the installation
guide here: https://docs.anaconda.com/anaconda/install/

After you have a working version of Python 3, simply install the required
packages via `pip`:

pip install numpy>=1.16 scipy>=1.2 mne==0.18 mne-bids>=0.3 nibabel>=2.4.1

"""

# make a CHANGES file, marking the initial release as BIDS data
changes_readme = """1.0.0 2019-08-01
    - initial release

"""

# mne should be 0.18 minimum ... but not higher
if not check_version('mne', '0.18') or check_version('mne', '0.19'):
    raise RuntimeError('You need to install mne 0.18: `pip install mne==0.18`')
# the other dependencies are a bit more lenient, we check anyways
for pkg, ver in [('numpy', '1.16'), ('scipy', '1.2'), ('nibabel', '2.4.1'),
                 ('mne_bids', '0.3')]:
    if not check_version(pkg, ver):
        raise RuntimeError('You need to install {0} {1} or higher:'
                           'pip install {0}>={1}'.format(pkg, ver))

# Check that FreeSurfer is initialized
FREESURFER_HOME = os.getenv('FREESURFER_HOME')
if FREESURFER_HOME is None:
    raise RuntimeError('You need to define a FREESURFER_HOME environment '
                       'variable pointing to your installation of FreeSurfer.'
                       'Also make sure you have initialized FreeSurfer by '
                       'running: `source $FREESURFER_HOME/SetUpFreeSurfer.sh`')

# Somato data prior to conversion
somato_path = somato.data_path()

# Print the directory tree
print('\nSomato data before conversion: {}\n'.format(somato_path))
print_dir_tree(somato_path, max_depth=3)
print('\n\n')

# Convert to BIDS
# Path to the raw data of somato dataset
fif_path = op.join(somato_path, 'MEG', 'somato')

# Load the raw data file
raw = mne.io.read_raw_fif(op.join(fif_path, 'sef_raw_sss.fif'))

# Set the sex of the participant to male
# Subject sex (0=unknown, 1=male, 2=female).
raw.info['subject_info']['sex'] = raw.info['subject_info'].get('sex', 1)

# Get the events, and assign an ID
events = mne.find_events(raw)
event_id = dict()
for val in np.unique(events[:, -1]):
    event_id['somato_event{}'.format(val)] = val

print('\n\n')
print('event_id: "{}"'.format(event_id))

# Make a bids name for the raw file
bids_basename = make_bids_basename(subject='01', task='somato')

# Make a location for the BIDS formatted data
somato_parent, somato_name = op.split(somato_path)
somato_path_bids = op.join(somato_parent, somato_name + '-bids')

# Write the data
write_raw_bids(raw, bids_basename, somato_path_bids, events, event_id,
               overwrite=True)

# Edit dataset_description.json to include link to dataset
dataset_description_json = op.join(somato_path_bids,
                                   'dataset_description.json')
with open(dataset_description_json, 'r') as fin:
    jsondict = json.load(fin)

# Edit some fields we know of
jsondict['Name'] = 'MNE-somato-data-bids'
jsondict['Authors'] = ['Lauri Parkkonen']
jsondict['License'] = 'PDDL, see: https://opendatacommons.org/licenses/pddl/'
jsondict['ReferencesAndLinks'] = ['http://martinos.org/mne/stable/manual/datasets_index.html?#somatosensory']  # noqa: E501
jsondict['Acknowledgements'] = "Stefan Appelhoff, Alexandre Gramfort, and Mainak Jas formatted these data to BIDS."   # noqa: E501

# overwrite the json, updating it
with open(dataset_description_json, 'w') as fout:
    json.dump(jsondict, fout, indent=2, sort_keys=True)

# Write anatomical data to BIDS
# we take the original T1 from the FreeSurfer directory
t1w = op.join(somato_path, 'subjects', 'somato', 'mri', 'T1.mgz')

# we also take the trans file, and use it to write the coordinates of
# anatomical landmarks to a T1w.json file
trans = op.join(somato_path, 'MEG', 'somato', 'sef_raw_sss-trans.fif')

# Copy over the MRI, convert it to NIfTI format, and write the anatomical
# landmarks in voxel coordinates
anat_dir = write_anat(somato_path_bids, subject='01', t1w=t1w, trans=trans,
                      raw=raw, overwrite=True, verbose=True)
t1w_nii = op.join(anat_dir, 'sub-01_T1w.nii.gz')

# Add derivatives
# not all of this is defined in BIDS as of yet
# General derivatives and FreeSurfer directory names
derivatives_dir = op.join(somato_path_bids, 'derivatives')
subjects_dir_bids = op.join(derivatives_dir, 'freesurfer', 'subjects')

# Export the FreeSurfer SUBJECTS_DIR as environment variable, available to
# this process and all subprocesses
os.environ['SUBJECTS_DIR'] = subjects_dir_bids

# Run recon-all from FreeSurfer
run_subprocess(['recon-all', '-i', t1w_nii, '-s', '01', '-all'])

# Run make_scalp_surfaces ... use --force to prevent an error from
# topology defects
run_subprocess(['mne', 'make_scalp_surfaces', '-s', '01', '--overwrite',
                '--force'])

# Run watershed_bem
run_subprocess(['mne', 'watershed_bem', '-s', '01', '--overwrite'])

# Make a directory for our subject and move the forward model there
forward_dir = op.join(derivatives_dir, '01')
if not op.exists(forward_dir):
    os.makedirs(forward_dir)

# copy it, overwriting old if it's there
old_forward = op.join(somato_path, 'MEG', 'somato',
                      'somato-meg-oct-6-fwd.fif')
bids_forward = op.join(forward_dir, 'sub-01_task-somato-fwd.fif')
sh.copyfile(old_forward, bids_forward)

# Prepare a /code directory to put a README there
code_dir = op.join(somato_path_bids, 'code')
if not op.exists(code_dir):
    os.makedirs(code_dir)

# Write the README and CHANGES texts defined earlier
changes_fname = op.join(somato_path_bids, 'CHANGES')
main_fname = op.join(somato_path_bids, 'README')
code_fname = op.join(code_dir, 'README')
for fname, txt in zip((changes_fname, main_fname, code_fname),
                      (changes_readme, main_readme, code_readme)):
    with open(fname, 'w') as fout:
        print(changes_txt, file=fout)  # noqa: E999

# Finally, copy over THIS Python script as well
basename = op.basename(__file__)
fpath = op.realpath(__file__)
sh.copyfile(fpath, op.join(code_dir, basename))

# And show what the converted data look like
print('\nSomato BIDS data: {}\n'.format(somato_path_bids))
print_dir_tree(somato_path_bids, max_depth=5)
print('\n\n')

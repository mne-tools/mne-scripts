#!/usr/bin/env bash

# start by downloading data

wget http://www.fil.ion.ucl.ac.uk/spm/download/data/mmfaces/multimodal_smri.zip
wget http://www.fil.ion.ucl.ac.uk/spm/download/data/mmfaces/multimodal_meg.zip

unzip multimodal_smri.zip
unzip multimodal_meg.zip

mkdir subjects

# set up freesurfer :
freesurfer # my alias for setup

# Run freesurfer reconstruction:
cd subjects
export SUBJECTS_DIR=$PWD
recon-all -all -i ../sMRI/smri.hdr -s spm_smri

# Convert CTF to FIF

cd ../MEG
mne_ctf2fiff --ds SPM_CTF_MEG_example_faces1_3D.ds --fif SPM_CTF_MEG_example_faces1_3D_raw.fif
mne_ctf2fiff --ds SPM_CTF_MEG_example_faces2_3D.ds --fif SPM_CTF_MEG_example_faces2_3D_raw.fif
mkdir mat
mv *.mat mat/

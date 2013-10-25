#!/usr/bin/env bash

# start by downloading data

if [ $# -ne 1 ] ; then
    echo "Usage: $0 <sample data directory>"
    exit 1
fi

SPM_sample=$1/MNE-spm-face
mkdir ${SPM_sample}
export SUBJECT=spm
CUR_DIR=$(pwd)

TMPDIR=$1/TMP
mkdir ${TMPDIR}
cd ${TMPDIR}

# Download the data
for FNAME in multimodal_smri.zip multimodal_meg.zip
do
    if [ ! -f ${FNAME} ];
    then
        wget http://www.fil.ion.ucl.ac.uk/spm/download/data/mmfaces/${FNAME}
    fi
    unzip ${FNAME}
done

# Run freesurfer reconstruction
export SUBJECTS_DIR=${SPM_sample}/subjects
if [ ! -d ${SUBJECTS_DIR}/spm ];
then
    mkdir -p ${SUBJECTS_DIR}/spm
    cd ${SUBJECTS_DIR}/spm
    recon-all -all -i ${TMPDIR}/sMRI/smri.hdr -s spm
fi

# remove fsaverage symlinks
find ${SUBJECTS_DIR} -type l -exec rm -rf {} \;

# Convert CTF to FIF
cd ${SPM_sample}
mkdir -p MEG/spm
cd MEG/spm
for FNAME in SPM_CTF_MEG_example_faces1_3D SPM_CTF_MEG_example_faces2_3D
do
    FIF_FNAME=${FNAME}_raw.fif
    if [ ! -f $FIF_FNAME ];
    then
        mne_ctf2fiff --ds ${TMPDIR}/MEG/${FNAME}.ds --fif ${FIF_FNAME}
    fi
done

# Copy trans file
cp ${CUR_DIR}/SPM_CTF_MEG_example_faces1_3D_raw-trans.fif ${SPM_sample}/MEG/spm/

# Create archive
cd $1
tar -cjvf MNE-spm-face.tar.gz MNE-spm-face

#!/usr/bin/env bash

# start by downloading data
# give full path when running it, for example
# $ ./run_freesurfer_recon.sh /tsi/doctorants/mainak/mne-scripts/brainstorm/brainstorm
if [ $# -ne 1 ] ; then
    echo "Usage: $0 <sample data directory>"
    exit 1
fi

# directory for the MRI recon
BRAINSTORM_DATA=$1/MNE-brainstorm-data
echo "BRAINSTORM_DATA set to $BRAINSTORM_DATA"
if [ ! -d ${BRAINSTORM_DATA} ];
then
    mkdir -p ${BRAINSTORM_DATA}
fi
CUR_DIR=$(pwd)

# directory for downloading the data
TMPDIR=$1/TMP
if [ ! -d ${TMPDIR} ];
then
    mkdir ${TMPDIR}
fi
cd ${TMPDIR}

# Download the data
for FNAME in sample_auditory sample_raw sample_resting
do
    if [ ! -f ${FNAME}.zip ];
    then
        wget -O ${FNAME}.zip http://neuroimage.usc.edu/bst/getupdate.php?u=mne\&s=${FNAME}
    fi

    if [ ! -d ${FNAME} ];
    then
        unzip ${FNAME}.zip
    fi
done

# Create subject directory
export SUBJECTS_DIR=${BRAINSTORM_DATA}/subjects
echo "SUBJECTS_DIR set to $SUBJECTS_DIR"
if [ ! -d ${SUBJECTS_DIR} ];
then
    echo "Creating subject directory"
    mkdir -p ${SUBJECTS_DIR}
fi

for ARCHIVE in auditory raw resting
do

    # make the name of the Data/data directory always lower case
    if [ -d ${TMPDIR}/sample_${ARCHIVE}/Data ];
    then
        mv ${TMPDIR}/sample_${ARCHIVE}/Data ${TMPDIR}/sample_${ARCHIVE}/data
    fi

    # Make the MEG directory
    # Convert CTF to FIF
    cd ${TMPDIR}/sample_${ARCHIVE}/data

    # convert to ctf
    for FNAME in `ls -d *.ds`
    do
        echo ${FNAME%.*}
        FIF_FNAME=${FNAME%.*}_raw.fif
        if [ ! -f $FIF_FNAME ];
        then
            ORIG_FNAME=${TMPDIR}/sample_${ARCHIVE}/data/${FNAME}
            mne_ctf2fiff --ds ${ORIG_FNAME} --fif ${FIF_FNAME}
            rm -rf ${ORIG_FNAME}
        fi
    done

    # make the name of the Anatomy/anatomy directory always lower case
    if [ -d ${TMPDIR}/sample_${ARCHIVE}/Anatomy ];
    then
        mv ${TMPDIR}/sample_${ARCHIVE}/Anatomy ${TMPDIR}/sample_${ARCHIVE}/anatomy
    fi

    # run recon-all
    export SUBJECT=bst_${ARCHIVE}
    recon-all -all -i ${TMPDIR}/sample_${ARCHIVE}/anatomy/mri/T1.mgz -s ${SUBJECT}

    # remove fsaverage symlinks
    find ${SUBJECTS_DIR}/${SUBJECT} -type l -exec rm -rf {} \;

    # use watershed algorithm to make BEM surfaces
    if [ ! -f ${SUBJECTS_DIR}/${SUBJECT}/bem/${SUBJECT}-inner-skull.surf ];
    then
        cd ${SUBJECTS_DIR}/${SUBJECT}/bem
        mne_watershed_bem
        ln -s watershed/${SUBJECT}_inner_skull_surface ${SUBJECT}-inner_skull.surf
        ln -s watershed/${SUBJECT}_outer_skin_surface ${SUBJECT}-outer_skin.surf
        ln -s watershed/${SUBJECT}_outer_skull_surface ${SUBJECT}-outer_skull.surf
    fi

    # Make high resolution head surface
    HEAD_FNAME=${SUBJECTS_DIR}/${SUBJECT}/bem/${SUBJECT}-head.fif
    if [ ! -f ${HEAD_FNAME} ];
    then
        mkheadsurf -s ${SUBJECT}
        mne_surf2bem --surf ${SUBJECTS_DIR}/${SUBJECT}/surf/lh.seghead --id 4 --check --fif ${HEAD_FNAME}
    fi

    # cleanup and archive
    if [ ! -d ${BRAINSTORM_DATA}/bst_${ARCHIVE} ];
    then
        mkdir -p ${BRAINSTORM_DATA}/bst_${ARCHIVE}/MEG
        mkdir -p ${BRAINSTORM_DATA}/bst_${ARCHIVE}/subjects
    fi
    cp -a ${TMPDIR}/sample_${ARCHIVE}/data/ ${BRAINSTORM_DATA}/bst_${ARCHIVE}/MEG
    cp -a ${BRAINSTORM_DATA}/subjects/bst_${ARCHIVE} ${BRAINSTORM_DATA}/bst_${ARCHIVE}/subjects
    mv ${BRAINSTORM_DATA}/bst_${ARCHIVE}/MEG/data ${BRAINSTORM_DATA}/bst_${ARCHIVE}/MEG/bst_${ARCHIVE}
    tar -cjvf ${BRAINSTORM_DATA}/bst_${ARCHIVE}.tar.bz2 ${BRAINSTORM_DATA}/bst_${ARCHIVE}
done

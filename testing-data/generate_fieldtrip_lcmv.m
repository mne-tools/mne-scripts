% Fieldtrip source reconstruction with MNE-Python data and forward model
%
% Author: Britta Westner  <britta.wstnr@gmail.com>
% License: BSD (3-clause)


% File to generate the FieldTrip beamformer output data used in the FieldTrip
% comparison unit test beamformer.test.test_external

% Input data for this file can be produced using the _get_bf_data function from
% beamformer.test.test_external


% path to MNE testing data and MNE sample dataset:
mne_data_path = './';
mne_sample_path = './';
% path to save and load data:
data_path = './';

% add FieldTrip and NutMEG
fieldtrip_path = './';
nutmeg_path = './';

try
    warning('FieldTrip is already on your path, check for right version.')
    ft_defaults;
catch
    addpath(fieldtrip_path);
    ft_defaults;
end

addpath(nutmeg_path);

%% read in the MNE-Python objects

% data can be read in with Fieldtrip's preprocessing function:
data_fname = fullfile(data_path, 'raw.fif');
cfg =[];
cfg.dataset = data_fname;
data = ft_preprocessing(cfg);%
data.hdr.grad.coordsys = 'neuromag306';

% select grads only (ft_selectdata with 'MEGGRAD' is not working here):
count = 1;
for ii = 1: length(data.grad.chantype)
    if strcmp(data.grad.chantype{ii}, 'megplanar')
        picks(count) = ii;
        count = count + 1;
    end
end

labels_select = data.label(picks);

% there is one add. bad channel -- this info is from test_lcmv._get_data()
idx_del = strfind(labels_select, 'MEG 0943');  %
idx_del = find(not(cellfun('isempty', idx_del)));
labels_select(idx_del) = [];

cfg = [];
cfg.channel = labels_select;
data = ft_selectdata(cfg, data);

% read the headmodel
vol_fname = fullfile(mne_sample_path, '/subjects/sample/bem/', ...
                     'sample-5120-bem.fif');
vol_bem = mne_read_bem_surfaces(vol_fname);

% forward model
fwd_fname = fullfile(mne_data_path, ...
                     'sample_audvis_trunc-meg-vol-7-fwd.fif');
fwd_model = mne_read_forward_solution(fwd_fname, false,  false);

%% Build a fake vol-structure

% Fieldtrip's ft_sourceanalysis() expects a headmodel as input:
% build one based on the volume and transform positions to MEG head space
vol = [];
vol.bnd.pos = nut_coordtfm(fwd_model.source_rr, fwd_model.mri_head_t.trans);
vol.bnd.tri = vol_bem.tris;
vol.type = 'openmeeg';
vol.cond = [1., 1., 1.];  % dummy field in this case, values don't matter now

%% Build the leadfield structure from MNE-Python input

leadf = [];
leadf.pos = fwd_model.source_rr;  % positions
leadf.inside = logical(repmat(1, size(leadf.pos,1), 1));  % positions inside
leadf.unit = 'm';
leadf.label = fwd_model.sol.row_names;
leadf.leadfielddimord =  '{pos}_chan_ori';  % dimension order

% insert the actual leadfield into the FieldTrip cell structure
leadf.leadfield = cell(1,length(leadf.inside));
for ii=1:length(leadf.inside)
    if leadf.inside(ii)
        % this is ordered: channels x sourcepos/ori
        leadf.leadfield{ii}(:,1) = fwd_model.sol.data(:, ii*3-2);
        leadf.leadfield{ii}(:,2) = fwd_model.sol.data(:, ii*3-1);
        leadf.leadfield{ii}(:,3) = fwd_model.sol.data(:, ii*3);
    end
end

%% covariance matrix

% create Fieldtrip covariance matrix from MNE data to get a dummy structure
cfg = [];
cfg.channel          = leadf.label;
cfg.covariance       = 'yes';
cfg.covariancewindow = [0.05 0.3];
cov                  = ft_timelockanalysis(cfg, data);

% adjust time to match evoked and delete unnecessary field
cov.time = cov.time(1:31);  % this works because we redo time in MNE anyway
cov = rmfield(cov, 'dof');
cov = rmfield(cov, 'var');

% load MNE-Python covariance matrix and evoked data:
load(fullfile(data_path, 'sample_cov.mat'));
load(fullfile(data_path, 'sample_evoked.mat'));

% input MNE-Python covariance data in covariance structure
cov.cov = sample_cov;
cov.avg = sample_evoked;


%% run the LCMV beamformer

% loop over the different combinations to create output for all
save_names = {'ug_vec', 'ug_scal', 'ung', 'ung_pow'};
weight_norms = {false, false, 'unitnoisegain', 'unitnoisegain'};
pick_oris = {'no', 'yes', 'yes', 'yes'};
pow = {false, false, false, true};

for ii=1:length(save_names)

    % run the beamformer
    cfg                    = [];
    cfg.channel            = data.label;
    cfg.headmodel          = ft_convert_units(vol, 'mm');
    cfg.method             = 'lcmv';
    cfg.grid               = ft_convert_units(leadf, 'mm');
    cfg.lcmv.reducerank    = 'no' ;
    cfg.lcmv.fixedori      = pick_oris{ii};
    if weight_norms{ii} == 'unitnoisegain'
        cfg.lcmv.projectnoise  = 'yes';
        cfg.lcmv.weightnorm    = weight_norms{ii};
    end
    cfg.lcmv.lambda        = '5%';
    source_lcmv            = ft_sourceanalysis(cfg, cov);

    save_cell{ii} = source_lcmv.cfg.lcmv;
    %% Save source ouput
    % Prepare by combining the 3 orientations (if applicable, i.e., if
    % fixedori is false) or by taking take absolut value to account for
    % arbitray 180 degrees rotations

    if ~pow{ii}

        insideidx = find(source_lcmv.inside);
        if(size(source_lcmv.avg.mom{insideidx(1)},1)==3)
            for jj = 1:length(insideidx)
                % this mimicks MNE-Python's `combine_xyz`
                source_lcmv.avg.mom{insideidx(jj)} = real(...
                    source_lcmv.avg.mom{insideidx(jj)});
                source_lcmv.avg.mom{insideidx(jj)} = sqrt(sum(...
                    [source_lcmv.avg.mom{insideidx(jj)}(1,:).^2; ...
                     source_lcmv.avg.mom{insideidx(jj)}(2,:).^2; ...
                     source_lcmv.avg.mom{insideidx(jj)}(3,:).^2]));
            end
        end
        % prepare MNE-Python'esque source file
        mne_source.data = single(cat(1, source_lcmv.avg.mom{:}));
        mne_source.tmin = min(source_lcmv.time);
        mne_source.tstep = source_lcmv.time(2)-source_lcmv.time(1);
    else
        mne_source.data = single(source_lcmv.avg.pow);
        % prepare MNE-Python'esque source file
        mne_source.tmin = 0.;
        mne_source.tstep = 1.;
    end

    mne_source.vertices = fwd_model.src.vertno;

    save_fname = ['ft_source_', save_names{ii}, '-vol.stc'];
    % save to mne structure
    mne_write_stc_file(fullfile(data_path, save_fname), mne_source);
end

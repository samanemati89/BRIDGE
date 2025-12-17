% run_cat12_batch.m
% Usage:
%  - Create subj_list_paths.txt (one full path to each T1 per line)
%  - Create and save a CAT12 batch template (cat12_batch_template.mat)
%  using the GUI with your prefere4d options
%  - Adjust paths below and run this script in MATLAB




% ----------------- USER CONFIG -----------------
spm_path = '/Users/snemati/Documents/toolbox/spm';   % path to spm12 folder (update)
addpath(spm_path);
addpath(fullfile(spm_path, 'toolbox', 'cat12'));    % adjust if CAT12 is elsewhere

template_batch = '/Users/snemati/Documents/ABC_BrainAge/Scripts/CAT12_brainage/cat12_batch_template.mat';
subj_list_file = '/Users/snemati/Documents/ABC_BrainAge/Data/Images/unprocessed/T1w_organized/session1/subj_list_paths.txt';

nproc = 4;   % set number of cores (optional)
logfile = '/Users/snemati/Documents/ABC_BrainAge/Scripts/CAT12_brainage/cat12_run_log.txt';
% ------------------------------------------------

spm('defaults','fmri');
spm_jobman('initcfg');

% Load subject list
fid = fopen(subj_list_file, 'r');
if fid < 0
    error('Cannot open subj list: %s', subj_list_file);
end
files = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
files = files{1};

% Load template batch (saved from CAT12 GUI)
if ~exist(template_batch, 'file')
    error('Template batch not found. Create and save it in CAT12 GUI: %s', template_batch);
end
tmp = load(template_batch);
if ~isfield(tmp, 'matlabbatch')
    % if you saved the variable with a different name, try to locate matlabbatch
    vars = fieldnames(tmp);
    fprintf('Loaded %s, found vars: %s\n', template_batch, strjoin(vars, ', '));
    if isfield(tmp, 'batch') && isfield(tmp.batch, 'matlabbatch')
        matlabbatch_template = tmp.batch.matlabbatch;
    else
        error('Saved file does not contain matlabbatch. Open the template in MATLAB and save matlabbatch variable.');
    end
else
    matlabbatch_template = tmp.matlabbatch;
end

% Open log file
lf = fopen(logfile, 'a');
fprintf(lf, '\n=== CAT12 run started: %s ===\n', datestr(now));
fclose(lf);

% Loop over subjects and run
for i = 1:numel(files)
    t1 = strtrim(files{i});
    if isempty(t1), continue; end
    fprintf('(%d/%d) Processing: %s\n', i, numel(files), t1);

    % copy template
    matlabbatch = matlabbatch_template;

    % Replace data entry with current T1 path
    % Find the field that contains the image data. For standard CAT12 estwrite it is often:
    %  matlabbatch{1}.spm.tools.cat.estwrite.data = { '/full/path/to.nii' };
    % But the exact location may differ by template; we try to find the first occurrence.
    replaced = false;
    for mb = 1:numel(matlabbatch)
        flds = fieldnames(matlabbatch{mb});
        if isfield(matlabbatch{mb}, 'spm')
            % dive further
        end
        try
            % attempt common location
            if isfield(matlabbatch{mb}, 'spm') && isfield(matlabbatch{mb}.spm, 'tools') ...
                    && isfield(matlabbatch{mb}.spm.tools, 'cat')
                if isfield(matlabbatch{mb}.spm.tools.cat, 'estwrite')
                    matlabbatch{mb}.spm.tools.cat.estwrite.data = { t1 };
                    if isfield(matlabbatch{mb}.spm.tools.cat.estwrite, 'nproc')
                        matlabbatch{mb}.spm.tools.cat.estwrite.nproc = nproc;
                    end
                    replaced = true;
                end
            end
        catch
            % fallback: try to set common pattern for older/newer versions
        end
    end

    if ~replaced
        % fallback: try first matlabbatch entry
        try
            matlabbatch{1}.spm.tools.cat.estwrite.data = { t1 };
            if isfield(matlabbatch{1}.spm.tools.cat.estwrite, 'nproc')
                matlabbatch{1}.spm.tools.cat.estwrite.nproc = nproc;
            end
            replaced = true;
        catch ME
            fprintf('ERROR: Could not insert T1 into template for %s: %s\n', t1, ME.message);
            fid = fopen(logfile, 'a'); fprintf(fid, 'ERROR inserting %s: %s\n', t1, ME.message); fclose(fid);
            continue;
        end
    end

    % Run the job
    try
        spm_jobman('run', matlabbatch);
        fprintf('Done: %s\n', t1);
        fid = fopen(logfile, 'a'); fprintf(fid, '%s : OK\n', t1); fclose(fid);
    catch ME
        fprintf('ERROR running CAT12 for %s: %s\n', t1, ME.message);
        fid = fopen(logfile, 'a'); fprintf(fid, '%s : ERROR %s\n', t1, ME.message); fclose(fid);
    end
end

fprintf('All done. Log: %s\n', logfile);

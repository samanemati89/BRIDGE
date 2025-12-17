% run_BA_gpr_local.m
% Use your BA_data2mat-produced .mat files (s4rp1_4mm_*.mat etc.) as both train & test
% Edit the user config below.

% -------------- USER CONFIG ----------------
mat_dir = '/Users/snemati/Documents/ABC_BrainAge/Data/Images/processed/CAT12_BrainAge/BrainAge_input'; 
% directory where s4*.mat files created by BA_data2mat are stored (or current dir)
basename = 'ABC_session1';    % D.name used when you created the s4... .mat files
relnumber = '_CAT12.9';       % same release string you used
segs = {'rp1', 'rp2'};               % {'rp1'} or {'rp1','rp2'} depending on what you created
resolutions = {'4','8'};      % which res used in BA_data2mat
smoothings = {'s4','s8'};     % which smooth used in BA_data2mat
use_smooth = {'s8'};          % choose which smoothing(s) to use here, e.g. {'s4','s8'} or {'s4'}
use_res = {'8'};              % choose which resolution(s) to use, e.g. {'4','8'} or {'4'}
tablesdir = fullfile(mat_dir, 'tables'); % where ordered_ids.txt and ages.txt are
PCA_components = 0;           % 0 -> use default PCA behaviour (D.PCA = 1 means PCA using n-1 comps),
                              % >1 -> limit to that many PCA components to reduce memory (recommend 50..200)
verbose = 1;
% --------------------------------------------

% sanity checks
if ~exist(mat_dir,'dir'), error('mat_dir not found: %s', mat_dir); end
if ~exist(tablesdir,'dir'), error('tablesdir not found: %s', tablesdir); end

% read ages and ids
ids = cellstr( strtrim( readlines(fullfile(tablesdir,'ordered_ids.txt')) ) );
ages = load(fullfile(tablesdir,'ages.txt'));
nsub = numel(ids);
if numel(ages) ~= nsub
    warning('Mismatch between ids (%d) and ages (%d). Proceeding, but check ordering.', nsub, numel(ages));
end

% build list of files to load (we will load all selected combos and then horizontally concatenate Y)
matfiles = {};
for si = 1:numel(segs)
  seg = segs{si};
  for r = 1:numel(use_res)
    res = use_res{r};
    for s = 1:numel(use_smooth)
      sm = use_smooth{s};
      % pattern: <sm><seg>_<res>mm_<basename><relnumber>.mat
      pattern = sprintf('%s%s_%smm_%s%s.mat', sm, seg, res, basename, relnumber);
      fullpath = fullfile(mat_dir, pattern);
      % also allow alternative where training_sample name uses dataset names, so accept wildcard:
      if exist(fullpath,'file')
        matfiles{end+1} = fullpath; %#ok<SAGROW>
      else
        % try wildcard across mat_dir to find matching files
        files = dir(fullfile(mat_dir, sprintf('%s%s_%smm_*%s.mat', sm, seg, res, relnumber)));
        if ~isempty(files)
          % prefer file that contains basename in its name (if any), else take first
          found = [];
          for k=1:numel(files)
            if contains(files(k).name, basename)
              found = files(k).name; break;
            end
          end
          if isempty(found)
            found = files(1).name;
          end
          matfiles{end+1} = fullfile(mat_dir, found); %#ok<SAGROW>
        else
          if verbose, fprintf('No files found for pattern %s%s_%smm_*%s.mat\n', sm, seg, res, relnumber); end
        end
      end
    end
  end
end

if isempty(matfiles)
  error('No s* .mat files found. Check mat_dir, basename, relnumber, and smoothing/res settings.');
end

fprintf('Found %d .mat files to load:\n', numel(matfiles));
for i=1:numel(matfiles), fprintf('  %s\n', matfiles{i}); end

% Load and concatenate Y matrices
Y_all = [];
for i=1:numel(matfiles)
  mf = matfiles{i};
  fprintf('Loading %s ...\n', mf);
  S = load(mf);
  % BA_data2mat typically saves variable Y (subjects x voxels) and maybe 'IDs' or similar.
  % We try to find a matrix variable with name 'Y' or, failing that, the largest numeric matrix.
  if isfield(S,'Y')
    Y = S.Y;
  else
    % find largest numeric matrix variable
    fn = fieldnames(S);
    best = ''; bestsz = 0;
    for k = 1:numel(fn)
      v = S.(fn{k});
      if isnumeric(v) && ndims(v)==2
        sz = numel(v);
        if sz > bestsz
          best = fn{k}; bestsz = sz;
        end
      end
    end
    if isempty(best)
      error('No suitable numeric 2D variable found in %s', mf);
    else
      fprintf('Using variable "%s" from %s as Y\n', best, mf);
      Y = S.(best);
    end
  end

  % ensure data type, and rows correspond to subjects
  Y = single(Y);
  % If Y has voxels as rows and subjects as cols (common in some conventions), check dims
  if size(Y,1) ~= nsub && size(Y,2) == nsub
    Y = Y'; % transpose to subjects x voxels
    fprintf('Transposed Y to make subjects as rows (now %d x %d)\n', size(Y,1), size(Y,2));
  end
  if size(Y,1) ~= nsub
    warning('Y rows (%d) != nsub (%d). You must ensure ordering and subject count match.', size(Y,1), nsub);
    % we will still continue, but BA_gpr may error later.
  end

  % optionally drop NaNs / zero columns? BA_gpr will scale later.
  % Concatenate horizontally: more segments/resolutions -> more features
  Y_all = [Y_all, Y];
  clear S Y;
end

fprintf('Final Y_all size: %d subjects x %d features\n', size(Y_all,1), size(Y_all,2));

% Build D struct required by BA_gpr
D = struct();
D.Y_test = single(Y_all);         % subjects x voxels/features
D.age_test = ages(:);
D.training_sample = {basename};   % set to your basename so n_training_samples >0 but we will set train_array same as data
D.train_array = {basename};       % important: if train_array{1} == D.data, BA_gpr will use Y_test as training when called via BA_gpr_ui logic
D.data = basename;                % used for equality checks
D.seg = segs;
D.res = use_res{1};               % scalar string (e.g. '4'); BA_gpr expects char
D.smooth = use_smooth{1};         % e.g. 's4'
D.relnumber = relnumber;
D.dir = mat_dir;                  % folder where mat files live (not needed for local-train but harmless)
D.PCA = 1;                        % enable PCA (recommended) - set to 0 to skip
if PCA_components > 0, D.PCA = PCA_components; end
D.PCA_method = 'svd';
D.RVR = 0;                        % use GPR (not RVR)
D.verbose = verbose;
D.p_dropout = 0;                  % no dropout by default

% Optional: if you want to use nuisance regressors (e.g. sex), add D.nuisance (matrix NxK)
% Example: load male flags from tablesdir if exists
malefile = fullfile(tablesdir,'male.txt');
if exist(malefile,'file')
  male = load(malefile);
  D.male_test = male(:);
else
  % leave empty
end

% Now call BA_gpr
fprintf('Calling BA_gpr ...\n');
[BrainAGE, PredictedAge, Dout] = BA_gpr(D);

% Save outputs
out_tab = fullfile(tablesdir, sprintf('BrainAGE_local_rp1rp2_smooth8_%s%s.csv', basename, relnumber));
IDs_table = ids;
T = table(IDs_table(:), D.age_test(:), PredictedAge(:), (PredictedAge(:)-D.age_test(:)), ...
    'VariableNames', {'ID','Age','PredictedAge','BAG'});
writetable(T, out_tab);
fprintf('Saved predictions to %s\n', out_tab);

% done
fprintf('Done. Mean BAG = %.3f, SD = %.3f\n', nanmean(PredictedAge - D.age_test), nanstd(PredictedAge - D.age_test));

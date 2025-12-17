% this script should be run from the BrainAGE folder which has all the
% scripts from the CAT12 Brainage github
% adjust base paths to your system
base = '/Users/snemati/Documents/ABC_BrainAge/Data/Images/processed/CAT12_BrainAge/BrainAge_input';
%rp1dir = fullfile(base, 'rp1_CAT12.9');  % folder with rp1 files
%rp2dir = fullfile(base, 'rp2_CAT12.9');  % folder with rp2 files (optional)
tablesdir = fullfile(base, 'tables');

% Load ages and sex (these are simple text files created earlier)
age_c = load(fullfile(tablesdir, 'ages.txt'));
male_c = load(fullfile(tablesdir, 'male.txt'));

% Fill D struct per BA_data2mat doc
D.age = age_c;
D.male = male_c;
D.release = '_CAT12.9';
D.name = 'ABC_session1';
D.data = { base };  % if you only want rp1, set D.data = {rp1dir};
% Resampling & smoothing options (defaults used in README)
D.res_array    = char('4','8');   % resampling mm
D.smooth_array = char('s4','s8'); % smoothing kernel
D.seg_array    = {'rp1','rp2'};   % use both gm and wm; or {'rp1'} for gm only

% run BA_data2mat
BA_data2mat(D);

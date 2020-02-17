%% Prepare
data_root = '/media/sakkol/HDD1/HBML/';
project_name = 'Speech_Perception';
sbj_ID = 'NS148';
Sbj_Metadata = makeSbj_Metadata(data_root, project_name, sbj_ID); % 'SAkkol_Stanford'

% Get params directly from BlockList excel sheet
curr_block = Sbj_Metadata.BlockLists{2}
params = create_Params(Sbj_Metadata,curr_block)

%% Run quick behavioral analysis
SP_beh_analysis(Sbj_Metadata,curr_block)

%% Import
[ecog] = TDT2ecog(params);
ecog.params=params;
% data=TDTbin2mat(params.directory);
% 
% save(fullfile(Sbj_Metadata.iEEG_data, curr_block, [curr_block '_TDT_data.mat']),'data','-v7.3');

%% Find bad channels using PSD
% find_bad_chans(ecog);
ecog = bad_chan_GUI([],ecog);
if size(ecog.bad_chans,2)>1,ecog.bad_chans = ecog.bad_chans';end % if bad_chans are in row order.

% Look at EEG, write bad channels to Xls-sheet
% cfg=[];
% cfg.channel = ecog.bad_chans;
% ecog_databrowser(ecog)

%% Check the good channels (write out bad channels, manually add them to ecog.bad_chans)
cfg = [];
cfg.viewmode = 'vertical';
cfg.blocksize = 20;
cfg.preproc.bsfilter       = 'yes';
cfg.preproc.bsfiltord      = 3;
cfg.preproc.bsfreq         = [59 61; 119 121; 179 181];
% cfg.preproc.bsfreq         = [59 61; 119 121; 179 181; 200 1000]; %sabina (visualisation purposes only, for noisy data)
cfg.preproc.demean         = 'yes';
good_chns = get_good_chans(ecog,2);
temp = ecog.ftrip;
temp.label = ecog.ftrip.label(good_chns);
temp.trial{1} = ecog.ftrip.trial{1}(good_chns,:);
temp.nChans = length(good_chns);
cfg = ft_databrowser(cfg, temp);

%% If you added bad (or SOZ, spikey, out) chans to xls. Read xls in again
% this will overwrite several fields in the ecog structure
% [labelfile,ecog] = read_labelfile(params.labelfile,ecog);
% if you don't want to be asked if you'd want to overwrite.
[labelfile,ecog] = read_labelfile(params.labelfile,ecog,1); 

%% Write the bad channels seen in this block
% ecog.bad_chans = [ecog.bad_chans; {'RPs15';'RFp2';'RFp3';'RFp4';'RHs11';'RHs13';'RPc13'}];%;'Second';'In Column Order'}];
select_bad_chans

save(fullfile(Sbj_Metadata.iEEG_data, curr_block, [curr_block '_ecog.mat']),'ecog','-v7.3');

%% If needed: check for threshold
% figure; plot(ecog.analog.trial{1}(2,:));
% title('Check for threshold');

%% Event onsets
% load behavioral
beh_data = load(fullfile(Sbj_Metadata.behavioral_root,curr_block,[curr_block '.mat']));
tmp_events = cell2table(beh_data.events_cell);
tmp_events.Properties.VariableNames(1:end) = {'Sentence_Codes','Sentences','Cond_code','Condition','Stimuli','cfg'};

% Analog 2 digital of the noise channel
refract_tpts = floor(10*ecog.analog.fs);
thr_ampl = 0.01; % amplitude threshold
noise_ch = ecog.analog.trial{1}(2,:);
digital_trig_chan=analog2digital_trig(noise_ch,thr_ampl,refract_tpts,0);
analog_fs = ecog.analog.fs;

% remove extra digital channel pulses based on sound length
trial_onsets_tpts=find(digital_trig_chan==1);
for i=1:length(tmp_events.Sentence_Codes)
    curr_stimdur = length(tmp_events.Stimuli{i})/24000; % in seconds; events file is 24KHz, recording may be different
    trial_dur = curr_stimdur*floor(ecog.analog.fs); % according to recording time stamps
    trial_onsets_tpts(trial_onsets_tpts>trial_onsets_tpts(i) & trial_onsets_tpts<trial_onsets_tpts(i)+trial_dur) = [];
    trial_end_tpts(i,1) = trial_onsets_tpts(i) + trial_dur;
    trial_durs(i,1) = trial_dur;
end

% plot events
figure('Units','normalized','Position', [0 0  1 .5]);
plot(1/analog_fs:1/analog_fs:length(noise_ch)/analog_fs,noise_ch); hold on
for i=1:length(trial_onsets_tpts)
    plot([trial_onsets_tpts(i)/analog_fs trial_onsets_tpts(i)/analog_fs],[-2 2])
end
title([num2str(length(trial_onsets_tpts)) ' onsets found']);
xlabel('Time (s)')
print(fullfile(Sbj_Metadata.iEEG_data,curr_block,'PICS','events.jpg'),'-djpeg','-r300')


% Get all events
t=find(digital_trig_chan==1);
pulse_spacing = 1000;
[ev_code, ev_start_tpt]=read_event_codes(digital_trig_chan,pulse_spacing);

% plot events
figure; plot(noise_ch); hold on
for i=1:length(t)
    plot([t(i) t(i)],[-2 2])
end
plot(ev_start_tpt,noise_ch(ev_start_tpt),'*g')
title([num2str(length(ev_code)) ' bursts found, with these burst lengths: ' num2str(unique(ev_code))]);
print(fullfile(Sbj_Metadata.iEEG_data,curr_block,'PICS','events.jpg'),'-djpeg','-r300')

%% Create each event point
% trial onsets and ends
% convert event time from Accl recording to EEG recording sampling rate
% (should be in column)
trial_onsets = (trial_onsets_tpts'/ecog.analog.fs);
trial_ends = (trial_end_tpts/ecog.analog.fs);
trial_durs = trial_ends-trial_onsets;


% prespeech part lengths (depending on if it is slow or fast)
% (this may be needed, because there may be delay before speech starts)
prespeech_noise_length = 0.5; % in seconds
curr_blockinfo = params.CurrBlockInfo;
if strcmp(curr_blockinfo.slowVSfast,'slow')
    prestim_att_length = 73093/24000; % in secs
elseif strcmp(curr_blockinfo.slowVSfast,'fast')
    prestim_att_length = 50848/24000; % in secs
end

speech_onsets = trial_onsets+repmat(prespeech_noise_length+prestim_att_length,size(trial_onsets));

% word,syllable and phoneme onsets
tmp = load('English_all_info.mat');all_info_table = tmp.all_info_table;clear tmp
for t = 1:length(tmp_events)
    curr_onset_info = all_info_table(strcmpi(all_info_table.sentence,tmp_events.Sentences(t)),:);
    
    
    
    
    
    
    
    
end


%% Collect trial events
fs = ecog.ftrip.fsample;
prespeech_ends = (prespeech_ends)/fs;
trial_ends = trial_ends/fs;
speech_onsets = speech_onsets/fs;
events = tmp_events(:,[3,4,1,2]);
events = [events,array2table(trial_onsets),array2table(prespeech_ends),...
    array2table(speech_onsets),array2table(trial_ends),array2table(stim_length)];

ecog.events = events;

%% trial based rejection
% Notch filter, demean
cfg=[];
cfg.demean         = 'yes';
cfg.bsfilter       = 'yes';
cfg.bsfiltord      = 3;
cfg.bsfreq         = [59 61; 119 121; 179 181];
cont_notched = ft_preprocessing(cfg,ecog.ftrip);

% speech onset locked
pre = 4; % seconds (prespeech part is 3.5455 seconds)
post = 6; % seconds (longest trial is ~8.5 seconds)
trl_trg           = [];
trl_trg(:,1)      = floor( events.speech_onsets*fs - fs*pre );
trl_trg(:,2)      = floor( events.speech_onsets*fs + fs*post );
trl_trg(:,3)      = floor( -pre*fs );

% Epoch
cfg      = [];
cfg.trl  = trl_trg;
trials_all  = ft_redefinetrial(cfg,cont_notched);

cfg=[];
cfg.method = 'summary';
cfg.keepchannel = 'yes';
cfg.channel = good_chns; % assuming bad channels are the same across blocks!!
cfg.metric = 'zvalue';
cfg.keeptrial = 'no';
trials_clean = ft_rejectvisual(cfg,trials_all);

%% if there were bad trials, take note here and remove them from further saving
bad_trials_idx = [3, 5];
all_idx = (1:length(trl_trg))';
good_trials_idx = all_idx(~ismember(all_idx,bad_trials_idx));
events = events(good_trials_idx,:);

%% Create info.mat file

% run if corr sheet doesn't include elecInfo:
% cfg=[];
% cfg.subj_folder = '/media/sakkol/HDD1/HBML/DERIVATIVES/freesurfer/NS148';
% cfg.fsaverage_dir = '/media/sakkol/HDD1/HBML/DERIVATIVES/freesurfer/fsaverage';
% cfg.FS_atlas_info = '/media/sakkol/HDD1/HBML/DERIVATIVES/freesurfer/Freesurfer_Atlas_Labels.xlsx';
% sbj_name = 'NS148';
% create_elecInfo(sbj_name, cfg)

% create info variable:
cfg=[];
cfg.events = events;
cfg.ecog = ecog;
cfg.corr_sheet = ecog.params.labelfile;
info = create_info(cfg);
save(fullfile(Sbj_Metadata.iEEG_data,curr_block,[curr_block '_info.mat']),'info');

save(fullfile(params.directoryOUT, [params.filename '_ecog.mat']),'ecog','-v7.3');
%% Re-reference
% Average ref
plot_stuff=0;
ignore_szr_chans=1;
ecog_avg=ecog_avg_ref(ecog,plot_stuff,ignore_szr_chans);
save(fullfile(Sbj_Metadata.iEEG_data, curr_block, [curr_block '_ecog_avg.mat']),'ecog_avg','-v7.3');

% Also BIPOLAR reference
ecog_bp=ecog_bipolarize(ecog);
save(fullfile(Sbj_Metadata.iEEG_data, curr_block, [curr_block '_ecog_bp.mat']),'ecog_bp','-v7.3');
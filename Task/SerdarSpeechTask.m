%% Temporary Speech Perception Script

% Serdar Akkol
% Noah Markowitz
% Stephan Bickel
% Human Brain Mapping Lab
% North Shore University Hospital
% September 2019
%% Preliminary Experimental Startup

% Pre-Experiment Items
clear all
commandwindow;                                                              % Typed Characters Appear in Command Window 

% Create and Locate Directory
if ~exist([pwd filesep 'log'],'dir'); mkdir([pwd filesep 'log']); end
curr_dir=pwd;
main_stim_loc = fullfile(curr_dir,'main_stim_loc');

% Experimental Setup Settings
Screen('Preference', 'SkipSyncTests', 1); % Setup Screen
par.textcolor = 255;                                                        % Text appears white
par.textsize = 60;                                                          % Text font size
par.cross_length = 40;                 % Size in pixels
par.N_entrain_stim = 4;                                                   % Number of entrainment sounds prior to the probe 
par.eeg_pPort = 'DFF8';                                                     % For parallel port
par.port_id = '/dev/tty.usbmodem14201';                     % Something like '/dev/tty.usbmodem14101' for Mac and something like 'COM4' for Windows

%% Prompt for settings
non_acceptable = 1;
dlg_title = 'Enter information';
while non_acceptable
    prompt = {'Run ID',...
        'Slow (1) vs Fast (2)',...
    'TTL Pulse (1 = None, 2 = MMB, 3 = Parallel Port)'};
    def = {'B1_NS001', '1', '1'};
    answer = inputdlg(prompt,dlg_title,1,def);
    
    if isempty(answer); errordlg('Exiting task. Rerun script for dialogue', 'Aborting'); return; end
    
    par.runID = answer{1};
    slowVSfast = str2double(answer{2});
    ttl_sender = str2double(answer{3});
    log_dir = [curr_dir filesep 'log' filesep par.runID];
    
    % Put in bits that checks to make sure input is acceptable
    if exist(log_dir,'dir')
        dlg_title = 'Run ID exists already!';
        non_acceptable = 1;
    elseif ~ismember(slowVSfast,[1, 2])
        dlg_title = 'Invalid choice for slow or fast for threshold!';
        non_acceptable = 1;
    elseif ~ismember(ttl_sender,[1, 2,3])
        dlg_title = 'Invalid choice for TTL sender!';
        non_acceptable = 1;
    else
        non_acceptable = 0;
    end
        
end

%% Setup second part

% Create directory structure to store data
mkdir(log_dir);                                                           % General directory
save_filename = [log_dir filesep par.runID];                  % The file that will store the end results
tmp_dir = fullfile(log_dir, 'tmp');
mkdir(tmp_dir);    % Temporary storage

% Anonymous functions for TTL
if ttl_sender == 1
    send_ttl = @(pulse_code, ttl_handle) pulse_code*2;%display('No pulse sent');
    port_handle = 0; 
elseif ttl_sender == 2  % Set up TTLs for MMB Trigger box
    try
        port_handle = serial(par.port_id);
        set(port_handle,'BaudRate',9600); % 9600 is recommended by Neurospec
        fopen(port_handle);
        send_ttl = @(pulse_code, ttl_handle) fwrite(ttl_handle, pulse_code);
    catch
        error('MMB No working!');
    end
elseif ttl_sender == 3 % Set TTLs for parallel port
        eeg_obj = io64;                                   % obj = io32;
        eeg_status = io64(eeg_obj);               % stat = io32(obj);
        port_handle = hex2dec(par.eeg_pPort); 
        send_ttl = @(pulse_code, ttl_handle) io64(eeg_obj,ttl_handle, pulse_code);
end

%% Setup Psychtoolbox and Screen
try

PsychDefaultSetup(2);
HideCursor;
% Setup Screen and
screenid = max(Screen('Screens')); %Change back to maximum after finished testing; min will make the default the secondary display
[scresw, scresh]=Screen('windowSize',screenid); % Get screen resolution
center = [scresw scresh]/2; % Center of screen

% Setup Cross
xCenter = (scresw)/2;
yCenter = (scresh)/2;
CrossArmLength = par.cross_length;
CrossWidth = 6;
xCoords = [-CrossArmLength CrossArmLength 0 0];                             % Set Center of Cross, x
yCoords = [0 0 -CrossArmLength CrossArmLength];                             % Set Center of Cross, y
cross_Coords = [xCoords; yCoords];

% Retrieves color codes for black and white and grey.
black = BlackIndex(screenid);
white = WhiteIndex(screenid);
grey = (black + white) / 2;
if round(grey)==white; grey=black; end

%%% For debugging make screen small (comment this, use 2nd line for the real deal)
% [window winRect] = Screen('Openwindow', screenid, grey,[0 0 640 480]);
[window winRect] = Screen('Openwindow', screenid, grey);

% Set text parameters
Screen('TextFont',window,'Times');
Screen('TextSize',window,par.text_size);

% Setup PsychPortAudio and Sounds
InitializePsychSound(1);                          % Initialize Sound Driver
nrchannels = 2;                                     % Number of Channels
fs = 24000;                                          %Frequency of Sampling
repetitions = 1;                                     % Number of Times to Play Sound Each Time (Keep at 1)
startCue = 0;                                        % Start Immeadiately
pahandle = PsychPortAudio('Open', [], 1, 1, fs, nrchannels); % Open Psych-Audio Port
PsychPortAudio('Volume', pahandle, 1);
waitforDeviceStart = 1;                                                      % Integrate Device and Sound Driver

%% Adaptation
% SA: I'll put several example sounds to play, without noise. Their sounds
% are going to be ready to play. Just couple of introduction may be needed.
% 1. Intro:
%   a. 'You will be listening simple sentences composed of 5 words'
%   b. 'When you are ready, press space bar to start each sentence'
% 2. Loop for 30 stimuli (in a cell structure with same order for each
% patient)

% Load all the stimuli for the 'Adaptation Phase' from directory
% called 'adaptation_sounds'
if slowVSfast == 1
    adaption_sounds_dir = fullfile(main_stim_loc, 'adaptation_sounds_slow');
elseif slowVSfast == 2
    adaption_sounds_dir = fullfile(main_stim_loc, 'adaptation_sounds_fast');
end
list_adaptation_sound_files = dir([adaption_sounds_dir filesep '*.wav']);
adaptation_sounds = cell(length(list_adaptation_sound_files),2);
for ss = 1:length(adaptation_sounds)
    adaptation_sounds{ss,1} = list_adaptation_sound_files(ss).name;
    [y, ~] = audioread(fullfile(adaption_sounds_dir, list_adaptation_sound_files(ss).name));
    adaptation_sounds{ss,2} = y;
end

adaptation_intro_msg = ['You will be listening simple sentences composed of 5 words\n\n'...
    'When you are ready, press space bar to start each sentence'];

DrawFormattedText(window, adaptation_intro_msg,'center','center',par.text_color);
Screen('Flip',window);
KbWait(-1);

Screen('DrawLines', window, cross_Coords,CrossWidth, par.cross_color, [xCenter yCenter]);
Screen('Flip',window);

% Play the sounds
for trialN = 1:length(adaptation_sounds)
    PsychPortAudio('FillBuffer',pahandle, adaptation_sounds{trialN,2});
    startTime = PsychPortAudio('Start', pahandle, repetitions, startCue, waitforDeviceStart);
    send_ttl(255, port_handle);
    status = PsychPortAudio('GetStatus', pahandle);
    while GetSecs < status.EstimatedStopTime; continue; end; send_ttl(0, port_handle); WaitSecs(1); % Wait until audio ends and then wait another 1sec
    [time_trial_end, key, ~] = KbWait(-1);
    if strcmp(KbName(key), 'ESCAPE'); break; end
end
%% Threshold:
% SA: I need to work on this
% Probably same as adaptation, with set group of sentences with 3 different
% SNR levels. If that is, we can use a similar loop as in previous section

% Looping for threshold audio
% Load all the stimuli for the 'Adaptation Phase' from directory
% called 'adaptation_sounds'
if slowVSfast == 1
    threshold_sounds_dir = fullfile(main_stim_loc, 'threshold_sounds_slow');
elseif slowVSfast == 2
    threshold_sounds_dir = fullfile(main_stim_loc, 'threshold_sounds_fast');
end
list_threshold_sound_files = dir([threshold_sounds_dir filesep '*.wav']);
threshold_sounds = cell(length(list_threshold_sound_files),2);
for ss = 1:length(threshold_sounds)
    threshold_sounds{ss,1} = list_threshold_sound_files(ss).name;
    [y, ~] = audioread(fullfile(threshold_sounds_dir, list_threshold_sound_files(ss).name));
    threshold_sounds{ss,2} = y;
end

threshold_intro_msg = ['Now, you will listen similar sentences embedded in noise\n\n'...
    'Please try to catch the sentence coming after\n'...
    '''Please pay attention and remember this sentence''\n\n'...
    'When you are ready, press space bar to start each sentence'];

DrawFormattedText(window, threshold_intro_msg,'center','center',par.text_color);
Screen('Flip',window);
KbWait(-1);

Screen('DrawLines', window, cross_Coords,CrossWidth, par.cross_color, [xCenter yCenter]);
Screen('Flip',window);

% Play the sounds
for trialN = 1:length(adaptation_sounds)
    PsychPortAudio('FillBuffer',pahandle, adaptation_sounds{trialN,2});
    startTime = PsychPortAudio('Start', pahandle, repetitions, startCue, waitforDeviceStart);
    send_ttl(255, port_handle);
    status = PsychPortAudio('GetStatus', pahandle);
    while GetSecs < status.EstimatedStopTime; continue; end; send_ttl(0, port_handle); WaitSecs(1); % Wait until audio ends and then wait another 1sec
    [time_trial_end, key, ~] = KbWait(-1);
    if strcmp(KbName(key), 'ESCAPE'); break; end
end


% Threshold estimation
% Input accuracies for each SNR
if slowVSfast == 1
   threshold_accr = inputdlg({'SNR = -8:','SNR = -4:','SNR = 0:'},'Please input how many words were correct for each SNR!');
data_threshold =    [...
    -8,   str2double(threshold_accr{1}),   50.0000;...
    -4,   str2double(threshold_accr{2}),   50.0000;...
    0,   str2double(threshold_accr{3}),   50.0000];
elseif slowVSfast == 2
    threshold_accr = inputdlg({'SNR = -6:','SNR = -2:','SNR = 2:'},'Please input how many words were correct for each SNR!');
data_threshold =    [...
    -6,   str2double(threshold_accr{1}),   50.0000;...
    -2,   str2double(threshold_accr{2}),   50.0000;...
    2,   str2double(threshold_accr{3}),   50.0000];
end



options             = [];   % initialize as an empty struct
options.sigmoidName = 'norm';   % normal Gaussian curve as the sigmoid
% options.expType     = '4AFC'; % ours is not forced choice, so  no input should be given
options.threshPC       = .7;

result = psignifit(data_threshold,options);
plotPsych(result);
current_SNR = getThreshold(result,0.7)

%% Real deal
% Creating events: description of output:
% first column is Code of sentence; second is Sentence itself; third and
% fourth are Condition code and name; fifth is stimulus which will be given
% and sixth is cfg input to stim_creatorv2 (saving this to be on the safer side.)
events_cell = event_creator(main_stim_loc,slowVSfast,current_SNR);

%% Loop for events_cell
% 1. Intro:
%   a. 'Now, you will listen similar sentences' stays for 3sec
%   b. 'Please try to attend and tell us what was the sentence' stays for 3sec
%   c. 'To start a new sentence, press space bar!' stays for 3sec
% 2. Loop starts:
% 3. Cross hair comes, stays as long as stimulus ends. Also there is going
% to be the code of the stimulus in the lower left corner of the screen.
% This code is the first column of events_cell. It is a note for
% experimenter to check the sheet and find the sentence.
% 4. Button press
% 5. After stim ends, 'What was the sentence?' stays for 2 sentence.
% 6. Cross hair comes. End of loop.
% 7. After loop ends, 'Thank you for your time!'

real_deal_msg = ['Now, you will listen similar sentences\n\n'...
   'Please try to attend and tell us what was the sentence\n\n'...
   'To start a new sentence, press space bar!'];

DrawFormattedText(window, real_deal_msg,'center','center',par.text_color);
Screen('Flip',window);
KbWait(-1);
if strcmp(KbName(key), 'ESCAPE'); return; end

% Start loop through events_cell
for trialN = 1:length(events_cell)
    % Set sound and code for this trial
    this_trial_sounds = events_cell{trialN,5};
    this_trial_code = events_cell{trialN,1};
    
    % Create cross and write code to screen for this trial
    Screen('DrawLines', window, cross_Coords,CrossWidth, par.cross_color, [xCenter yCenter]);
    DrawFormattedText(window, this_trial_code,scresw * 0.2,scresh * 0.8,par.text_color);
    Screen('Flip', window);
    
    % Play sound for this trial
    PsychPortAudio('FillBuffer',pahandle, this_trial_sounds);
    startTime = PsychPortAudio('Start', pahandle, repetitions, startCue, waitforDeviceStart);
    send_ttl(255, port_handle);
    status = PsychPortAudio('GetStatus', pahandle);
    while GetSecs < status.EstimatedStopTime; continue; end; send_ttl(0, port_handle); WaitSecs(1); % Wait until audio ends and then wait another 1sec
    
    % Ask for answer from participant
    DrawFormattedText(window, 'What was the sentence?','center','center',par.text_color);
    DrawFormattedText(window, events_cell{trialN,1},scresw * 0.2,scresh * 0.8,par.text_color);
    Screen('Flip',window);
    KbWait(-1);
    if strcmp(KbName(key), 'ESCAPE'); break; end
end

%% End of task

% Save everything
save([save_dir filesep runID '_events_cell.mat'],'events_cell','result')
save([save_filename '.mat'], 'par') 

% Draw thank you msg
end_msg = 'Thank you for your time!';
DrawFormattedText(window, end_msg,'center','center',par.text_color);
Screen('Flip',window);
WaitSecs(3);

% If MMB trigger box was used, close it
if ttl_sender == 2
    fclose(port_handle)
    delete(port_handle)
    clear port_handle
end

% Close Experiment
ListenChar(0);                                                               % Characters Show in Command Window
ShowCursor();                                                               % Shows Cursor
PsychPortAudio('Close', pahandle);                                 % Close the audio device
Screen('CloseAll');                                                         % Close PsychToolbox Screen
sca

catch
    
    ListenChar(0);                                                           % Characters Show in Command Window
    ShowCursor();                                                           % Shows Cursor
    PsychPortAudio('Close', pahandle);                             % Close the audio device
    Screen('CloseAll');                                                     % Close PsychToolbox Screen
    sca
    ple                                                                     % Print Last Error
end
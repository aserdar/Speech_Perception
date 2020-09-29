%% Script to run Isochronous version of Matrix Sentence based Speech in Noise Task (Matrix Speech Task, in short)
% This script combines English and Spanish versions of the task so that
% it'll be much easier to track and save changes.
%
% Serdar Akkol
% Noah Markowitz
% Stephan Bickel
% Human Brain Mapping Lab
% North Shore University Hospital
% September 2020
% Script is based on "Matrix_Speech_Task_masterScript.m"

%% Preliminary Experimental Startup

% Pre-Experiment Items
clear
commandwindow;                                                              % Typed Characters Appear in Command Window

addpath(genpath('Speech_Perception'));
% Create and Locate Directory
if ~exist([pwd filesep 'log'],'dir'); mkdir([pwd filesep 'log']); end
curr_dir=pwd;

% Experimental Setup Settings
par.textcolor = 255;                         % Text appears white
par.textsize = 60;                           % Text font size
par.cross_length = 40;                       % Size in pixels
par.cross_color = 255;
par.N_entrain_stim = 4;                      % Number of entrainment sounds prior to the probe
par.eeg_pPort = 'DFF8';                      % For parallel port
par.port_id = '/dev/ttyACM01';               % Something like '/dev/ttyACM01' for new Ubuntu laptop; or '/dev/tty.usbmodem14101' for Mac; or 'COM4' for Windows
par.rec_comp_mic = 1;                        % if wanting to record microphone from laptop
par.time = string(datetime('now'));          % save the date and time
[~, par.ComputerID] = system('hostname');    % save computer ID
par.PTB_fs = 44100;

%% Prompt for main settings
non_acceptable = 1;
dlg_title = 'Enter information';

while non_acceptable
    prompt = {'Run ID',...
        'Adaptation+Threshold (1) vs E-stim (2) vs Clean stimuli (3) vs Free-Recall (4) vs Free style (5)',...
        'English (1) vs Spanish (2)',...
        'TTL Pulse (1 = None, 2 = MMB, 3 = Parallel Port)'};
    def = {'B1_NS001','1','1','1'};
    answer = inputdlg(prompt,dlg_title,1,def);
    
    if isempty(answer); errordlg('Exiting task. Rerun script for dialogue', 'Aborting'); return; end
    
    par.runID = answer{1};
    thresVSreal = str2double(answer{2});
    EngvsSpa = str2double(answer{3});
    ttl_sender = str2double(answer{4});
    
    log_dir = fullfile(curr_dir, 'log', par.runID);
    % Put in bits that checks to make sure input is acceptable
    if exist(log_dir,'dir')
        dlg_title = 'Run ID EXIST ALREADY!';
        non_acceptable = 1;
    elseif ~ismember(EngvsSpa,[1, 2])
        dlg_title = 'Invalid choice for English vs Spanish!';
        non_acceptable = 1;
    elseif ~ismember(thresVSreal,[1, 2, 3, 4, 5])
        dlg_title = 'Invalid choice for threshold or e-stim or clean stimuli part!';
        non_acceptable = 1;
    elseif ~ismember(ttl_sender,[1, 2, 3])
        dlg_title = 'Invalid choice for TTL sender!';
        non_acceptable = 1;
    else
        non_acceptable = 0;
    end
    
end

%% Setup second part
% Create directory structure to store data
if ~exist(log_dir,'dir'),mkdir(log_dir),end                                % General directory
save_filename = [log_dir filesep par.runID];                               % The file that will store the end results

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
    eeg_obj = io64;                           % obj = io32;
    eeg_status = io64(eeg_obj);               % stat = io32(obj);
    port_handle = hex2dec(par.eeg_pPort);
    send_ttl = @(pulse_code, ttl_handle) io64(eeg_obj,ttl_handle, pulse_code);
end

% set where the stimuli will be found and the dialogs
if EngvsSpa == 1
    language='English';
    load('EnglishWordsInfo.mat','WordsInfo','avg_sig_pow','avg_noise_pow','words_table')
    adaptation_intro_msg = ['You will be listening simple sentences,\ncomposed of 4 words\n\n'...
        'When you are ready, \npress space bar to start sentences'];
    threshold_intro_msg = ['Now, you will listen similar sentences,\nembedded in noise\n\n'...
        'Please try to catch the sentence coming after\n'...
        '''now catch these words''\n\n'...
        'When you are ready, \npress space bar to start each sentence'];
    real_deal_msg = ['Again, you will listen similar sentences,\nembedded in noise\n\n'...
        'Please try to catch the sentence coming after\n'...
        '''now catch these words''\n\n'...
        'When you are ready, \npress space bar to start each sentence'];
    end_msg = 'Thank you for your time!\n\nSaving data...';
    what_sentence = 'What was the sentence?';
    pass_list_msg = 'Catch: ';
    pass_list_intro_msg = ['You will listen series of words\n\n'...
        'Please try to catch the word\n'...
        'in the beginning of each series\n'...
        'Press space bar to start'];
    word_catch_msg = 'Was that present?';
elseif EngvsSpa == 2
    language='Spanish';
    load('SpanishWordsInfo.mat','WordsInfo','avg_sig_pow','avg_noise_pow','words_table')
    adaptation_intro_msg = ['Escucharás oraciones simples,\ncompuestas de 4 palabras\n\n'...
        'Cuando esté listo,\npresione la barra espaciadora\npara comenzar cada oración'];
    threshold_intro_msg = ['Otra vez, escuchará oraciones similares,\nincrustadas en el ruido\n\n'...
        'Por favor, trata de entender la frase que viene después\n'...
        '''................................''\n\n'...
        'Cuando esté listo,\npresione la barra espaciadora\npara comenzar cada oración'];
    real_deal_msg; %%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    end_msg = '¡Gracias por tu tiempo!\n\nGuardando datos...';
    what_sentence = '¿Cuál fue la oración?';
    pass_list_msg; %%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    word_catch_msg; %%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end

%% Create the events
% Description of events_cell:
% first column is the sound to play; second is cfgs, the output from
% trial_creator function; third is cond_info, the condition info.

tmp=load('default_conditions.mat');
if thresVSreal==1 % adapt + thresh
%     Adaptation + Thresholding:
%     There will be 10 trials, composed of 5 sentences without noise. Sentences
%     are preselected and generated here (so there is no need to save any
%     file, "WordsInfo" has everything). There will be 2 lines saying:
%     1. Intro:
%       a. 'You will be listening simple sentences composed of 4 words'
%       b. 'When you are ready, press space bar to start each sentence'
%     After adaptation (which it self can be used), there will be threshold
%     block with 30 sentences generated with 3 different  SNR levels (+2, -2,
%     -6). Words here are also preselected and generated rapidly here.
    
    cfgs_for_adapt = tmp.(['cfgs_for_adapt_' language]);
    cfgs_for_thresh = tmp.(['cfgs_for_thresh_' language]); 
    for c = 1:length(cfgs_for_adapt)
        cfgs_for_adapt{c}.language = language;
        events_table1{c,1} = trial_creator(cfgs_for_adapt{c});
    end
    for c = 1:length(cfgs_for_thresh)
        cfgs_for_thresh{c}.language = language;
        events_table2{c,1} = trial_creator(cfgs_for_thresh{c});
    end
    events_cell=[events_table1;events_table2];
    events_table = table;
    events_table.trials = events_cell;
    events_table.cfgs = [cfgs_for_adapt;cfgs_for_thresh];
    events_table.conds = [repmat({'adaptation'},[10,1]);repmat({'threshold'},[30,1])];
    clear events_table1 events_table2 cfgs_for_adapt cfgs_for_thresh tmp
    
elseif thresVSreal==2 % isochronous version of matrix sentence task
    % There are total of 6 conditions:
    % 1. isochronous-clean
    % 2. isochronous-in-noise - no e-stim
    % 2. achronous-clean
    % 4. achronous-in-noise - no e-stim
    % 5. isochronous-in-noise - with e-stim
    % 6. achronous-in-noise - with e-stim
    % E-stim conditions may be removed and other conditions may be added.
    % All trials are composed of 1 attention sentence and 1 4-word target
    % sentence. Each condition has 30 trials.
    [events_table] = events_wrapper([],language,[],'iso_mat_24');
    
elseif thresVSreal==3
    % This is a passive listening of isochronous sentences. Each condition
    % has 10 trials.
    [events_table] = events_wrapper([],language,[],'passive_5sent');
    
elseif thresVSreal==4 % free recall !! Needs some more work !!
    [events_table] = events_wrapper([],language,[],'FreeRecall_3sent');
    
elseif thresVSreal==4 % free style :D 
    [events_table] = events_wrapper([],language,[],[]);
    
end
close all

%% Setup Psychtoolbox and Screen
try

% SOUND VOLUME SETTING FIRST
sound_good=0;
while sound_good~=1
    obj = audioplayer(events_table.trials{1},par.PTB_fs);
    playblocking(obj);
    sounds_good = questdlg('Sounds good?', ...
        'Is the sound level good?', ...
        'Good','Too high','Too low','Good');
    sound_good = strcmp(sounds_good,'Good');
end
words_to_catch=cell(size(events_table,1),1);
responses = cell(size(events_table,1),1);

startscreen_now

% Play the sounds
for trialN = 1:size(events_table,1)
    if trialN==1,WaitSecs(.5);end % in the first, give a little pause, it may be very scary at first
    
    % Choose dialog messages
    if thresVSreal==1 && trialN==1
        % at the start of the adaptation part
        DrawFormattedText(window, adaptation_intro_msg,'center','center',par.textcolor);
        Screen('Flip',window);
        KbWait(-1);
        if strcmp(KbName(key), 'ESCAPE'); return; end
        % put cross hair
        Screen('DrawLines', window, cross_Coords,CrossWidth, par.cross_color, [xCenter yCenter]);
        Screen('DrawText',window,num2str(trialN),winRect(3)/20,winRect(4)*0.9,par.textcolor);
        Screen('Flip',window);
    elseif thresVSreal==1 && trialN==11
        % put the dialog message
        DrawFormattedText(window, threshold_intro_msg,'center','center',par.textcolor);
        Screen('Flip',window);
        KbWait(-1);
        if strcmp(KbName(key), 'ESCAPE'); return; end
        % draw cross hair
        Screen('DrawLines', window, cross_Coords,CrossWidth, par.cross_color, [xCenter yCenter]);
        Screen('DrawText',window,num2str(trialN),winRect(3)/20,winRect(4)*0.9,par.textcolor);
        Screen('Flip',window);
    elseif thresVSreal==1
        % draw cross hair
        Screen('DrawLines', window, cross_Coords,CrossWidth, par.cross_color, [xCenter yCenter]);
        Screen('DrawText',window,num2str(trialN),winRect(3)/20,winRect(4)*0.9,par.textcolor);
        Screen('Flip',window);
    elseif thresVSreal==2 && trialN==1
        DrawFormattedText(window, real_deal_msg,'center','center',par.textcolor);
        Screen('Flip',window);
        [~, key, ~] = KbWait(-1);
        if strcmp(KbName(key), 'ESCAPE'); return; end
        % draw cross hair
        Screen('DrawLines', window, cross_Coords,CrossWidth, par.cross_color, [xCenter yCenter]);
        Screen('Flip',window);
    elseif thresVSreal==3 % put intro message for passive listening and the word to catch
        if trialN==1
            DrawFormattedText(window, pass_list_intro_msg,'center','center',par.textcolor);
            Screen('Flip',window);
            [~, key, ~] = KbWait(-1);
            if strcmp(KbName(key), 'ESCAPE'); return; end
        end
        words_to_catch{trialN} = words_table{randi(6),randi(5)}{:};
        DrawFormattedText(window, [pass_list_msg words_to_catch{trialN}],'center','center',par.textcolor);
        Screen('Flip',window);
        [~, key, ~] = KbWait(-1);
        if strcmp(KbName(key), 'ESCAPE'); return; end
        % draw cross hair
        Screen('DrawLines', window, cross_Coords,CrossWidth, par.cross_color, [xCenter yCenter]);
        Screen('Flip',window);
    end
    
    PsychPortAudio('FillBuffer',pahandle, events_table.trial{trialN});
    startTime{trialN,1} = PsychPortAudio('Start', pahandle, repetitions, startCue, waitforDeviceStart);
    send_ttl(255, port_handle);
    [actualStartTime{trialN,1}, ~,~,estStopTime{trialN,1}] = PsychPortAudio('Stop',pahandle,1,1);
    send_ttl(0, port_handle); 
    WaitSecs(0.25); % Wait until audio ends and then wait another 0.25 sec
    
    if (thresVSreal == 1 && trialN > 10) || thresVSreal == 2
        % Prompt for answer from participant. Show message for 1.75sec
        DrawFormattedText(window, what_sentence,'center','center',par.textcolor);
        Screen('DrawText',window,num2str(trialN),winRect(3)/20,winRect(4)*0.9,par.textcolor);
        Screen('Flip',window);
        WaitSecs(1.5);
        % this time period when patient answers, then wait for input to start next trial
        [time_trial_end{trialN,1}, key, ~] = KbWait(-1);
        if strcmp(KbName(key), 'ESCAPE'); break; end
    elseif thresVSreal==3 % ask for if the word was present
        DrawFormattedText(window, word_catch_msg,'center','center',par.textcolor);
        Screen('Flip',window);
        [time_trial_end{trialN,1}, key, ~] = KbWait(-1);
        responses{trialN} = key;
        if strcmp(KbName(key), 'ESCAPE'); return; end
        % draw cross hair
        Screen('DrawLines', window, cross_Coords,CrossWidth, par.cross_color, [xCenter yCenter]);
        Screen('Flip',window);
    else
        Screen('DrawLines', window, cross_Coords,CrossWidth, par.cross_color, [xCenter yCenter]);
        Screen('Flip', window);
        [time_trial_end{trialN,1}, key, ~] = KbWait(-1);
        if strcmp(KbName(key), 'ESCAPE'); break; end
    end
    
end

% Draw thank you msg
DrawFormattedText(window, end_msg,'center','center',par.textcolor);
Screen('Flip',window);
WaitSecs(1.5);

% gather the times
all_times=[];
all_times.startTime = startTime;startTime=[];
all_times.estStopTime = estStopTime;estStopTime=[];
all_times.actualStartTime=actualStartTime;actualStartTime=[];
all_times.time_trial_end = time_trial_end;time_trial_end=[];

% Save the info
save([save_filename '.mat'], 'par', 'EngvsSpa', 'events_table', 'all_times', 'thresVSreal', 'words_to_catch', 'responses')

%% End of task

% If MMB trigger box was used, close it
if ttl_sender == 2
    fclose(port_handle);
    delete(port_handle);
    clear port_handle
end

% Close Experiment
ListenChar(0);                                                              % Characters Show in Command Window
ShowCursor();                                                               % Shows Cursor
PsychPortAudio('Close', pahandle);                                          % Close the audio device
Screen('CloseAll');                                                         % Close PsychToolbox Screen
sca

%% IF ANY ERRORS

catch
    ListenChar(0);                                                          % Characters Show in Command Window
    ShowCursor();                                                           % Shows Cursor
    %PsychPortAudio('Close', pahandle);                                     % Close the audio device
    Screen('CloseAll');                                                     % Close PsychToolbox Screen
    sca
    ple                                                                     % Print Last Error
end
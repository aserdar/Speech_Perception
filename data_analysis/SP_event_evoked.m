function SP_event_evoked(Sbj_Metadata,control_blocks,runagain)
% This is to get the mean of evoked responses (ERP and HFA) word heard
% vs others.

%% Select blocks to import
vars=who;
if ~ismember(vars,'control_blocks')
    control_blocks = select_cont_blocks(Sbj_Metadata);
end
if ~ismember(vars,'runagain')
    runagain = 1;
end
clear vars

%% bring in these blocks and combine only the control events
fprintf('These blocks are going to be used: %s\n',strjoin(control_blocks,', '))

save_folder = fullfile(Sbj_Metadata.results, strjoin(control_blocks,'_'));
if ~exist(save_folder,'dir'),mkdir(save_folder),end
% check if this has already been run
if ~exist(fullfile(save_folder,[strjoin(control_blocks,'_') '_control_wltERP.mat']),'file') || runagain
    for b = 1:length(control_blocks)
        curr_block = control_blocks{b};
        fprintf('...loading:%s\n',curr_block)
        
        % Load iEEG
        load(fullfile(Sbj_Metadata.iEEG_data, curr_block, [curr_block '_wlt.mat']))
        load(fullfile(Sbj_Metadata.iEEG_data,curr_block,[curr_block '_info.mat']))
        events = info.events;
        
        % Select only control events
        control_idx = events.Cond_code == 1;
        
        % Select ecog data
        cfg = [];
        cfg.trials = control_idx;
        [epoched_wlt.wlt] = ft_selectdata(cfg, epoched_wlt.wlt);
        curr_ERP = ft_selectdata(cfg, epoched_wlt);
        
        % from fourierspectrum to powerspectrum
        cfg = [];
        cfg.output='abs';
        cfg.keeptrials = 'yes';
        epoched_wlt.wlt=ft_freqdescriptives(cfg,epoched_wlt.wlt);
        
        % Select events
        events = events(control_idx,:);
        
        % Append to overall list
        if b == 1
            control_wlt = epoched_wlt.wlt;
            control_events = events;
            control_ERP = curr_ERP;
        else
            cfg = [];
            cfg.parameter  = 'powspctrm';
            control_wlt = ft_appendfreq(cfg, control_wlt, epoched_wlt.wlt);
            cfg = [];
            control_ERP = ft_appendtimelock(cfg,control_ERP,curr_ERP);
            control_events = [control_events;events];
        end
        clear epoched_wlt events info curr_ERP control_idx
    end
    
    save(fullfile(Sbj_Metadata.results, strjoin(control_blocks,'_'),[strjoin(control_blocks,'_') '_control_wltERP.mat']),'control_events','control_ERP','control_wlt','-v7.3')
else
    load(fullfile(Sbj_Metadata.results, strjoin(control_blocks,'_'),[strjoin(control_blocks,'_') '_control_wltERP.mat']),'control_events','control_ERP','control_wlt')
    
end

%%  Baseline correct time-freq data
cfg              = [];
cfg.baseline     = [-3.45 -3.05]; % seconds (prespeech part is 3.5455 seconds) [0.5sec + 3.0455sec]
cfg.baselinetype = 'db';
cfg.parameter    = 'powspctrm';
[control_wlt]         = ft_freqbaseline(cfg, control_wlt);

cfg              = [];
cfg.baseline     = [-3.45 -3.05];
cfg.channel      = 'all';
cfg.parameter    = 'trial';
control_ERP      = ft_timelockbaseline(cfg, control_ERP);

%% Separate conditions

fprintf('There are total of %d events\n',size(control_events,1))

corr_rspn_ERP_peakEnv = {[]};
no_rspn_ERP_peakEnv = {[]};
wrng_rspn_ERP_peakEnv = {[]};
corr_rspn_spect_peakEnv = {[]};
no_rspn_spect_peakEnv = {[]};
wrng_rspn_spect_peakEnv = {[]};

corr_rspn_ERP_peakRate = {[]};
no_rspn_ERP_peakRate = {[]};
wrng_rspn_ERP_peakRate = {[]};
corr_rspn_spect_peakRate = {[]};
no_rspn_spect_peakRate = {[]};
wrng_rspn_spect_peakRate = {[]};


wcorr_ind = 1;
wno_ind = 1;
wwrng_ind = 1;
scorr_ind = 1;
sno_ind = 1;
swrng_ind = 1;
fprintf('\nCurrent event:')



for t = 1:size(control_events,1)
    
    fprintf('-%d',t)
    % if only 1 correct answer, skip this trial
    if sum(strcmp(control_events.word_info{t}.response,'1')) < 2
        fprintf('Skipped')
        continue
    end
    
    % Separate peakEnv events
    % Collect fouri in a cell structure
    for pE = 1:length(control_events.peak_info{t}.peakEnv{1})
        
        % first check if the points are too close to each other
        if pE == length(control_events.peak_info{t}.peakEnv{1})
            % do nothing
        elseif control_events.peak_info{t}.peakEnv{1}(pE+1) - control_events.peak_info{t}.peakEnv{1}(pE) < 0.25
            continue
        end
        
        % check what is the response when that word was heard
        wword_resp = control_events.word_info{t}.response{...
            control_events.peak_info{t}.peakEnv{1}(pE)>=control_events.word_info{t}.onset & ...
            control_events.peak_info{t}.peakEnv{1}(pE)<control_events.word_info{t}.offset};
        
        % find closest timepoint for ERP
        cl_times = [nearest(control_ERP.time, control_events.peak_info{t}.peakEnv{1}(pE)-0.05)...
            nearest(control_ERP.time,control_events.peak_info{t}.peakEnv{1}(pE)+.5)];
        if strcmp(wword_resp,'1')
            corr_rspn_ERP_peakEnv{1}(wcorr_ind,:,:) = squeeze(control_ERP.trial(t,:,cl_times(1):cl_times(2)));
        elseif strcmp(wword_resp,'0')
            no_rspn_ERP_peakEnv{1}(wno_ind,:,:) = squeeze(control_ERP.trial(t,:,cl_times(1):cl_times(2)));
        else % wrong responses
            wrng_rspn_ERP_peakEnv{1}(wwrng_ind,:,:) = squeeze(control_ERP.trial(t,:,cl_times(1):cl_times(2)));
        end
        
        % find closest timepoint for HFA and spectrogram
        cl_times = [nearest(control_wlt.time, control_events.peak_info{t}.peakEnv{1}(pE)-0.05)...
            nearest(control_wlt.time,control_events.peak_info{t}.peakEnv{1}(pE)+.5)];
        if strcmp(wword_resp,'1')
            corr_rspn_spect_peakEnv{1}(wcorr_ind,:,:,:) = squeeze(control_wlt.powspctrm(t,:,:,cl_times(1):cl_times(2)));
            wcorr_ind = wcorr_ind+1;
        elseif strcmp(wword_resp,'0')
            no_rspn_spect_peakEnv{1}(wno_ind,:,:,:) = squeeze(control_wlt.powspctrm(t,:,:,cl_times(1):cl_times(2)));
            wno_ind = wno_ind+1;
        else % wrong responses
            wrng_rspn_spect_peakEnv{1}(wwrng_ind,:,:,:) = squeeze(control_wlt.powspctrm(t,:,:,cl_times(1):cl_times(2)));
            wwrng_ind = wwrng_ind+1;
        end
        
    end
    
    % Separate peakRate like different trials
    % Collect fouri in a cell structure
    for pR = 1:length(control_events.peak_info{t}.peakRate{1})
        
        % first check if the points are too close to each other
        if pR == length(control_events.peak_info{t}.peakRate{1})
            % do nothing
        elseif control_events.peak_info{t}.peakRate{1}(pR+1) - control_events.peak_info{t}.peakRate{1}(pR) < 0.25
            continue
        end
        
        % check what is the response when that word was heard
        wword_resp = control_events.word_info{t}.response{...
            control_events.peak_info{t}.peakRate{1}(pR)>=control_events.word_info{t}.onset & ...
            control_events.peak_info{t}.peakRate{1}(pR)<control_events.word_info{t}.offset};
        
        % find closest timepoint for ERP
        cl_times = [nearest(control_ERP.time, control_events.peak_info{t}.peakRate{1}(pR)-0.05)...
            nearest(control_ERP.time, control_events.peak_info{t}.peakRate{1}(pR)+.5)];
        if strcmp(wword_resp,'1')
            corr_rspn_ERP_peakRate{1}(scorr_ind,:,:) = squeeze(control_ERP.trial(t,:,cl_times(1):cl_times(2)));
        elseif strcmp(wword_resp,'0')
            no_rspn_ERP_peakRate{1}(sno_ind,:,:) = squeeze(control_ERP.trial(t,:,cl_times(1):cl_times(2)));
        else % wrong responses
            wrng_rspn_ERP_peakRate{1}(swrng_ind,:,:) = squeeze(control_ERP.trial(t,:,cl_times(1):cl_times(2)));
        end
        
        
        % find closest timepoint for HFA and spectrogram
        cl_times = [nearest(control_wlt.time, control_events.peak_info{t}.peakRate{1}(pR)-0.05)...
            nearest(control_wlt.time, control_events.peak_info{t}.peakRate{1}(pR)+.5)];
        if strcmp(wword_resp,'1')
            corr_rspn_spect_peakRate{1}(scorr_ind,:,:,:) = squeeze(control_wlt.powspctrm(t,:,:,cl_times(1):cl_times(2)));
            scorr_ind = scorr_ind+1;
        elseif strcmp(wword_resp,'0')
            no_rspn_spect_peakRate{1}(sno_ind,:,:,:) = squeeze(control_wlt.powspctrm(t,:,:,cl_times(1):cl_times(2)));
            sno_ind = sno_ind+1;
        else % wrong responses
            wrng_rspn_spect_peakRate{1}(swrng_ind,:,:,:) = squeeze(control_wlt.powspctrm(t,:,:,cl_times(1):cl_times(2)));
            swrng_ind = swrng_ind+1;
        end
    end
    
    
end
fprintf('\n')



%% Calculate ITPC
save_dir = fullfile(Sbj_Metadata.results, [strjoin(control_blocks,'_') '_v3']);
load(fullfile(save_dir, [strjoin(control_blocks,'_') '_ctrl_word_fouri.mat']),'fouri_of_words');
bwr = load('bwr_cmap.mat');

itpc = [];
for pp = 1:2 % first peakEnv second peakRate
    for cond = 1:2 % first correct second no response
        % get data
        if cond == 1 && pp ==1
            curr_fouri_all = fouri_of_words.corr_rspn_fouri_peakEnv{1};
        elseif cond == 2 && pp ==1
            curr_fouri_all = fouri_of_words.no_rspn_fouri_peakEnv{1};
        elseif cond == 1 && pp ==2
            curr_fouri_all = fouri_of_words.corr_rspn_fouri_peakRate{1};
        elseif cond == 2 && pp ==2
            curr_fouri_all = fouri_of_words.no_rspn_fouri_peakRate{1};
        end
        
        % compute inter-trial phase coherence (itpc) for each conditions
        tmp      = curr_fouri_all./abs(curr_fouri_all);    % divide by amplitude
        tmp      = sum(tmp,1);                            % sum angles across trials
        tmp      = abs(tmp)/size(curr_fouri_all,1);       % take the absolute value and normalize
        
        if isempty(tmp)
            sztmp = size(itpc);
            tmp = zeros(sztmp(3:5));
        end
        itpc(pp,cond,:,:,:) = squeeze(tmp);    % remove the first singleton dimension
        
    end
end


% for ITPC plot
load(fullfile(Sbj_Metadata.iEEG_data,Sbj_Metadata.BlockLists{1},[Sbj_Metadata.BlockLists{1} '_info.mat']),'info');


clear fouri_of_words pp cond tmp

%%

% corr_rspn_ERP_peakEnv = {[]};
% no_rspn_ERP_peakEnv = {[]};
% wrng_rspn_ERP_peakEnv = {[]};
% corr_rspn_spect_peakEnv = {[]};
% no_rspn_spect_peakEnv = {[]};
% wrng_rspn_spect_peakEnv = {[]};
%
% corr_rspn_ERP_peakRate = {[]};
% no_rspn_ERP_peakRate = {[]};
% wrng_rspn_ERP_peakRate = {[]};
% corr_rspn_spect_peakRate = {[]};
% no_rspn_spect_peakRate = {[]};
% wrng_rspn_spect_peakRate = {[]};

freq_ITPC = fouri_of_words.freq_band_dtls{1};
time_ITPC = linspace(-0.05,0.5,size(fouri_of_words.corr_rspn_fouri_peakEnv{1},4));
time_ERP = linspace(-0.05,0.5,size(corr_rspn_ERP_peakEnv{1},3));
freq_spec = control_wlt.freq;
time_spec = linspace(-0.05,0.5,size(corr_rspn_spect_peakEnv{1},4));

for ii = 70:150
    cl_freqs(ii) = nearest(control_wlt.freq, ii);
end

for el = 1:size(corr_rspn_ERP_word{1},1)
    
    figure('Units','normalized','Position', [0 0  1 1]);
    
    %% plot ERPs
    % plot single trials and average of corr - ERP - pR
    subplot(4,4,1)
    for_avg=squeeze(corr_rspn_ERP_peakRate{1}(:,el,:));
    plot(time_ERP,for_avg,'Color',[0.9412,0.9412,0.9412])
    hold on
    shadedErrorBar(time_ERP,mean(for_avg,1),stderr(for_avg),'lineprops','r')
    title([num2str(size(corr_rspn_ERP_peakRate{1},1)) ' correct response - peakRate locked - ERP'])
    xlim([time_ERP(1) time_ERP(end)])
    
    % plot single trials and average of no - ERP - pR
    subplot(4,4,5)
    for_avg=squeeze(no_rspn_ERP_peakRate{1}(:,el,:));
    plot(time_ERP,for_avg,'Color',[0.9412,0.9412,0.9412])
    hold on
    shadedErrorBar(time_ERP,mean(for_avg,1),stderr(for_avg),'lineprops','r')
    title([num2str(size(no_rspn_ERP_peakRate{1},1)) ' no response - peakRate locked - ERP'])
    xlim([time_ERP(1) time_ERP(end)])
    
    % plot single trials and average of corr - ERP - pE
    subplot(4,4,9)
    for_avg=squeeze(corr_rspn_ERP_peakEnv{1}(:,el,:));
    plot(time_ERP,for_avg,'Color',[0.9412,0.9412,0.9412])
    hold on
    shadedErrorBar(time_ERP,mean(for_avg,1),stderr(for_avg),'lineprops','r')
    title([num2str(size(corr_rspn_ERP_peakEnv{1},1)) ' correct response - peakEnv locked - ERP'])
    xlim([time_ERP(1) time_ERP(end)])
    
    % plot single trials and average of no - ERP - pE
    subplot(4,4,13)
    for_avg=squeeze(no_rspn_ERP_peakEnv{1}(:,el,:));
    plot(time_ERP,for_avg,'Color',[0.9412,0.9412,0.9412])
    hold on
    shadedErrorBar(time_ERP,mean(for_avg,1),stderr(for_avg),'lineprops','r')
    title([num2str(size(no_rspn_ERP_peakEnv{1},1)) ' no response - peakEnv locked - ERP'])
    xlim([time_ERP(1) time_ERP(end)])
    
    
    
    %% plot spectrograms
    % spectrogram of corr - pR
    subplot(4,4,2)
    avg_spec = squeeze(mean(corr_rspn_spect_peakRate{1}(:,el,:,:),1));
    imagesc(time_spec,freq_spec,avg_spec')
    axis xy
    % spectrogram of no - pR
    subplot(4,4,6)
    avg_spec = squeeze(mean(no_rspn_spect_peakRate{1}(:,el,:,:),1));
    imagesc(time_spec,freq_spec,avg_spec')
    axis xy
    % spectrogram of corr - pE
    subplot(4,4,10)
    avg_spec = squeeze(mean(corr_rspn_spect_peakEnv{1}(:,el,:,:),1));
    imagesc(time_spec,freq_spec,avg_spec')
    axis xy
    % spectrogram of no - pE
    subplot(4,4,14)
    avg_spec = squeeze(mean(no_rspn_spect_peakEnv{1}(:,el,:,:),1));
    imagesc(time_spec,freq_spec,avg_spec')
    axis xy
    
    
    
    
    % plot single trials and average of corr - HFA
    subplot(322)
    for c = 1:size(corr_rspn_powspec_word,1)
        plot(corr_rspn_powspec_word{c}(el,:),'Color',[0.9412,0.9412,0.9412])
        hold on
        tr_lenght(c,1) = size(corr_rspn_powspec_word{c},2);
    end
    for_avg=[];
    for c = 1:size(corr_rspn_powspec_word,1)
        for_avg(c,:) = [corr_rspn_powspec_word{c}(el,:),NaN(1,max(tr_lenght)-tr_lenght(c))];
    end
    shadedErrorBar(1:size(for_avg,2),nanmean(for_avg,1),nanstd(for_avg),'lineprops','r')
    title([num2str(size(corr_rspn_powspec_word,1)) ' correct words HFA (mean+SD)'])
    xlim([1 max(tr_lenght)])
    xticks([20 40 60])
    xticklabels({'0.2','0.4','0.6'})
    
    % plot single trials and average of no resp - HFA
    subplot(324)
    for c = 1:size(no_rspn_powspec_word,1)
        plot(no_rspn_powspec_word{c}(el,:),'Color',[0.9412,0.9412,0.9412])
        hold on
        tr_lenght(c,1) = size(no_rspn_powspec_word{c},2);
    end
    for_avg=[];
    for c = 1:size(no_rspn_powspec_word,1)
        for_avg(c,:) = [no_rspn_powspec_word{c}(el,:),NaN(1,max(tr_lenght)-tr_lenght(c))];
    end
    shadedErrorBar(1:size(for_avg,2),nanmean(for_avg,1),nanstd(for_avg),'lineprops','r')
    title([num2str(size(no_rspn_powspec_word,1)) ' no response words HFA (mean+SD)'])
    xlim([1 max(tr_lenght)])
    xticks([20 40 60])
    xticklabels({'0.2','0.4','0.6'})
    
    % plot single trials and average of wrong resp - HFA
    subplot(326)
    for c = 1:size(wrng_rspn_powspec_word,1)
        plot(wrng_rspn_powspec_word{c}(el,:),'Color',[0.9412,0.9412,0.9412])
        hold on
        tr_lenght(c,1) = size(wrng_rspn_powspec_word{c},2);
    end
    for_avg=[];
    for c = 1:size(wrng_rspn_powspec_word,1)
        for_avg(c,:) = [wrng_rspn_powspec_word{c}(el,:),NaN(1,max(tr_lenght)-tr_lenght(c))];
    end
    shadedErrorBar(1:size(for_avg,2),nanmean(for_avg,1),nanstd(for_avg),'lineprops','r')
    title([num2str(size(wrng_rspn_powspec_word,1)) ' wrong response words HFA (mean+SD)'])
    xlim([1 max(tr_lenght)])
    xticks([20 40 60])
    xticklabels({'0.2','0.4','0.6'})
    xlabel('Time (s)')
    
    sgtitle({[control_ERP.label{el}, ' - word onset locked ERP and HFA'];...
        'Baseline corrected to prespeech only noise part ([-3.45 -3.05]sec of sentence onset)';...
        ['from ' num2str(length(control_blocks)) ' blocks']})
    
    % Save the figure
    fprintf('\t-Saving electrode #%d-%s, out of %d\n',el,control_ERP.label{el},size(control_ERP.label,1))
    print(fullfile(save_folder,[control_wlt.label{el} , '_words_only.jpg']),'-djpeg','-r300')
    close all
    
end


end

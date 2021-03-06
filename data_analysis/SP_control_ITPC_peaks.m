function SP_control_ITPC_peaks(Sbj_Metadata)
% This function streamlines: loading wavelet complex output that was
% epoched based on peakRate or peakEnv events in different conditions
% (no-response, correct response and wrong response), calculating ITPC
% (from all events) and plots in 2x3 figure (peakRate or peakEnv x 3
% conditions). 

% Select blocks to import
control_blocks = select_cont_blocks(Sbj_Metadata);
save_dir = fullfile(Sbj_Metadata.results, [strjoin(control_blocks,'_') '_v3']);
fprintf('Loading ''fouri_of_words'' from:\n-->%s\n',fullfile(save_dir, [strjoin(control_blocks,'_') '_ctrl_word_fouri.mat']))
load(fullfile(save_dir, [strjoin(control_blocks,'_') '_ctrl_word_fouri.mat']));
load(fullfile(Sbj_Metadata.iEEG_data,Sbj_Metadata.BlockLists{1},[Sbj_Metadata.BlockLists{1} '_info.mat']),'info');

freq = fouri_of_words.freq_band_dtls{1};
time = linspace(-0.05,0.5,size(fouri_of_words.corr_rspn_fouri_peakEnv{1},4));

save_dir = fullfile(Sbj_Metadata.results, [strjoin(control_blocks,'_') '_v3'],'PICS');
if ~exist(save_dir,'dir'),mkdir(save_dir),end

bwr = load('bwr_cmap.mat');

itpc = [];
for pp = 1:2
    for cond = 1:3
        % get data
        if cond == 1 && pp ==1
            curr_fouri_all = fouri_of_words.corr_rspn_fouri_peakEnv{1};
        elseif cond == 2 && pp ==1
            curr_fouri_all = fouri_of_words.no_rspn_fouri_peakEnv{1};
        elseif cond == 3 && pp ==1
            curr_fouri_all = fouri_of_words.wrng_rspn_fouri_peakEnv{1};
        elseif cond == 1 && pp ==2
            curr_fouri_all = fouri_of_words.corr_rspn_fouri_peakRate{1};
        elseif cond == 2 && pp ==2
            curr_fouri_all = fouri_of_words.no_rspn_fouri_peakRate{1};
        elseif cond == 3 && pp ==2
            curr_fouri_all = fouri_of_words.wrng_rspn_fouri_peakRate{1};
        end
        
        % compute inter-trial phase coherence (itpc) for each conditions
        tmp      = curr_fouri_all./abs(curr_fouri_all);    % divide by amplitude
        tmp      = sum(tmp,1);                            % sum angles across trials
        tmp      = abs(tmp)/size(curr_fouri_all,1);       % take the absolute value and normalize
        
        if isempty(tmp)
            sztmp = size(itpc);
            tmp = zeros(sztmp(3:5));
        end
        itpc(pp,cond,:,:,:) = squeeze(tmp);                          % remove the first singleton dimension
        
    end
end

% plot ITPC of each electrode
for el = 1:size(itpc,3)
    figure('Units','normalized','Position', [0 0  .6 .3]);
    for pp = 1:2
        for cond = 1:3
            
            subplot(2, 3, (pp-1)*3+cond);
            imagesc(time, freq, squeeze(itpc(pp,cond,el,:,:)));
            axis xy
            
            if cond == 1 && pp ==1
                title('Correct responses');
            elseif cond == 2 && pp ==1
                title('No responses');
            elseif cond == 3 && pp ==1
                title('Wrong responses');
            end
            set(gca, 'FontSize',13,'FontWeight','bold');
            
            if cond==1 && pp == 1
                ylabel({'peakEnv locked';'Frequency (Hz)'});end
            if cond==1 && pp == 2
                ylabel({'peakRate locked';'Frequency (Hz)'});end
            if cond==2 && pp == 2
                xlabel('Time (s)');end
            caxis([0 0.5])
        end
    end
    
    % Create and delete new axes to plot colorbar
    ax = axes;
    colormap(bwr.rgb_vals);
    cmaph = colorbar(ax);
    cmaph.Ticks = linspace(0,1,6);
    cmaph.TickLabels = num2cell(linspace(0,0.5,6));
    cmaph.FontSize = 13;cmaph.FontWeight='bold';
    cmaph.LineWidth = 1;
    colorTitleHandle = get(cmaph,'Title');
    set(colorTitleHandle ,'String','ITPC','FontSize',13,'FontWeight','bold');
    a=get(cmaph); %gets properties of colorbar
    a = a.Position; %gets the positon and size of the color bar
    set(cmaph,'Position',[a(1)+0.05 a(2) 0.03 0.8])% To change size
    ax.Visible = 'off';
    
    
    sgtitle(['Elec: ' info.channelinfo.Label{el} ' - inter-trial phase coherence (peakEnv and peakRate locked)'], 'FontSize',15,'FontWeight','bold')
    print('-r300','-djpeg',fullfile(save_dir,[info.channelinfo.Label{el} '_ITPC_peaks.jpg']))
    close all
end


end
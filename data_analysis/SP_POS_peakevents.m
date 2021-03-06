function SP_POS_peakevents(Sbj_Metadata)
% This function streamlines calculation of phase opposition values by:
% loading peakRate and peakEnv locked epoched wavelet, calculates p-values
% from phase opposition sum from z-score, calculate ITPCz nd plots ITPCzs,
% p-values and ITPZ differences (with significant periods circled).

% Select blocks to import
control_blocks = select_cont_blocks(Sbj_Metadata);
save_dir = fullfile(Sbj_Metadata.results, [strjoin(control_blocks,'_') '_v3']);
fprintf('Loading ''fouri_of_words'' from:\n-->%s\n',fullfile(save_dir, [strjoin(control_blocks,'_') '_ctrl_word_fouri.mat']))
load(fullfile(save_dir, [strjoin(control_blocks,'_') '_ctrl_word_fouri.mat']),'fouri_of_words');
load(fullfile(Sbj_Metadata.iEEG_data,Sbj_Metadata.BlockLists{1},[Sbj_Metadata.BlockLists{1} '_info.mat']),'info');

% freq = fouri_of_words.freq_band_dtls{1};
% time = linspace(-0.05,0.5,size(fouri_of_words.corr_rspn_fouri_peakEnv{1},4));
save_folder = fullfile(Sbj_Metadata.results, strjoin(control_blocks,'_'), 'POS_peakevents');
if ~exist(save_folder,'dir'),mkdir(save_folder),end

% load channels of interest
load(fullfile(Sbj_Metadata.sbjDir,[Sbj_Metadata.sbj_ID, '_channel_OI.mat']),'channel_OI')

%% Calculate statistics
% % calculate everything only on electrodes of interest 
% chan_OI_idx = ismember(info.channelinfo.Label,channel_OI);
% fouri_of_words.corr_rspn_fouri_peakRate{1} = fouri_of_words.corr_rspn_fouri_peakRate{1}(:,chan_OI_idx,:,:);
% fouri_of_words.no_rspn_fouri_peakRate{1} = fouri_of_words.no_rspn_fouri_peakRate{1}(:,chan_OI_idx,:,:);
% fouri_of_words.corr_rspn_fouri_peakEnv{1} = fouri_of_words.corr_rspn_fouri_peakEnv{1}(:,chan_OI_idx,:,:);
% fouri_of_words.no_rspn_fouri_peakEnv{1} = fouri_of_words.no_rspn_fouri_peakEnv{1}(:,chan_OI_idx,:,:);

for pp=1:2 % loop peakRate and peakEnv
    % move the trials to last dimension
    if pp==1 % peakRate events
        data1 = permute(fouri_of_words.corr_rspn_fouri_peakRate{1},[2,3,4,1]);
        data2 = permute(fouri_of_words.no_rspn_fouri_peakRate{1},[2,3,4,1]);
    else
        data1 = permute(fouri_of_words.corr_rspn_fouri_peakEnv{1},[2,3,4,1]);
        data2 = permute(fouri_of_words.no_rspn_fouri_peakEnv{1},[2,3,4,1]);
    end
    % calculate different phase opposition values, best seems to be p_zPOS
    [p_circWW{pp}, p_POS{pp}, p_zPOS{pp}] = PhaseOpposition(data1, data2, 1000, 3);
end

%% Calculate ITPCz
itpc = [];
for pp = 1:2
    for cond = 1:2
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
        tmp      = curr_fouri_all./abs(curr_fouri_all);   % divide by amplitude
        tmp      = sum(tmp,1);                            % sum angles across trials
        tmp      = abs(tmp)/size(curr_fouri_all,1);       % take the absolute value and normalize
        
        itpc(pp,cond,:,:,:) = size(curr_fouri_all,1) * squeeze(tmp).^2; % remove the first singleton dimension and n*ITPC^2
    end
end


%% Plot

bwr = load('bwr_cmap.mat');

% for ITPC plots
freq_ITPC = fouri_of_words.freq_band_dtls{1};
time_ITPC = fouri_of_words.time_dtls;

for el = 1:size(info.channelinfo.Label,1)
    
    if ~any(ismember(channel_OI,info.channelinfo.Label{el}))
        continue
    end
    
    figure('Units','normalized','Position', [0 0  1 1]);
    % first row peakRate, second peakEnv
    % first col corr resp, second no resp, third for difference and significant parts
    
    
    
    for pp = 1:2 % first peakRate second peakEnv
        
        for cond = 1:2 % loop columns: first correct, second no, third difference
            
            subplot(2, 4, subplotno(4,pp,cond))
            surf(time_ITPC, freq_ITPC, squeeze(itpc(pp,cond,el,:,:)));set(gcf,'renderer','zbuffer');
            axis xy
            set(gca, 'FontSize',13,'FontWeight','bold');
            caxis([0 5])
            view(0,90); axis tight;
            
            
            if pp == 1
                ylabel({'peakRate locked';'Frequency (Hz)'});
            elseif pp == 2
                ylabel({'peakEnv locked';'Frequency (Hz)'});
            end
            
            hold on
            shading interp;
%             clim_v = get(gca,'clim');  %colorbar;
            plot3([0 0],ylim,[15 15],'k');
            if cond == 1 && pp ==1
                title([num2str(size(fouri_of_words.corr_rspn_fouri_peakRate{1},1)) ' events during correct responses']);
            elseif cond == 2 && pp ==1
                title([num2str(size(fouri_of_words.no_rspn_fouri_peakRate{1},1)) ' events during no-responses']);
            elseif cond == 1 && pp == 2
                title([num2str(size(fouri_of_words.corr_rspn_fouri_peakEnv{1},1)) ' events during correct responses']);
            elseif cond == 2 && pp == 2
                title([num2str(size(fouri_of_words.no_rspn_fouri_peakEnv{1},1)) ' events during no-responses']);
            end
            
            if cond==1 && pp == 1
                ylabel({'peakRate locked';'Frequency (Hz)'});
            end
            if cond==1 && pp == 2
                ylabel({'peakEnv locked';'Frequency (Hz)'});
            end
            if pp==1
                xlabel('Time (s)');
            end
            
        end
        
        % plot raw p-values
        subplot(2,4,subplotno(4,pp,3))
        surf(time_ITPC, freq_ITPC, -log10(squeeze(p_zPOS{pp}(el,:,:))));set(gcf,'renderer','zbuffer');
        axis xy
        set(gca, 'FontSize',13,'FontWeight','bold');
        hold on
        shading interp;
        view(0,90); axis tight;
        yl=ylim;
        ylim([1 yl(2)])
        title('-log10(p-values) of z-scored POS')
        clim_p = [0 3];
        set(gca,'CLim',clim_p)  %colorbar;
        plot3([0 0],ylim,[15 15],'k');
        if pp==1
            xlabel('Time (s)');
        end
        
        % now plot the difference and significance
        subplot(2,4,subplotno(4,pp,4))
        surf(time_ITPC, freq_ITPC, [squeeze(itpc(pp,1,el,:,:))-squeeze(itpc(pp,2,el,:,:))]);set(gcf,'renderer','zbuffer');
        axis xy
        set(gca, 'FontSize',13,'FontWeight','bold');
        caxis([-5 5])
        hold on
        shading interp;
        view(0,90); axis tight;
        yl=ylim;
        ylim([1 yl(2)])
%         clim_v = get(gca,'clim');  %colorbar;
        plot3([0 0],ylim,[20 20],'k');
        
%         signplot = double(squeeze(p_zPOS{pp}(el,:,:)>p_thresh));
        signplot = double(squeeze(p_zPOS{pp}(el,:,:))<0.05);
%         signplot = [zeros(size(ITPC_stats(pp).mask,2),find(time_ITPC==0)-1),double(squeeze(ITPC_stats(pp).mask(strcmp(ITPC_stats(pp).label,control_ERP.label{el}),:,:)))];
        contour3(time_ITPC, freq_ITPC,15*signplot,1,'LineColor','k','LineWidth',3)
        title('n*ITPC^2 [correct-no] response')
        if pp==1
            xlabel('Time (s)');
        end
    end
    
    
    % Create and delete new axes to plot colorbar of ITPC
    ax = axes;
    colormap(bwr.rgb_vals);
    cmaph = colorbar(ax);
    cmaph.Ticks = linspace(0,1,5);
    cmaph.TickLabels = num2cell(linspace(0,5,5));
    cmaph.FontSize = 13;cmaph.FontWeight='bold';
    cmaph.LineWidth = 1;
    colorTitleHandle = get(cmaph,'Title');
    set(colorTitleHandle ,'String','n*ITPC^2 values','FontSize',13,'FontWeight','bold','Position',[300 -30 0]);
    a=get(cmaph); %gets properties of colorbar
    a = a.Position; %gets the positon and size of the color bar
    set(cmaph,'Location','southoutside') % to change orientation
    set(cmaph,'Position',[a(1)/6-0.02 0.04 0.35 0.02]) % To change size    
    ax.Visible = 'off';
    
    % Create and delete new axes to plot colorbar of ITPC on last column
    ax = axes;
    colormap(bwr.rgb_vals);
    cmaph = colorbar(ax);
    cmaph.Ticks = linspace(0,1,5);
    cmaph.TickLabels = num2cell(linspace(-5,5,5));
    cmaph.FontSize = 13;cmaph.FontWeight='bold';
    cmaph.LineWidth = 1;
    colorTitleHandle = get(cmaph,'Title');
    set(colorTitleHandle ,'String','n*ITPC^2 difference values','FontSize',13,'FontWeight','bold','Position',[149.5800 -30 0]);
    a=get(cmaph); %gets properties of colorbar
    a = a.Position; %gets the positon and size of the color bar
    set(cmaph,'Location','southoutside') % to change orientation
    set(cmaph,'Position',[3*a(1)/4+0.08 0.04 0.16 0.02]) % To change size    
    ax.Visible = 'off';
    
    % Create and delete new axes to plot colorbar of p-values
    cmaph2 = colorbar(ax);
    cmaph2.Ticks = linspace(0,1,6);
    cmaph2.TickLabels = num2cell(linspace(clim_p(1),clim_p(2),6));
    cmaph2.FontSize = 13;cmaph2.FontWeight='bold';
    cmaph2.LineWidth = 1;
    colorTitleHandle = get(cmaph2,'Title');
    set(colorTitleHandle ,'String','-log10(p-values)','FontSize',13,'FontWeight','bold','Position',[149.5800 -30 0]);
    a2=get(cmaph2); %gets properties of colorbar
    a2 = a2.Position; %gets the positon and size of the color bar
    set(cmaph2,'Location','southoutside') % to change orientation
    set(cmaph2,'Position',[3*a(1)/4-0.13 0.04 0.16 0.02]) % To change size    
    ax.Visible = 'off';
    text(-0.07,0.6,'peakRate locked events','Units','normalized','Rotation',90,'FontSize',18,'FontWeight','bold')
    text(-0.07,0.1,'peakEnv locked events','Units','normalized','Rotation',90,'FontSize',18,'FontWeight','bold')
    
    sgtitle(['Elec: ' info.channelinfo.Label{el} ' - ITPC and Phase Opposition Sum values'], 'FontSize',15,'FontWeight','bold')
    
    % Save the figure
    fprintf('\t-Saving electrode %s, out of %d\n',info.channelinfo.Label{el},size(channel_OI,1))
    print(fullfile(save_folder,[info.channelinfo.Label{el} , '_pEvent_ITPCs.jpg']),'-djpeg','-r300')
    close all
    
end
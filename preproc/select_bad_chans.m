% select_bad_chans
% To be able to easily select the bad channels from a list
soz_id = ismember(ecog.ftrip.label,ecog.szr_onset_chans);
spike_id = ismember(ecog.ftrip.label,ecog.spike_chans);
bad_id = ismember(ecog.ftrip.label,ecog.bad_chans);

d = table(ecog.ftrip.label,bad_id,spike_id,soz_id);
% newData = select_bad_chan_GUI(d);
% function data = MyDeleteFcn(t)
% data = get(t,'Data');
% end
h = figure('Name', 'Check appropriate boxes', 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none',...
    'Units', 'Normalized', 'Position', [0.4, 0.15, 0.2, 0.8]);


uit = uitable('Parent',h,...
    'Units', 'Normalized', 'Position', [0.1, 0.1, 0.8, 0.8],...
    'Data', table2cell(d),...
    'ColumnName',{'Label','bad chans','spikey','SOZ'},...
    'ColumnEditable',true,...
     'DeleteFcn','newData = MyDeleteFcn(gcbo);');


% % set(uit,'CellEditCallback','newData = get(h,''Data'');');
% % btn = uicontrol('Style', 'pushbutton', 'String', 'Update',...
% %         'Position', [420 480 100 40],...
% %         'Callback', 'newData = get(uit,''Data'');'); 
waitfor(h)
% % newData = get(uit,'Data');


% Vocalize the results
new_bads = ecog.ftrip.label(~ismember(ecog.ftrip.label([newData{:,2}]),ecog.bad_chans));
new_spikes = ecog.ftrip.label(~ismember(ecog.ftrip.label([newData{:,3}]),ecog.spike_chans));
new_SOZs = ecog.ftrip.label(~ismember(ecog.ftrip.label([newData{:,4}]),ecog.szr_onset_chans));

fprintf('Newly assigned bad channels: %s\n',strjoin(new_bads,', '))
fprintf('Newly assigned spikey channels: %s\n',strjoin(new_spikes,', '))
fprintf('Newly assigned SOZ channels: %s\n',strjoin(new_SOZs,', '))

% Put it back
ecog.bad_chans = ecog.ftrip.label([newData{:,2}]);
ecog.spike_id = ecog.ftrip.label([newData{:,3}]);
ecog.soz_id = ecog.ftrip.label([newData{:,4}]);

clear new_bads new_spikes new_SOZs newData uit h soz_id bad_id spike_id d
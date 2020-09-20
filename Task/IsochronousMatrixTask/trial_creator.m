function [all_trial,cfg] = trial_creator(cfg)
% Adapted from stim_creatorv2.m of Simple (first) version of Matrix
% Sentence Test based Speech in Noise task. Here the change is to make the
% stimuli coming isochronously, achronously or naturally. Similar approach
% have been used but using loops more efficiently.
% Example cfg
% cfg=[];
% cfg.language='English';
% cfg.noise='pink';
% cfg.SNR=-3;
% cfg.LvsR='L';
% cfg.part1.length=1;
% cfg.part2.chronicity='a';
% cfg.part2.frequency=2.4;
% cfg.part2.word1='Ben';
% cfg.part2.word2='got';
% cfg.part2.word3='nine';
% cfg.part2.word4='large';
% cfg.part2.word5='bells';
% cfg.part3.length=1;

%% Adming stuff
if ~isfield(cfg,'SNR')
    cfg.SNR = -3;
end
if ~isfield(cfg,'language')
    error('cfg needs to contain which "language" to use!')
end
if strcmp(cfg.language,'English')
    load('EnglishWordsInfo.mat','WordsInfo','avg_sig_pow','avg_noise_pow')
else
    load('SpanishWordsInfo.mat','WordsInfo','avg_sig_pow','avg_noise_pow')
end
language = cfg.language;
if ~isfield(cfg,'LvsR')
    cfg.LvsR = 'both';
    warning('No side for presenting channels is given, giving the stimulus to both!')
end

% Set sample rate same for all
SampleRate = 44100;

% generate noise
if strcmp(cfg.noise,'silence')
    common_noise = zeros(curr_length,1);
elseif any(strcmp(cfg.noise,{'pink','white','brown','blue','purple'}))
    cn = dsp.ColoredNoise('Color',cfg.noise,'SamplesPerFrame',SampleRate,'NumChannels',1);
    common_noise = cn();clear cn;common_noise=[common_noise;common_noise;common_noise;common_noise;common_noise];
elseif exist(cfg.noise,'file') % if wanting to use another noise (babble etc.)
    [common_noise, noise_SampleRate] = audioread(cfg.noise);
    common_noise = resample(common_noise,SampleRate,noise_SampleRate);
else
    error('Unrecognized noise in speech!')
end
if size(common_noise,2)==2 % it may have two channels, get only one for now
    common_noise(:,2) = [];
end

%% Now loop the parts according to the parameters
cfgfields=fieldnames(cfg);
partfields = cfgfields(contains(cfgfields,'part'));
all_trial=[];

for p = 1:length(partfields)
    curr_part = cfg.(partfields{p});
    curr_partfields = fieldnames(curr_part);
    
    if any(contains(curr_partfields,'word'))
        wordfields = curr_partfields(contains(curr_partfields,'word'));
        collected_clean_sounds=[];
        
        % loop the words to get clean versions with iso/achronous regularity
        for w=1:length(wordfields)
            
            filename = find_word(curr_part.(wordfields{w}),main_stim_loc,language);
            speech_audio = WordsInfo.Stim{contains(WordsInfo.StimName,[curr_part.(wordfields{w}) '-'])};
            if isempty(speech_audio),error('There is something wrong here'),end
            if size(speech_audio,2)==2 % it may have two channels, get only one for now
                speech_audio(:,2) = [];
            end
            emptyss=(SampleRate*(1/curr_part.frequency))-length(speech_audio);
            if emptyss > 0 && strcmpi(curr_part.chronicity,'a')
                movepoint=randi(emptyss,1);
            elseif strcmpi(curr_part.chronicity,'iso')
                movepoint=0;
            elseif strcmpi(curr_part.chronicity,'natural')
                movepoint=0;
                emptyss=0;
            end
            % collect move points
            cfg.(partfields{p}).(['move_times' num2str(w)]) = movepoint/SampleRate;
            
            thisword_clear=[zeros(movepoint,1);speech_audio;zeros(emptyss-movepoint,1)];
            collected_clean_sounds=[collected_clean_sounds;thisword_clear];
            
        end
    else
        collected_clean_sounds=zeros(curr_part.length * SampleRate,1);
        
    end
    
    % calculate the average scale factor to multiply with noise
    K = (avg_sig_pow/avg_noise_pow)*10^(-cfg.SNR/10);
    % Scale factor (K): avg_sig_pow and avg_noise_pow are the average signal and noise
    % power of 4 attention words: "now cath these words" or Spanish
    curr_noise = sqrt(K)*common_noise; % Change Noise level
    
    collected_noise_sounds=collected_clean_sounds+curr_noise(1:length(collected_clean_sounds));
    
    % LvsR option
    if strcmp(cfg.LvsR,'L')
        curr_stim = [collected_clean_sounds,collected_noise_sounds];
    elseif strcmp(cfg.LvsR,'R')
        curr_stim = [collected_noise_sounds,collected_clean_sounds];
    end
    
    all_trial=[all_trial;curr_stim];
    
end

end
%% Create many many stimuli :)

cd /home/sakkol/Documents/Speech_Perception_stim/02nd_Generation/GoogleTTS_M_1.7
speech_files = dir('*.wav');
stim_save_dir = '/home/sakkol/Documents/Speech_Perception_stim/02nd_Generation/Created_Stim_1.7';

cfg=[];
cfg.SNR = -4;
cfg.prespeech.part1.length= 0.5;
cfg.prespeech.part1.noise = 'pink';
cfg.prespeech.part2.noise = 'pink';
cfg.prespeech.part2.signal = '/home/sakkol/Documents/Speech_Perception_stim/02nd_Generation/Pre-stim-Attention-comma-M.wav';

cfg.speech.noise = 'pink';
cfg.postspeech.part1.length=2;
cfg.postspeech.part1.noise = 'pink';
cfg.LvsR = 'L';

for s=1:length(speech_files)
    cfg.speech.file = [speech_files(s).folder filesep speech_files(s).name];
    
    curr_sentence = erase(speech_files(s).name,'.wav');
    cfg.stim_save_filename = [stim_save_dir filesep curr_sentence 'LpatientRtdt.wav'];
    cfg.envelope_save_filename = [stim_save_dir filesep curr_sentence '.mat'];
    cfg.plot_save_filename = [stim_save_dir filesep curr_sentence '.jpg'];
    
    [stimulus,envelope]=stimuli_creator(cfg);
    
end
function JF_GratingPassive(t, events, parameters, visStim, inputs, outputs, audio)
% Present static grating (as in choiceworld) passively left/center/right 100% contrast
% Pseudorandom (each stim presented once for each trial)
% Number of trials = number of repeats
% modified from Andy's AP_lcrGratingPassive script 

%% Set up stimuli

stim_time = 0.5;%was 0.5
min_iti = 0.5;
max_iti = 0.5;
step_iti = 0.05;

% Visual stim
sigma = [100,100];
azimuths = repmat([1,1,1],1,6);
contrasts = repmat([1,1,1],1,6);
spatialFreq = repmat([1/3,1/3,1/3,1/15,1/15,1/15,1/30,1/30,1/30],1,2);
orientations= sort(repmat([0,45,90], 1,6));
vis_params = [azimuths; contrasts; spatialFreq; orientations];%before 170220: CombVec(azimuths,contrasts);

% audDev = audO.Devices('default');
% numAudChannels = audDev.NrOutputChannels;
% outputSampleRate = audDev.DefaultSampleRate;

%% Set trial data

% Signals garbage: things can't happen at the exact same time as newTrial
new_trial_set = events.newTrial.delay(0);

% Start clock for trial
trial_t = t - t.at(new_trial_set);

% Set the stim order and ITIs for this trial
stimOrder = new_trial_set.map(@(x) randperm(size(vis_params,2)));
stimITIs = new_trial_set.map(@(x) randsample(min_iti:step_iti:max_iti,size(vis_params,2),true)');

% Get the stim on times and the trial end time
trial_stimOn_times = stimITIs.map(@(x) [0,cumsum(x(1:end-1) + stim_time)]);
trial_end_time = stimITIs.map(@(x) sum(x) + stim_time*size(vis_params,2));


%% Present stim

% % Visual

stim_num = trial_t.ge(trial_stimOn_times).sum.skipRepeats;
stim_id = map2(stimOrder,stim_num,@(stim_order,stim_num) stim_order(stim_num));
stimAzimuth = stim_id.map(@(x) vis_params(1,x));
stimContrast = stim_id.map(@(x) vis_params(2,x));
stimOri = stim_id.map(@(x) vis_params(4,x));
stimSpFreq = stim_id.map(@(x) vis_params(3,x));

stim = vis.grating(t, 'square', 'gaussian');
stim.spatialFreq = stimSpFreq;
stim.sigma = sigma;
stim.phase = 2*pi*events.newTrial.map(@(x)rand);
stim.orientation = stimOri;

%stim.azimuth = stimAzimuth;
stim.contrast = stimContrast;

stimOn = stim_id.to(stim_id.delay(stim_time));
stim.show = stimOn;
visStim.stim = stim;

endTrial = events.newTrial.setTrigger(trial_t.gt(trial_end_time));

%% Events

events.stimITIs = stimITIs;
events.stimOn = stimOn;

events.stimAzimuth = stimAzimuth;
events.stimContrast = stimContrast;
events.stimOrientation = stimOri;
events.stimSpatialFreq = stimSpFreq;
events.endTrial = endTrial;

end


















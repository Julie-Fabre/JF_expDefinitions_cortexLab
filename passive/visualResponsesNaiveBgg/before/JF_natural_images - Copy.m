function JF_natural_images(t, events, parameters, visStim, inputs, outputs, audio)
% Present natural images
% Pseudorandom (each stim presented once for each trial)
% Number of trials = number of repeats

%% Set up parameters
stim_time = 0.5;
min_iti = 0.5;
max_iti = 0.5;
step_iti = 0.1;
n_images = 50;


%% Set trial data

% Signals garbage: things can't happen at the exact same time as newTrial
new_trial_set = events.newTrial.delay(0);

% Start clock for trial
trial_t = t - t.at(new_trial_set);

% Set the stim order and ITIs for this trial
stimOrder = new_trial_set.map(@(x) randperm(n_images));
stimITIs = new_trial_set.map(@(x) randsample(min_iti:step_iti:max_iti,n_images,true)');

% Get the stim on times and the trial end time
trial_stimOn_times = stimITIs.map(@(x) [0,cumsum(x(1:end-1) + stim_time)]);
trial_end_time = stimITIs.map(@(x) sum(x) + stim_time*n_images);


%% Present stim

% % Visual
imgDir = '\\zserver\Data\pregenerated_textures\JulieF\shapesAndNatImages';

stim_num = trial_t.ge(trial_stimOn_times).sum.skipRepeats;
stim_id = map2(stimOrder,stim_num,@(stim_order,stim_num) stim_order(stim_num));
stim_id_str = stim_id.map(@num2str);

stim_image = stim_id_str.map( ...
  @(curr_str_id) loadVar(fullfile(imgDir, ['img' curr_str_id '.mat']), 'img'));

stim = vis.image(t); 
stim.sourceImage = stim_image.map(@rescale);
stim.azimuth = 0;
stim.dims = [360,90];

stimOn = stim_id.to(stim_id.delay(stim_time));
stim.show = stimOn;
visStim.stim = stim;

endTrial = events.newTrial.setTrigger(trial_t.gt(trial_end_time));

%% Events

events.stimITIs = stimITIs;
events.stimOn = stimOn;
events.stim_id = stim_id;

events.endTrial = endTrial;

end


function preLoad(imgDir)
% PRELOAD Load images into memory to speed up retrieval
%  The burgbox function `loadVar` caches the images it loads and so long as
%  the files have not been modified, will return the cached image rather
%  than re-loading from the disk.  Calling this function either at expStart
%  or independent of any signals will load all the images into memory
%  well before the stimuli are presented.  This may be useful if you want
%  to show them in quick succession.  
%
% See also loadVar, clearCBToolsCache

% Clear any previously cached images so that memory doesn't blow up
clearCBToolsCache % Comment out to keep images cached between experiments
imgs = dir(fullfile(imgDir, '*.mat')); % Get all images from directory
loadVar(strcat({imgs.folder},'\',{imgs.name})); % Load into memory
end


function img = rescale(img)
% RESCALE Rescales image from [-1 1] to [0 255]
if isa(img,'single') %Kevin's images are [0 255] already
  img = max(img,-1); img = min(img, 1);
  img = (img*128+128);
else
  img = [img,img,img];
end
end














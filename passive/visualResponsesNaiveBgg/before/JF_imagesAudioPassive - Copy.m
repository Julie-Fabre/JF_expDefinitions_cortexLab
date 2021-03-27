function JF_imagesAudioPassive(t, evts, p, vs, ~, ~, ~)
% IMAGEWOLD Presentation of Marius's image set
%  Image directory must contain image files as MAT files named imgN where N
%  = {1, ..., N total images}.
% from Anna
%% parameters
% Image directory
imgDir = p.imgDir.skipRepeats();
N = imgDir.map(@file.list).map(@numel); % Get number of images
imgIds = N.map(@randperm);
%imgIds = N.map(@(x)linspace(1,x));
%imgIds = N.map(@(~) [1:100]);

%% define the visual stimulus
on = evts.newTrial.to(evts.newTrial.delay(p.onDuration));
off = at(true, on == false); % `then` makes sure off only ever updates to true
% If you want each image to repeat a set number of times...  Here when
% endTrial is false idx will update with the same value as before,
% repeating the image.
showNext = evts.repeatNum == p.repeats;
evts.endTrial = showNext.at(off).delay(p.offDuration);
% evts.endTrial = off.delay(p.offDuration); % Show each once

idx = merge(evts.expStart.then(true), evts.endTrial.scan(@plus, 1));
number = imgIds(idx); 
numberStr = number.map(@num2str);

imgArr = imgDir.map2(numberStr, ...
  @(dir,num)loadVar(fullfile(dir, ['img' num '.mat']), 'img'));
%imgArr = repmat(imgArr,2,1);
% Test stim left
vs.stimulus = vis.image(t); % create a Gabor grating
disp(t)
vs.stimulus.sourceImage = imgArr.map(@rescale);
vs.stimulus.show = on;
vs.stimulus.azimuth = p.ThisAzimuth;
vs.stimulus.dims = [p.ScreenSize1, p.ScreenSize2];
%% End trial and log events
evts.stimulusOn = on;

% Session ends when all images shown.
evts.expStop = at(true, idx == N);
evts.index = idx;
evts.num = number;

%% Parameter defaults
% See timeSampler for full details on what values the *Delay paramters can
% take.  Conditional perameters are defined as having ncols > 1, where each
% column is a condition.  All conditional paramters must have the same
% number of columns.
try
  imgDir = '\\zserver\Data\pregenerated_textures\JulieF\shapesAndNatImages';
  p.imgDir = imgDir;
  p.onDuration = 0.5;
  p.offDuration = 0.5;
  p.repeats = 1; % Repeat each image twice in a row
  p.ScreenSize1 = 360;
  p.ScreenSize2 = 90;
  p.ThisAzimuth = 0;
 % p.NumRepeats = 20;
 
catch 
  % NB At the start of a Signals experiment (as opposed to when you call
  % inferParameters) this catch block is executed.  Therefore you could
  % preload the images here during the initiazation phase.
  preLoad(imgDir);
end

end

%% Helper functions
function duration = timeSampler(time)
% TIMESAMPLER Sample a time from some distribution
%  If time is a single value, duration is that value.  If time = [min max],
%  then duration is sampled uniformally.  If time = [min, max, time const],
%  then duration is sampled from a exponential distribution, giving a flat
%  hazard rate.  If numel(time) > 3, duration is a randomly sampled value
%  from time.
%
% See also exp.TimeSampler
if nargin == 0; duration = 0; return; end
switch length(time)
  case 3 % A time sampled with a flat hazard function
    duration = time(1) + exprnd(time(3));
    duration = iff(duration > time(2), time(2), duration);
  case 2 % A time sampled from a uniform distribution
    duration = time(1) + (time(2) - time(1))*rand;
  case 1 % A fixed time
    duration = time(1);
  otherwise % Pick on of the values
    duration = randsample(time, 1);
end
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
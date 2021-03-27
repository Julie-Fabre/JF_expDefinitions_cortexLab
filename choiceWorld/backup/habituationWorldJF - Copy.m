function habituationWorldJF(t, evts, p, vs, in, out, audio)
%% habituationWorld
% A simple function that will either osputput a reward at the end of each
% trial whose length is defined by p.rewardTime, or when the wheel reaches
% a threshold, defined as p.movementThreshold in arbitrary units.  The
% latter mode is chosen by p.useWheel being true.

%% parameters
% p.randomiseConditions; % Allows specific condition order
wheel = in.wheel.skipRepeats(); % Wheel signal
wheelDelta = evts.newTrial.at(wheel).scan(@plus, 0); % Wheel integrator
wheelDelta = wheelDelta - wheelDelta.at(evts.newTrial); % Reset each trial

rewardKey = p.rewardKey.at(evts.expStart); % get value of rewardKey at experiemnt start, otherwise it will take the same value each new trial
rewardKeyPressed = in.keyboard.strcmp(rewardKey); % true each time the reward key is pressed

% Sounds
audioDevice = audio.Devices('default');
onsetToneFreq = 5000;
onsetToneDuration = 0.1;
onsetToneRampDuration = 0.01;
toneSamples = p.onsetToneAmplitude*evts.expStart.map(@(x) ...
    aud.pureTone(onsetToneFreq, onsetToneDuration, audioDevice.DefaultSampleRate, ...
    onsetToneRampDuration, audioDevice.NrOutputChannels));

%% Audio onset tone
% Play tone at trial onset
audio.default = toneSamples.at(evts.newTrial);

%% feedback
reward = iff(p.useWheel, wheelDelta > p.movementThreshold,... % movement threshold reached
  t - t.at(evts.newTrial.delay(0)) > map(p.avgRewardTime, @timeSampler)); % or at end of trial
reward = merge(rewardKeyPressed, evts.newTrial.setTrigger(reward));% only update when feedback changes to greater than 0, or reward key is pressed
out.reward = p.rewardSize.at(reward.delay(0.5)); % output reward

%% Test stim
trialSide = evts.newTrial.map(@(k)randsample([-1 1], double(k)));
azimuth = trialSide*cond(...
  evts.newTrial.to(reward), p.stimulusAzimuth,...
  reward.to(reward.delay(p.interTrialDelay)), 0);
stimulusOff = reward.delay(p.interTrialDelay);

stimulus = vis.grating(t, 'square', 'gaussian');%QQ
stimulus.sigma = p.sigma;
stimulus.spatialFreq = p.spatialFreq;
stimulus.phase = 2*pi*evts.newTrial.map(@(v)rand);
stimulus.azimuth = azimuth;
%stim.contrast = trialContrast.at(stimOn)*stimFlicker;
stimulus.contrast = 1;
% When show is true, the stimulus is visible
stimulus.show = evts.newTrial.to(stimulusOff);

vs.Stimulus = stimulus; % store stimulus in visual stimuli set and log as 'leftStimulus'

%% misc
% we want to save these signals so we put them in events with appropriate names
nextCondition = azimuth == 0; 
evts.endTrial = nextCondition.at(stimulusOff).delay(p.interTrialDelay);
% evts.wheelDelta = wheelDelta;
% evts.reward = reward;
evts.thr = p.movementThreshold;
evts.trialSide = trialSide;
evts.totalWater = out.reward.scan(@plus, 0).map(fun.partial(@sprintf, '%.1f?l'));

try
  p.onsetToneAmplitude = 0.15;
  p.rewardKey = 'r';
  p.interTrialDelay = 1.0;
  p.rewardSize = 3;
  p.stimulusAzimuth = 90;
  p.spatialFreq = 1/15;%QQ
p.sigma = [20,20]';%QQ
% stimFlickerFrequency = 5; % DISABLED BELOW
p.startingAzimuth = 90; % (degrees)%QQ
  % Random rewards
  p.useWheel = false;
  p.movementThreshold = 1000; % Irrelevant when useWheel is false
  p.rewardTime = randi(10,1,100);
  p.avgRewardTime = 10; % Seconds
%   p.randomiseConditions = true; % Should be set in parameter GUI
  % Rewards for moving wheel
%   p.useWheel = true;
%   p.randomiseConditions = false; % Should be set in parameter GUI
%   p.movementThreshold = 1:100:4000; % Gradually increase threshold
%   p.rewardTime = 10; % Irrelevant when useWheel is true
catch
end

end
function t = timeSampler(time, mode)
if nargin == 1; mode = 'normal'; end
sd = 2;
switch mode
  case 'normal'
    t = time + randn*sd;
    t = iff(t<0, 0, t);
  case 'uniform'
    t = randi(time);
  otherwise
    t = 0;
end
end
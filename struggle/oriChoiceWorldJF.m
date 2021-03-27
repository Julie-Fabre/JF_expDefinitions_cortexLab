function oriChoiceWorldJF(t, events, p, vs, in, out, audio)
%% oriChoiceWorld
% Burgess 2AFC task with orientation discrimination  

% 2019-02-06 Modified for oriComp (originally advancedChoiceWorld.m) SF
% 2019-02-11 Added stationary cue option (p.stationaryCues) SF
% 2019-02-13 Added wait on early response option (p.waitOnEarlyResponse)
% for interactive delay
% 2019-06-11 Stimulus is turned off at end of feedback

% NOTE: Orientation convention is different from original choiceworld.
% Vertical = 0, horizontal = 90. 

%% parameters
wheel = in.wheelMM; % The wheel input in mm turned tangential to the surface
rewardKey = p.rewardKey.at(events.expStart); % get value of rewardKey at experiemnt start, otherwise it will take the same value each new trial
rewardKeyPressed = in.keyboard.strcmp(rewardKey); % true each time the reward key is pressed
randomNumbers2 = randi([0, 1], [1, 2]);
if randomNumbers2(2)==0
    oriLeft = 45;
oriRight = 45;
else
     oriLeft = 0;
oriRight = 0;
end
contrastLeft = p.stimulusContrast(1);
contrastRight = p.stimulusContrast(2);


%% when to present stimuli & allow visual stim to move
% stimulus should come on after the wheel has been held still for the
% duration of the preStimulusDelay.  The quiescence threshold is a tenth of
% the rotary encoder resolution.
preStimulusDelay = p.preStimulusDelay.map(@timeSampler).at(events.newTrial); % at(evts.newTrial) fix for rig pre-delay 
stimulusOn = sig.quiescenceWatch(preStimulusDelay, t, wheel, p.quiescenceThreshold);
% interactiveDelay = p.interactiveDelay.map(@timeSampler);
interactiveDelay = p.interactiveDelay.map(@timeSampler).at(stimulusOn);
interactThreshold = cond(p.waitOnEarlyResponse, p.quiescenceThreshold, true, inf);
interactiveOn = sig.quiescenceWatch(interactiveDelay, t, wheel, interactThreshold);
% interactiveOn = stimulusOn.delay(interactiveDelay); % the closed-loop period starts when the stimulus comes on, plus an 'interactive delay'

audioDevice = audio.Devices('default');
onsetToneSamples = p.onsetToneAmplitude*...
    mapn(p.onsetToneFrequency, 0.1, audioDevice.DefaultSampleRate,...
    0.02, audioDevice.NrOutputChannels, @aud.pureTone); % aud.pureTone(freq, duration, samprate, "ramp duration", nAudChannels)
audio.default = onsetToneSamples.at(interactiveOn); % At the time of 'interative on', send samples to audio device and log as 'onsetTone'

%% wheel position to stimulus displacement
% Here we define the multiplication factor for changing the wheel signal
% into mm/deg visual angle units.  The Lego wheel used has a 31mm radius.
% The standard KÜBLER rotary encoder uses X4 encoding; we record all edges
% (up and down) from both channels for maximum resolution. This means that
% e.g. a KÜBLER 2400 with 100 pulses per revolution will actually generate
% *400* position ticks per full revolution.
wheelOrigin = wheel.at(interactiveOn); % wheel position sampled at 'interactiveOn'
stimulusDisplacement = p.wheelGain*(wheel - wheelOrigin); % yoke the stimulus displacment to the wheel movement during closed loop

%% define response and response threshold 
%responseWindow = iff(oriLeft*leftStimulus.contrast + oriRight*rightStimulus.contrast == 45, 1, 10); 
responseTimeOver = (t - t.at(interactiveOn)) > p.responseWindow; % p.responseWindow may be set to Inf
threshold = interactiveOn.setTrigger(...
  abs(stimulusDisplacement) >= abs(p.stimulusAzimuth) | responseTimeOver);

response = cond(...
    responseTimeOver, 0,... % if the response time is over the response = 0
    true, -sign(stimulusDisplacement)); % otherwise it should be the inverse of the sign of the stimulusDisplacement

response = response.at(threshold); % only update the response signal when the threshold has been crossed

%% define correct response and feedback
% each trial randomly pick -1 or 1 value for use in baited (guess) trials
rndDraw = map(events.newTrial, @(x) sign(rand(x)-0.5)); 
correctResponse = cond(oriLeft < oriRight, -1,... % ori left
    oriLeft > oriRight, 1,... % ori right
    (oriLeft == oriRight) & (rndDraw < 0), -1,... % equal orientation (baited)
    (oriLeft == oriRight) & (rndDraw > 0), 1); % equal orientation (baited)
feedback = correctResponse == response;
% Only update the feedback signal at the time of the threshold being crossed
feedback = feedback.at(threshold).delay(0.1); 

noiseBurstSamples = p.noiseBurstAmp*...
    mapn(audioDevice.NrOutputChannels, p.noiseBurstDur*audioDevice.DefaultSampleRate, @randn);
audio.default = noiseBurstSamples.at(feedback==0); % When the subject gives an incorrect response, send samples to audio device and log as 'noiseBurst'

reward = merge(rewardKeyPressed, feedback > 0);% only update when feedback changes to greater than 0, or reward key is pressed
out.reward = p.rewardSize.at(reward); % output this signal to the reward controller

% Correcting for delay differences for rewarded vs unrewarded due to DAQ
% lag?
postThDelay = iff(feedback>0, p.rewardDur-0.1, p.noiseBurstDur); 

dT = threshold.delay(0.2);

stimulusOff = dT.delay(postThDelay-0.2); % turn stimulus off once feedback is complete

% stimulusOff = threshold.delay(1); % Set this for some passive experiments that used old version

%% stimulus azimuth
azimuth = cond(...
    stimulusOn.to(interactiveOn), 0,... % Before the closed-loop condition, the stimulus is at it's starting azimuth
    interactiveOn.to(threshold), stimulusDisplacement,... % Closed-loop condition, where the azimuth yoked to the wheel
    threshold.to(stimulusOff),  -response*abs(p.stimulusAzimuth)); % Once threshold is reached the stimulus is fixed again

%% define the visual stimulus
randomNumbers = randi([0, 1], [1, 2]);
% Test stim left
leftStimulus = vis.grating(t, 'sinusoid', 'gaussian'); % create a Gabor grating
leftStimulus.orientation = oriLeft;
leftStimulus.altitude = 0;
leftStimulus.sigma = [20,20]; % in visual degrees
leftStimulus.spatialFreq = p.spatialFrequency; % in cylces per degree
leftPhase = 2*pi*events.newTrial.map(@(v)rand);
leftStimulus.phase = leftPhase;  % phase randomly changes each trial
if randomNumbers(1)==0
    leftStimulus.contrast = 1;
end

leftStimulus.azimuth = cond(p.stationaryCues, -p.stimulusAzimuth, true, -p.stimulusAzimuth + azimuth);
%     leftStimulus.azimuth = -p.stimulusAzimuth + azimuth;
% leftStimulus.azimuth = -p.stimulusAzimuth;


% When show is true, the stimulus is visible
leftStimulus.show = stimulusOn.to(stimulusOff);

vs.leftStimulus = leftStimulus; % store stimulus in visual stimuli set and log as 'leftStimulus'

% Test stim right
rightStimulus = vis.grating(t, 'sinusoid', 'gaussian');
rightStimulus.orientation = oriRight;
rightStimulus.altitude = 0;
rightStimulus.sigma = [20,20];
rightStimulus.spatialFreq = p.spatialFrequency;
rightPhase = 2*pi*events.newTrial.map(@(v)rand);
rightStimulus.phase = rightPhase;
if randomNumbers(1)==0
    rightStimulus.contrast = 0;
end

rightStimulus.azimuth = cond(p.stationaryCues, p.stimulusAzimuth, true, p.stimulusAzimuth + azimuth);
% rightStimulus.azimuth = p.stimulusAzimuth + azimuth;
% rightStimulus.azimuth = p.stimulusAzimuth;

rightStimulus.show = stimulusOn.to(stimulusOff); 

vs.rightStimulus = rightStimulus; % store stimulus in visual stimuli set

%% End trial and log events
% Let's use the next set of conditional paramters only if positive feedback
% was given, or if the parameter 'Repeat incorrect' was set to false.
nextCondition = feedback > 0 | p.repeatIncorrect == false; 

% we want to save these signals so we put them in events with appropriate
% names:
events.stimulusOn = stimulusOn;
events.stimulusOff = stimulusOff;
events.threshold = threshold;
events.preStimulusDelay = preStimulusDelay;
events.interactiveDelay = interactiveDelay;
events.contrast = p.stimulusContrast;
events.orientation = p.stimulusOrientation;
events.stimulusPhase = [leftPhase; rightPhase];
events.postThDelay = postThDelay;
events.stationary = p.stationaryCues;
events.azimuth = azimuth;
events.response = response;
events.feedback = feedback;
events.interactiveOn = interactiveOn;
% Accumulate reward signals and append microlitre units
events.totalReward = out.reward.scan(@plus, 0).map(fun.partial(@sprintf, '%.1fµl')); 

% Trial ends when evts.endTrial updates.  
% If the value of evts.endTrial is false, the current set of conditional
% parameters are used for the next trial, if evts.endTrial updates to true, 
% the next set of randowmly picked conditional parameters is used
events.endTrial = nextCondition.at(stimulusOff).delay(p.interTrialDelay.map(@timeSampler)); 

%% Parameter defaults
% See timeSampler for full details on what values the *Delay paramters can
% take.  Conditional perameters are defined as having ncols > 1, where each
% column is a condition.  All conditional paramters must have the same
% number of columns.
try

p.stimulusContrast = [1,1]';
p.repeatIncorrect = false;
p.onsetToneFrequency = 5000;
p.interactiveDelay = 1;
p.onsetToneAmplitude = 0.15;
p.responseWindow = Inf;
p.stimulusAzimuth = 80;
p.noiseBurstAmp = 0.01;
p.noiseBurstDur = 1;
p.rewardDur = 0.5;
p.rewardSize = 3;
p.rewardKey = 'r';
p.stimulusOrientation = [0,0]';
p.spatialFrequency = 0.04; 
p.interTrialDelay = [0.5,1]';
p.wheelGain = 6;
p.preStimulusDelay = 1;
p.quiescenceThreshold = 10;
p.stationaryCues = false;
p.waitOnEarlyResponse = false;
catch % ex
%    disp(getReport(ex, 'extended', 'hyperlinks', 'on'))
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
end
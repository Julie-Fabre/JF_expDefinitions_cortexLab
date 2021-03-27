function barWorldJF(t, events, p, vs, in, out, audio)
%% barWorld
% Task where mice move a bar from periphery to center screen. 

% Goal
% Bar appears at random positions tangent to the unit circle falling within
% the visual field. Position of the bar is determined by direction the bar 
% will subsequently move. All bars move to centre screen regardless of
% direction of wheel movement. 

% Example, if imaging right V1, show bars with direction spanning 90 to
% 270. If imaging left V1, show bars spanning 270 to 90. 

% 2020-03-13 Created by SF

% 2020-03-13 - First step, a 0 deg bar moving left to right and right to
% left.

% NOTE: Orientation convention is different from original choiceworld.
% Vertical = 0, horizontal = 90. 

%% parameters
wheel = in.wheelMM; % The wheel input in mm turned tangential to the surface
rewardKey = p.rewardKey.at(events.expStart); % get value of rewardKey at experiemnt start, otherwise it will take the same value each new trial
rewardKeyPressed = in.keyboard.strcmp(rewardKey); % true each time the reward key is pressed

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
stimulusDisplacement = p.wheelGain*(abs(wheel - wheelOrigin)); % yoke the stimulus displacment to the wheel movement during closed loop

%% define response and response threshold 

responseTimeOver = (t - t.at(interactiveOn)) > p.responseWindow; % p.responseWindow may be set to Inf
threshold = interactiveOn.setTrigger(...
  abs(stimulusDisplacement) >= abs(p.pRadius) | responseTimeOver); % Stimulus moves all the way to other azimuth position


%% define correct response and feedback

feedback = p.pRadius == p.pRadius;
% Only update the feedback signal at the time of the threshold being crossed
feedback = feedback.at(threshold).delay(0.1); 

reward = merge(rewardKeyPressed, feedback > 0);% only update when feedback changes to greater than 0, or reward key is pressed
out.reward = p.rewardSize.at(reward); % output this signal to the reward controller

stimulusOff = threshold.delay(p.rewardDur); % Keep on screen until end of reward delay (to allow drinking of water/sucrose)

%% stimulus azimuth
distance = cond(...
    stimulusOn.to(interactiveOn), 0,... % Before the closed-loop condition, the stimulus is at it's starting azimuth
    interactiveOn.to(threshold), stimulusDisplacement,... % Closed-loop condition, where the azimuth yoked to the wheel
    threshold.to(stimulusOff),  p.pRadius); % Once threshold is reached the stimulus is fixed again

%% define the visual stimulus

% Bar stim

barStim = vis.patch(t, 'rect');
barStim.orientation = mod(abs(90-p.barDirection),180);
barStim.dims = [p.barLength p.barWidth];

% Azimuth and elevation should vary as a function of bar direction and
% distance wheel is moved

barStim.azimuth = cos(deg2rad(p.barDirection))*p.pRadius + -cos(deg2rad(p.barDirection))*distance;
barStim.altitude = sin(deg2rad(p.barDirection))*p.pRadius + -sin(deg2rad(p.barDirection))*distance;

% When show is true, the stimulus is visible
barStim.show = stimulusOn.to(stimulusOff);

vs.barStim = barStim;


%% End trial and log events

% we want to save these signals so we put them in events with appropriate
% names:
events.stimulusOn = stimulusOn;
events.stimulusOff = stimulusOff;
events.threshold = threshold;
events.preStimulusDelay = preStimulusDelay;
events.interactiveDelay = interactiveDelay;
events.direction = p.barDirection;
events.distance = distance;
events.interactiveOn = interactiveOn;
events.barStim = barStim;
% Accumulate reward signals and append microlitre units
events.totalReward = out.reward.scan(@plus, 0).map(fun.partial(@sprintf, '%.1fµl')); 

% Trial ends when evts.endTrial updates.  
% If the value of evts.endTrial is false, the current set of conditional
% parameters are used for the next trial, if evts.endTrial updates to true, 
% the next set of randowmly picked conditional parameters is used

events.endTrial = stimulusOff.delay(p.interTrialDelay.map(@timeSampler));

%% Parameter defaults
% See timeSampler for full details on what values the *Delay paramters can
% take.  Conditional perameters are defined as having ncols > 1, where each
% column is a condition.  All conditional paramters must have the same
% number of columns.
try

p.barWidth = 4;
p.barLength = 40;
p.onsetToneFrequency = 5000;
p.interactiveDelay = 1;
p.onsetToneAmplitude = 0.15;
p.responseWindow = Inf;
p.pRadius = 90;
p.rewardDur = 0.5;
p.rewardSize = 3;
p.rewardKey = 'r';
p.barDirection = 0;
p.interTrialDelay = [0.5,1]';
p.wheelGain = 1;
p.preStimulusDelay = 1;
p.quiescenceThreshold = 10;
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
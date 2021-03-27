function advancedChoiceWorld_miles(t, evts, p, vs, in, out, audio)
%% advancedChoiceWorld
% Burgess 2AUFC task with contrast discrimination and baited equal contrast
% trial conditions.  
% 2017-03-25 Added contrast discrimination MW
% 2017-08    Added baited trials (thanks PZH)
% 2017-09-26 Added manual reward key presses
% 2017-10-26 p.wheelGain now in mm/deg units
% 2018-03-15 Added time sampler function for delays

%% parameters
%wheel = in.wheel.skipRepeats(); % skipRepeats means that this signal doesn't update if the new value is the same of the previous one (i.e. if the wheel doesn't move)
wheel = in.wheelMM;

rewardKey = p.rewardKey.at(evts.expStart); % get value of rewardKey at experiemnt start, otherwise it will take the same value each new trial
rewardKeyPressed = in.keyboard.strcmp(rewardKey); % true each time the reward key is pressed
contrastLeft = p.stimulusContrast(1);
contrastRight = p.stimulusContrast(2);
oriLeft = p.stimulusOrientation(1);
oriRight = p.stimulusOrientation(2);
%correctColor = p.correctColor;
%rewardedOri = p.rewardedOrientation;
rewardProbability = p.rewardProbability;

% trialCount = at(double(0), evts.expStart);
% sumCount =  at(double(0), evts.expStart);



%% when to present stimuli & allow visual stim to move
% stimulus should come on after the wheel has been held still for the
% duration of the preStimulusDelay.  The quiescence threshold is a tenth of
% the rotary encoder resolution.
preStimulusDelay = p.preStimulusDelay.map(@timeSampler).at(evts.newTrial); % at(evts.newTrial) fix for rig pre-delay 
stimulusOn = sig.quiescenceWatch(preStimulusDelay, t, wheel, 0.01);
interactiveDelay = p.interactiveDelay.map(@timeSampler);
interactiveOn = stimulusOn.delay(interactiveDelay); % the closed-loop period starts when the stimulus comes on, plus an 'interactive delay'

audioDevice = audio.Devices('default');
onsetToneSamples = p.onsetToneAmplitude*...
    mapn(p.onsetToneFrequency, 0.1, audioDevice.DefaultSampleRate,...
    0.02, audioDevice.NrOutputChannels, @aud.pureTone); % aud.pureTone(freq, duration, samprate, "ramp duration", nAudChannels)
audio.default = onsetToneSamples.at(interactiveOn); % At the time of 'interative on', send samples to audio device and log as 'onsetTone'

audioSig = onsetToneSamples.at(interactiveOn);

closedLoopOnsetToneSamples = mapn(audioSig, p.numAudChannels, 1, @repmat);     %Puts beep on all channels
audO.Strix = closedLoopOnsetToneSamples.at(interactiveOn);                       %Sends beep to buffer

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
responseTimeOver = (t - t.at(interactiveOn)) > p.responseWindow; % p.responseWindow may be set to Inf
threshold = interactiveOn.setTrigger(...
  abs(stimulusDisplacement) >= abs(p.stimulusAzimuth) | responseTimeOver);

response = cond(...
    responseTimeOver, 0,... % if the response time is over the response = 0
    true, -sign(stimulusDisplacement)); % otherwise it should be the inverse of the sign of the stimulusDisplacement

response = response.at(threshold); % only update the response signal when the threshold has been crossed
stimulusOff = threshold.delay(1); % true a second after the threshold is crossed

%% define correct response and feedback
% 


count50 = t.Node.Net.origin('count50');
%rewardedOri = count50.merge(evts.expStart).scan(@(ori,~)90-ori, randsample([90,0],1));
c = clock;
rewardedOri = count50.merge(evts.expStart).scan(@(ori,~)90-ori, mod(c(3),2)*90);


correctResponse = cond(oriLeft == rewardedOri, -1, oriRight == rewardedOri, 1);

feedback = at(correctResponse == response, response);
evts.feedback = feedback;

trialsSinceSwitch = evts.trialNum - evts.trialNum.at(rewardedOri+1);
evts.trialsSnceSwitch = trialsSinceSwitch;
% block1 = iff(trialsSinceSwitch>=50, feedback.keepWhen(rewardedOri == 90).bufferUpTo(50), 0);
% block2 = iff(trialsSinceSwitch>=50, feedback.keepWhen(rewardedOri == 0).bufferUpTo(50), 0);

% success = at(true, merge(...
%     (block1.map(@sum)) >= 40 & rewardedOri == 90,...
%     (block2.map(@sum)) >= 40 & rewardedOri == 0));
success = at(true, trialsSinceSwitch>=p.maxBlockLen);
blockLen = at(trialsSinceSwitch, success);
evts.blockLen = blockLen;
evts.success = success;


% evts.block1Total = (block1.map(@sum) - block1.at(rewardedOri+1).map(@sum));
% evts.block2Total = (block2.map(@sum) - block2.at(rewardedOri+1).map(@sum));
%evts.rewardedOri = rewardedOri;

t.Node.Listeners = [t.Node.Listeners, success.into(count50)];
% 
% evts.oriLeft = oriLeft;
% evts.oriRight = oriRight;


noiseBurstSamples = p.noiseBurstAmp*...
    mapn(audioDevice.NrOutputChannels, p.noiseBurstDur*audioDevice.DefaultSampleRate, @randn);
%audio.default = noiseBurstSamples.at(feedback2==0); % When the subject gives an incorrect response, send samples to audio device and log as 'noiseBurst'
audio.default = noiseBurstSamples.at(feedback==0);

%tmp = merge(rewardKeyPressed, feedback2 > 0);
tmp = merge(rewardKeyPressed, feedback > 0);
reward = tmp.at(threshold);

out.reward = p.rewardSize.at(reward); % output this signal to the reward controller
out.laserShutter = p.rewardSize.at(reward);
% %% stimulus azimuth
% azimuth = cond(...
%     stimulusOn.to(interactiveOn), 0,... % Before the closed-loop condition, the stimulus is at it's starting azimuth
%     interactiveOn.to(threshold), stimulusDisplacement,... % Closed-loop condition, where the azimuth yoked to the wheel
%     threshold.to(stimulusOff),  -response*abs(p.stimulusAzimuth)); % Once threshold is reached the stimulus is fixed again


interTrialDelay = iff(feedback ==1, 0, [2.5,3.5]); %check if this works

%% End trial and log events
% Let's use the next set of conditional paramters only if positive feedback
% was given, or if the parameter 'Repeat incorrect' was set to false.mc
%nextCondition = feedback > 0 | p.repeatIncorrect == false; 
nextCondition = (feedback > 0 | evts.repeatNum >= (p.maxRepeatIncorrect+1));
%nextCondition = evts.repeatNum >= (p.maxRepeatIncorrect+1);

% we want to save these signals so we put them in events with appropriate
% names:
% evts.stimulusOn = stimulusOn;
evts.preStimulusDelay = preStimulusDelay;
%save the contrasts as a difference between left and right
% evts.contrast = p.stimulusContrast.map(@diff); 
% evts.contrastLeft = contrastLeft;
% evts.contrastRight = contrastRight;
%evts.azimuth = azimuth;
evts.response = response;
evts.feedback = feedback;
evts.interactiveOn = interactiveOn;
% Accumulate reward signals and append microlitre units
evts.totalReward = out.reward.scan(@plus, 0).map(fun.partial(@sprintf, '%.1fµl')); 
evts.response = response;
evts.correctResponse = correctResponse;
% evts.oriLeft = oriLeft;
% evts.oriRight = oriRight;
% Trial ends when evts.endTrial updates.  
% If the value of evts.endTrial is false, the current set of conditional
% parameters are used for the next trial, if evts.endTrial updates to true, 
% the next set of randowmly picked conditional parameters is used
evts.endTrial = nextCondition.at(stimulusOff).delay(interTrialDelay.map(@timeSampler)); 


%% Parameter defaults
% See timeSampler for full details on what values the *Delay paramters can
% take.  Conditional perameters are defined as having ncols > 1, where each
% column is a condition.  All conditional paramters must have the same
% number of columns.
try
% c = [1 0.5 0.25 0.12 0.06 0];
%%% Contrast starting set
% C = [1 0;0 1;0.5 0;0 0.5]';
%%% Contrast discrimination set
% c = combvec(c, c);
% C = unique([c, flipud(c)]', 'rows')';
%%% Contrast detection set
p.minBlockLen = 80;
p.maxBlockLen = 150;
p.maxRepeatIncorrect = 10;
p.stimulusContrast = [1;1];
p.repeatIncorrect = true;
p.onsetToneFrequency = 5000;
p.interactiveDelay = 2;
p.onsetToneAmplitude = 0.15;
p.responseWindow = Inf;
p.stimulusAzimuth = 90;
p.noiseBurstAmp = 0.01;
p.noiseBurstDur = 0.5;
p.rewardSize = 3;
p.rewardKey = 'r';
p.stimFlickerFrequency = 5;
%p.rewardColor = 0;
p.stimulusOrientation = [0; 90];
p.spatialFrequency = 0.19; % Prusky & Douglas, 2004
p.interTrialDelay = 0.5;
p.wheelGain = 5;
p.encoderRes = 1024;
p.preStimulusDelay = [0 0.1 0.09]';
p.rewardedOrientation = 90;
p.rewardProbability = 1; %how likely is mouse to get a reward for horizontal grating
p.numAudChannels = 7;
p.instrTrial = 0;
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
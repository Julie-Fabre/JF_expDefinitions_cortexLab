function baselineWorld(t, events, parameters, visStim, inputs, outputs, audio)
% vanillaChoiceworld(t, events, parameters, visStim, inputs, outputs, audio)
% 170309 - AP
%
% Choice world that adapts with behavior
%
% Task structure: 
% Start trial
% Resetting pre-stim quiescent period
% Stimulus onset
% Fixed cue interactive delay
% Infinite time for response, fix stim azimuth on response
% Short ITI on reward, long ITI on punish, then turn stim off
% End trial


rewardSize = 2; 
% Key press for manual reward
rewardKeyPressed = inputs.keyboard.strcmp('r');

%% Set up wheel 

wheel = inputs.wheelMM.skipRepeats();

%% Rewards

water = at(rewardSize,merge(rewardKeyPressed));  
outputs.reward = water;
totalWater = water.scan(@plus,0);

%% Display and save


% Performance

events.totalWater = totalWater;
events.endTrial = totalWater>1000000;%some random thing that will never happen because we need endtrial field 
end




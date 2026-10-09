%% create_four_talker_masker_sets.m
%
% Creates 36 independent four-talker speech-masker segments from the
% Glissando-sp Prosodic News corpus.
%
% INPUT MATERIAL
%   Corpus: Glissando-sp
%   Subcorpus: News / Prosodic
%   Speakers:
%       sp_f11r  (female news broadcaster)
%       sp_f13r  (female news broadcaster)
%       sp_m12r  (male news broadcaster)
%       sp_m14r  (male news broadcaster)
%   Recording type: .fix.wav
%
% PROCESSING
%   For each of 36 sets:
%       1. Select one recording from each speaker.
%       2. Ensure that the four recordings correspond to different
%          news items (different prnXX identifiers).
%       3. If a source WAV unexpectedly contains >1 channel, use channel 1.
%       4. Remove the first 1 s from every recording.
%       5. Remove DC offset.
%       6. Calculate whole-file RMS.
%       7. Normalize each recording to the same RMS.
%       8. Truncate all four recordings to the duration of the shortest.
%       9. Sum the four recordings.
%      10. Check for clipping.
%      11. Save the resulting four-talker masker segment.
%
% IMPORTANT
%   - Every prn01-prn36 recording is used exactly once per speaker.
%   - The same prnXX is never used by two speakers within the same set.
%   - No silence detection/removal is performed.
%   - The individual four-talker sets are NOT normalized after summation.
%   - The 36 sets are NOT concatenated in this script.
%   - Final normalization will be performed after later concatenation.
%
% OUTPUT
%   - 36 WAV files containing independent four-talker masker segments.
%   - CSV processing log.
%   - MAT file containing processing information and parameters.
%
% -------------------------------------------------------------------------

clear;
clc;


%% ========================================================================
%  USER SETTINGS
%  ========================================================================

% Root directory containing the News folders
rootDir = 'E:\S0406\News';

% Output directory
outputDir = fullfile(rootDir, 'Four_talker_masker_sets');

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% Four professional news broadcasters
speakers = {'sp_f11r', ...
            'sp_f13r', ...
            'sp_m12r', ...
            'sp_m14r'};

% Corpus subfolder
subfolder = 'Prosodic';

% Expected number of recordings per speaker
nRecordings = 36;

% Fixed amount removed from the beginning of every recording
initialTrim_s = 1.0;

% Common RMS assigned to every individual speaker recording.
%
% This value is deliberately conservative to provide headroom when
% four signals are summed.
targetRMS = 0.025;

% Output WAV bit depth
outputBits = 32;


%% ========================================================================
%  DEFINE RECORDING ASSIGNMENT
%  ========================================================================
%
% Each row represents one four-talker masker set.
% Each column represents one speaker.
%
% Circular shifts ensure that:
%   - every speaker uses every prn01-prn36 recording exactly once;
%   - the four recordings in a set always have different prn identifiers.
%
% Example:
%
% Set 01:
%   f11r -> prn01
%   f13r -> prn10
%   m12r -> prn19
%   m14r -> prn28
%
% Set 02:
%   f11r -> prn02
%   f13r -> prn11
%   m12r -> prn20
%   m14r -> prn29

baseOrder = (1:nRecordings)';

shifts = [0 9 18 27];

assignment = zeros(nRecordings, numel(speakers));

for s = 1:numel(speakers)

    assignment(:,s) = ...
        mod(baseOrder - 1 + shifts(s), nRecordings) + 1;

end


%% ========================================================================
%  VERIFY ASSIGNMENT MATRIX
%  ========================================================================

% Check that each masker set contains four different news items
for setIdx = 1:nRecordings

    if numel(unique(assignment(setIdx,:))) ~= numel(speakers)

        error(['Assignment error: Set %d contains repeated ' ...
               'news items.'], setIdx);

    end

end


% Check that every speaker uses recordings 1-36 exactly once
for s = 1:numel(speakers)

    if ~isequal(sort(assignment(:,s))', 1:nRecordings)

        error(['Assignment error: speaker %s does not use every ' ...
               'recording exactly once.'], speakers{s});

    end

end

fprintf('Assignment matrix successfully validated.\n\n');


%% ========================================================================
%  INITIALISE PROCESSING LOG
%  ========================================================================

processingLog = table;

processingLog.Set = (1:nRecordings)';

processingLog.Duration_s = zeros(nRecordings,1);
processingLog.MixtureRMS = zeros(nRecordings,1);
processingLog.MixturePeak = zeros(nRecordings,1);


%% ========================================================================
%  PROCESS THE 36 MASKER SETS
%  ========================================================================

for setIdx = 1:nRecordings

    fprintf('============================================================\n');
    fprintf('Processing masker set %02d of %02d\n', ...
            setIdx, nRecordings);
    fprintf('============================================================\n');

    % Temporary variables for this set
    audioData = cell(1,numel(speakers));
    sourceFiles = cell(1,numel(speakers));

    sampleRates = zeros(1,numel(speakers));
    originalRMS = zeros(1,numel(speakers));
    normalizedRMS = zeros(1,numel(speakers));
    originalPeak = zeros(1,numel(speakers));
    numChannels = zeros(1,numel(speakers));

    recordingNumbers = assignment(setIdx,:);


    %% --------------------------------------------------------------------
    %  LOAD AND PROCESS EACH SPEAKER
    %  --------------------------------------------------------------------

    for s = 1:numel(speakers)

        speaker = speakers{s};

        recordingNumber = recordingNumbers(s);


        %% Construct expected filename

        fileName = sprintf('%s_prn%02d.fix.wav', ...
                           speaker, recordingNumber);

        filePath = fullfile(rootDir, ...
                            speaker, ...
                            subfolder, ...
                            fileName);


        %% Confirm that source file exists

        if ~exist(filePath, 'file')

            error('Source file not found:\n%s', filePath);

        end


        fprintf('Speaker %s -> prn%02d\n', ...
                speaker, recordingNumber);


        %% Load audio

        [x, fs] = audioread(filePath);

        sampleRates(s) = fs;

        numChannels(s) = size(x,2);


        %% ---------------------------------------------------------------
        %  CHANNEL HANDLING
        %  ---------------------------------------------------------------
        %
        % Glissando News .fix.wav recordings are expected to be mono.
        %
        % However, at least one distributed file has been found to contain
        % two channels. To ensure deterministic processing:
        %
        %   - Mono files are used directly.
        %   - Multichannel files use CHANNEL 1 ONLY.
        %
        % Channels are NOT averaged.
        %
        % Any multichannel occurrence is printed to the command window and
        % recorded in the processing log.

        if size(x,2) > 1

            warning(['Multichannel source detected (%d channels):\n%s\n' ...
                     'Using CHANNEL 1 only.'], ...
                     size(x,2), filePath);

            x = x(:,1);

        end


        %% ---------------------------------------------------------------
        %  REMOVE FIRST 1 SECOND
        %  ---------------------------------------------------------------
        %
        % Fixed trimming is used to remove possible initial silence,
        % preparation noise, or inhalation.
        %
        % No silence detection is performed.

        nTrimSamples = round(initialTrim_s * fs);

        if length(x) <= nTrimSamples

            error(['Recording is shorter than the requested ' ...
                   'initial trim:\n%s'], filePath);

        end

        x = x(nTrimSamples + 1:end);


        %% ---------------------------------------------------------------
        %  REMOVE DC OFFSET
        %  ---------------------------------------------------------------

        x = x - mean(x);


        %% ---------------------------------------------------------------
        %  CALCULATE ORIGINAL WHOLE-FILE RMS
        %  ---------------------------------------------------------------

        rmsBefore = sqrt(mean(x.^2));

        if rmsBefore == 0

            error('Zero RMS encountered in file:\n%s', filePath);

        end

        originalRMS(s) = rmsBefore;

        originalPeak(s) = max(abs(x));


        %% ---------------------------------------------------------------
        %  RMS NORMALIZATION
        %  ---------------------------------------------------------------
        %
        % Every individual speaker recording is assigned the same
        % long-term RMS before the four speakers are mixed.

        x = x .* (targetRMS / rmsBefore);


        %% Verify normalized RMS

        normalizedRMS(s) = sqrt(mean(x.^2));


        %% Store processed waveform

        audioData{s} = x;

        sourceFiles{s} = fileName;

    end


    %% ====================================================================
    %  VERIFY COMMON SAMPLING RATE
    %  ====================================================================

    if numel(unique(sampleRates)) ~= 1

        error(['Sampling-rate mismatch in set %02d. ' ...
               'Resampling has deliberately not been performed.'], ...
               setIdx);

    end

    fs = sampleRates(1);


    %% ====================================================================
    %  FIND SHORTEST RECORDING
    %  ====================================================================

    lengths = cellfun(@length, audioData);

    minLength = min(lengths);

    duration_s = minLength / fs;


    %% ====================================================================
    %  TRUNCATE ALL FOUR RECORDINGS TO COMMON LENGTH
    %  ====================================================================

    for s = 1:numel(speakers)

        audioData{s} = audioData{s}(1:minLength);

    end


    %% ====================================================================
    %  SUM THE FOUR SPEAKERS
    %  ====================================================================

    mixture = zeros(minLength,1);

    for s = 1:numel(speakers)

        mixture = mixture + audioData{s};

    end


    %% ====================================================================
    %  CALCULATE MIXTURE STATISTICS
    %  ====================================================================

    mixtureRMS = sqrt(mean(mixture.^2));

    mixturePeak = max(abs(mixture));


    %% ====================================================================
    %  CHECK FOR DIGITAL CLIPPING
    %  ====================================================================
    %
    % Do NOT normalize individual masker sets here.
    %
    % If clipping occurs, processing stops so that the common targetRMS
    % can be reduced and ALL sets regenerated consistently.

    if mixturePeak >= 1

        error(['Potential clipping in masker set %02d.\n' ...
               'Peak absolute amplitude = %.4f\n' ...
               'Reduce targetRMS and rerun all sets.'], ...
               setIdx, mixturePeak);

    end


    %% ====================================================================
    %  SAVE FOUR-TALKER MASKER SEGMENT
    %  ====================================================================

    outputFileName = sprintf('masker_set_%02d.wav', setIdx);

    outputPath = fullfile(outputDir, outputFileName);

    audiowrite(outputPath, ...
               mixture, ...
               fs, ...
               'BitsPerSample', outputBits);


    %% ====================================================================
    %  ADD INFORMATION TO PROCESSING LOG
    %  ====================================================================

    processingLog.Duration_s(setIdx) = duration_s;

    processingLog.MixtureRMS(setIdx) = mixtureRMS;

    processingLog.MixturePeak(setIdx) = mixturePeak;


    % Store information separately for each speaker
    for s = 1:numel(speakers)

        speakerLabel = erase(speakers{s}, 'sp_');

        recVar = sprintf('%s_prn', speakerLabel);
        fileVar = sprintf('%s_file', speakerLabel);
        rmsVar = sprintf('%s_originalRMS', speakerLabel);
        normRmsVar = sprintf('%s_normalizedRMS', speakerLabel);
        peakVar = sprintf('%s_originalPeak', speakerLabel);
        channelVar = sprintf('%s_NumChannels', speakerLabel);

        processingLog.(recVar)(setIdx) = ...
            recordingNumbers(s);

        processingLog.(fileVar){setIdx} = ...
            sourceFiles{s};

        processingLog.(rmsVar)(setIdx) = ...
            originalRMS(s);

        processingLog.(normRmsVar)(setIdx) = ...
            normalizedRMS(s);

        processingLog.(peakVar)(setIdx) = ...
            originalPeak(s);

        processingLog.(channelVar)(setIdx) = ...
            numChannels(s);

    end


    %% ====================================================================
    %  DISPLAY SET SUMMARY
    %  ====================================================================

    fprintf('\n');

    fprintf('Duration:       %.2f s\n', duration_s);

    fprintf('Mixture RMS:    %.6f\n', mixtureRMS);

    fprintf('Mixture peak:   %.6f\n', mixturePeak);

    fprintf('Saved: %s\n\n', outputFileName);

end


%% ========================================================================
%  SAVE PROCESSING LOG
%  ========================================================================

csvPath = fullfile(outputDir, ...
                   'masker_processing_log.csv');

writetable(processingLog, csvPath);


%% ========================================================================
%  SAVE MATLAB PROCESSING INFORMATION
%  ========================================================================

matPath = fullfile(outputDir, ...
                   'masker_processing_info.mat');

save(matPath, ...
     'processingLog', ...
     'assignment', ...
     'speakers', ...
     'rootDir', ...
     'subfolder', ...
     'initialTrim_s', ...
     'targetRMS', ...
     'outputBits');


%% ========================================================================
%  FINAL SUMMARY
%  ========================================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('MASKER SET CREATION COMPLETE\n');
fprintf('============================================================\n');

fprintf('Number of masker sets: %d\n', nRecordings);

fprintf('Output directory:\n%s\n\n', outputDir);

fprintf('Mean set duration: %.2f s\n', ...
        mean(processingLog.Duration_s));

fprintf('Total duration available after future concatenation: %.2f min\n', ...
        sum(processingLog.Duration_s) / 60);

fprintf('Mean mixture RMS: %.6f\n', ...
        mean(processingLog.MixtureRMS));

fprintf('Maximum mixture peak: %.6f\n', ...
        max(processingLog.MixturePeak));


%% ========================================================================
%  REPORT ANY MULTICHANNEL SOURCE FILES
%  ========================================================================

fprintf('\n');
fprintf('------------------------------------------------------------\n');
fprintf('MULTICHANNEL SOURCE CHECK\n');
fprintf('------------------------------------------------------------\n');

nMultichannel = 0;

for s = 1:numel(speakers)

    speakerLabel = erase(speakers{s}, 'sp_');

    channelVar = sprintf('%s_NumChannels', speakerLabel);
    fileVar = sprintf('%s_file', speakerLabel);

    idx = find(processingLog.(channelVar) > 1);

    for k = 1:numel(idx)

        nMultichannel = nMultichannel + 1;

        fprintf('%s : %d channels -> channel 1 used\n', ...
                processingLog.(fileVar){idx(k)}, ...
                processingLog.(channelVar)(idx(k)));

    end

end

if nMultichannel == 0

    fprintf('All source recordings were mono.\n');

else

    fprintf('\nTotal multichannel source files: %d\n', ...
            nMultichannel);

end


fprintf('\n');
fprintf('No concatenation or final masker normalization was performed.\n');
fprintf('============================================================\n');
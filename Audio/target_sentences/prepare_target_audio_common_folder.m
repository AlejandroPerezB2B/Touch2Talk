function prepare_target_audio_common_folder()
% PREPARE_TARGET_AUDIO_COMMON_FOLDER
%
% Creates a single PsychoPy-ready folder containing all existing target
% sentence WAV files.
%
% Processing:
%   1. Recursively finds the WAVs in the six FORMA folders.
%   2. Parses the stimulus code from filenames such as:
%          "17 - 3.9.wav"
%          "28 - 4b.12.wav"
%   3. Converts all recordings to mono if necessary.
%   4. Resamples recordings to 44100 Hz when necessary.
%   5. Does NOT normalize amplitude.
%   6. Does NOT trim audio.
%   7. Does NOT modify the original files.
%   8. Saves files using simplified names:
%          3.9.wav
%          4b.12.wav
%   9. Generates a CSV processing log.
%  10. Performs final integrity checks.
%
% Expected corpus:
%   296 existing WAV files
%
% Known missing WAVs:
%   3.6
%   4b.4
%   3.10
%   3.21
%
% IMPORTANT:
% The output directory is intentionally placed outside the six source
% FORMA directories so that it is never picked up as source material.

%% ============================================================
% SETTINGS
% =============================================================

rootDir = 'E:\Formas_1_a_6_sin_ruido';

outputDir = fullfile(rootDir, 'PsychoPy_target_audio_44100Hz');

targetFs = 44100;

expectedN = 296;

knownMissing = {
    '3.6'
    '4b.4'
    '3.10'
    '3.21'
    };

formaFolders = {
    'FORMA 1-1 y 2b'
    'FORMA 2-2 y 3b'
    'FORMA 3-3 y 4b'
    'FORMA 4-4 y 5b'
    'FORMA 5-5 y 6b'
    'FORMA 6-6 y 1b'
    };

%% ============================================================
% SAFETY CHECKS
% =============================================================

if ~isfolder(rootDir)
    error('Root directory does not exist:\n%s', rootDir);
end

fprintf('\n============================================================\n');
fprintf('TARGET AUDIO PREPARATION\n');
fprintf('============================================================\n');
fprintf('Source root: %s\n', rootDir);
fprintf('Output:      %s\n', outputDir);
fprintf('Target Fs:   %d Hz\n\n', targetFs);

% Prevent accidental mixing with an earlier run.
if isfolder(outputDir)

    existingOutput = dir(fullfile(outputDir, '*.wav'));

    if ~isempty(existingOutput)
        error(['Output folder already contains WAV files.\n' ...
               'For safety, nothing has been overwritten.\n\n' ...
               'Please inspect/delete/rename this folder first:\n%s'], ...
               outputDir);
    end

else
    mkdir(outputDir);
end

%% ============================================================
% DISCOVER SOURCE FILES
% =============================================================

sourceFiles = struct([]);

for f = 1:numel(formaFolders)

    thisDir = fullfile(rootDir, formaFolders{f});

    if ~isfolder(thisDir)
        error('Missing source folder:\n%s', thisDir);
    end

    wavs = dir(fullfile(thisDir, '*.wav'));

    if isempty(wavs)
        error('No WAV files found in:\n%s', thisDir);
    end

    if isempty(sourceFiles)
        sourceFiles = wavs;
    else
        sourceFiles = [sourceFiles; wavs]; %#ok<AGROW>
    end
end

fprintf('Existing source WAV files found: %d\n', numel(sourceFiles));

if numel(sourceFiles) ~= expectedN
    error(['Expected %d source WAV files but found %d.\n' ...
           'No processing performed.'], ...
           expectedN, numel(sourceFiles));
end

%% ============================================================
% PREALLOCATE LOG
% =============================================================

nFiles = numel(sourceFiles);

StimulusCode       = strings(nFiles,1);
OriginalFilename   = strings(nFiles,1);
OriginalPath       = strings(nFiles,1);
OutputFilename     = strings(nFiles,1);
OutputPath         = strings(nFiles,1);

OriginalFs         = zeros(nFiles,1);
OutputFs           = zeros(nFiles,1);

OriginalChannels   = zeros(nFiles,1);
OutputChannels     = zeros(nFiles,1);

OriginalDuration_s = zeros(nFiles,1);
OutputDuration_s   = zeros(nFiles,1);

OriginalRMS        = zeros(nFiles,1);
OutputRMS          = zeros(nFiles,1);

OriginalPeak       = zeros(nFiles,1);
OutputPeak         = zeros(nFiles,1);

WasResampled       = false(nFiles,1);
WasConvertedToMono = false(nFiles,1);

%% ============================================================
% FIRST PASS: PARSE CODES BEFORE WRITING ANYTHING
% =============================================================

fprintf('\nValidating filenames before audio processing...\n');

for k = 1:nFiles

    originalName = sourceFiles(k).name;

    [~, baseName, ext] = fileparts(originalName);

    if ~strcmpi(ext,'.wav')
        error('Unexpected non-WAV file: %s', originalName);
    end

    % Expected examples:
    %   1 - 1.1
    %   27 - 2b.9
    %
    % Captures only the actual stimulus code.

    tokens = regexp(baseName, ...
        '^\s*\d+\s*-\s*([1-6](?:b?)\.\d{1,2})\s*$', ...
        'tokens','once');

    if isempty(tokens)
        error('Could not parse stimulus code from:\n%s', originalName);
    end

    StimulusCode(k) = string(tokens{1});
    OriginalFilename(k) = string(originalName);

    originalPath = fullfile(sourceFiles(k).folder, originalName);
    OriginalPath(k) = string(originalPath);

    simplifiedName = StimulusCode(k) + ".wav";

    OutputFilename(k) = simplifiedName;
    OutputPath(k) = string(fullfile(outputDir, simplifiedName));

end

%% ============================================================
% CHECK FOR DUPLICATE CODES
% =============================================================

if numel(unique(StimulusCode)) ~= nFiles

    [uCodes,~,idx] = unique(StimulusCode);
    counts = accumarray(idx,1);

    duplicateCodes = uCodes(counts > 1);

    fprintf('\nDuplicate stimulus codes detected:\n');

    for d = 1:numel(duplicateCodes)
        fprintf('  %s\n', duplicateCodes(d));
    end

    error(['Duplicate simplified filenames would be created. ' ...
           'No audio has been processed.']);
end

%% ============================================================
% VERIFY THE FOUR KNOWN MISSING CODES
% =============================================================

fprintf('\nKnown missing WAV check:\n');

for m = 1:numel(knownMissing)

    code = string(knownMissing{m});

    if any(StimulusCode == code)
        error(['Known missing code unexpectedly exists: %s\n' ...
               'Stop and inspect the source corpus.'], code);
    else
        fprintf('  Confirmed absent: %s\n', code);
    end
end

%% ============================================================
% VERIFY COMPLETE THEORETICAL CODE SET
% =============================================================

expectedCodes = strings(300,1);

c = 0;

for fam = 1:6
    for num = 1:25

        c = c + 1;
        expectedCodes(c) = sprintf('%d.%d', fam, num);

        c = c + 1;
        expectedCodes(c) = sprintf('%db.%d', fam, num);

    end
end

actuallyMissing = setdiff(expectedCodes, StimulusCode);

if numel(actuallyMissing) ~= 4 || ...
        ~isempty(setxor(actuallyMissing, string(knownMissing)))

    fprintf('\nUnexpected missing-code pattern:\n');
    disp(actuallyMissing);

    error('Corpus does not contain the expected 296-code structure.');
end

fprintf('\nFilename/code validation passed.\n');

%% ============================================================
% PROCESS AUDIO
% =============================================================

fprintf('\n============================================================\n');
fprintf('PROCESSING AUDIO\n');
fprintf('============================================================\n\n');

for k = 1:nFiles

    inFile  = char(OriginalPath(k));
    outFile = char(OutputPath(k));

    info = audioinfo(inFile);

    OriginalFs(k)       = info.SampleRate;
    OriginalChannels(k) = info.NumChannels;
    OriginalDuration_s(k) = info.Duration;

    [x, fs] = audioread(inFile);

    % ---------------------------------------------------------
    % Channel handling
    % ---------------------------------------------------------

    if size(x,2) == 1

        WasConvertedToMono(k) = false;

    elseif size(x,2) == 2

        % Conservative stereo -> mono conversion.
        % Current validated target corpus should already be mono,
        % but this makes the script robust to an unexpected file.

        x = mean(x,2);
        WasConvertedToMono(k) = true;

        warning('Converted stereo file to mono: %s', ...
            OriginalFilename(k));

    else

        error(['Unexpected number of channels (%d) in:\n%s'], ...
            size(x,2), inFile);
    end

    % ---------------------------------------------------------
    % Original level statistics
    % ---------------------------------------------------------

    OriginalRMS(k)  = sqrt(mean(x.^2));
    OriginalPeak(k) = max(abs(x));

    % ---------------------------------------------------------
    % Sample-rate conversion
    % ---------------------------------------------------------

    if fs ~= targetFs

        x = resample(x, targetFs, fs);

        WasResampled(k) = true;

    else

        WasResampled(k) = false;
    end

    % ---------------------------------------------------------
    % Safety: do NOT normalize.
    % ---------------------------------------------------------

    peakAfter = max(abs(x));

    if peakAfter > 1

        error(['Resampling produced a peak above digital full scale.\n' ...
               'Stimulus: %s\n' ...
               'Peak: %.6f\n\n' ...
               'Nothing will be normalized automatically.'], ...
               StimulusCode(k), peakAfter);
    end

    % ---------------------------------------------------------
    % Save
    % ---------------------------------------------------------

    audiowrite(outFile, x, targetFs);

    % ---------------------------------------------------------
    % Verify written file
    % ---------------------------------------------------------

    outInfo = audioinfo(outFile);

    OutputFs(k)         = outInfo.SampleRate;
    OutputChannels(k)   = outInfo.NumChannels;
    OutputDuration_s(k) = outInfo.Duration;

    y = audioread(outFile);

    OutputRMS(k)  = sqrt(mean(y.^2));
    OutputPeak(k) = max(abs(y));

    fprintf('%3d/%3d  %-8s  %5d -> %5d Hz  %s\n', ...
        k, nFiles, StimulusCode(k), ...
        OriginalFs(k), OutputFs(k), OutputFilename(k));

end

%% ============================================================
% CREATE PROCESSING LOG
% =============================================================

processingLog = table( ...
    StimulusCode, ...
    OriginalFilename, ...
    OriginalPath, ...
    OutputFilename, ...
    OutputPath, ...
    OriginalFs, ...
    OutputFs, ...
    OriginalChannels, ...
    OutputChannels, ...
    OriginalDuration_s, ...
    OutputDuration_s, ...
    OriginalRMS, ...
    OutputRMS, ...
    OriginalPeak, ...
    OutputPeak, ...
    WasResampled, ...
    WasConvertedToMono);

logFile = fullfile(outputDir, ...
    'target_audio_processing_log.csv');

writetable(processingLog, logFile);

%% ============================================================
% FINAL OUTPUT VALIDATION
% =============================================================

fprintf('\n============================================================\n');
fprintf('FINAL VALIDATION\n');
fprintf('============================================================\n');

outputWavs = dir(fullfile(outputDir,'*.wav'));

fprintf('Output WAV files: %d\n', numel(outputWavs));

if numel(outputWavs) ~= expectedN
    error('Expected %d output WAVs but found %d.', ...
        expectedN, numel(outputWavs));
end

if any(OutputFs ~= targetFs)
    error('Not all output files have the target sample rate.');
end

if any(OutputChannels ~= 1)
    error('Not all output files are mono.');
end

if numel(unique(OutputFilename)) ~= expectedN
    error('Output filenames are not unique.');
end

%% ============================================================
% DURATION CONSISTENCY
% =============================================================

durationDifference = abs( ...
    OutputDuration_s - OriginalDuration_s);

maxDurationDifference = max(durationDifference);

fprintf('Maximum duration difference after processing: %.6f s\n', ...
    maxDurationDifference);

% Allow approximately two target-rate samples for rounding.
durationTolerance = 2 / targetFs;

if maxDurationDifference > durationTolerance

    warning(['At least one resampled file differs in duration by more ' ...
             'than %.6f s. Inspect processing log.'], ...
             durationTolerance);
end

%% ============================================================
% LEVEL CHECK
% =============================================================

fprintf('\nSample-rate conversion summary:\n');

originalRates = unique(OriginalFs);

for r = 1:numel(originalRates)

    thisFs = originalRates(r);

    fprintf('  %5d Hz : %d source files\n', ...
        thisFs, sum(OriginalFs == thisFs));
end

fprintf('\nFiles resampled: %d\n', sum(WasResampled));
fprintf('Files already at %d Hz: %d\n', ...
    targetFs, sum(~WasResampled));

fprintf('Files converted to mono: %d\n', ...
    sum(WasConvertedToMono));

fprintf('\nOutput peak range:\n');
fprintf('  Minimum file peak: %.6f\n', min(OutputPeak));
fprintf('  Maximum file peak: %.6f\n', max(OutputPeak));

fprintf('\nOutput RMS range:\n');
fprintf('  Minimum file RMS: %.6f\n', min(OutputRMS));
fprintf('  Maximum file RMS: %.6f\n', max(OutputRMS));

%% ============================================================
% FINAL MESSAGE
% =============================================================

fprintf('\n============================================================\n');
fprintf('TARGET AUDIO PREPARATION COMPLETE\n');
fprintf('============================================================\n');

fprintf('Output directory:\n%s\n\n', outputDir);

fprintf('WAV files created: %d\n', expectedN);
fprintf('Output sample rate: %d Hz\n', targetFs);
fprintf('Output channels: mono\n');

fprintf('\nOriginal files were NOT modified.\n');
fprintf('No RMS normalization was performed.\n');
fprintf('No trimming was performed.\n');

fprintf('\nSimplified naming example:\n');
fprintf('  "17 - 3.9.wav" -> "3.9.wav"\n');

fprintf('\nProcessing log:\n%s\n', logFile);

end
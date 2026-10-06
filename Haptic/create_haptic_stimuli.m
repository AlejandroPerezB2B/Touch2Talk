function manifest = create_haptic_stimuli(inputFolder, outputRoot, varargin)
% CREATE_HAPTIC_STIMULI Create speech-derived vibrotactile stimulation files.
%
%   manifest = create_haptic_stimuli(inputFolder, outputRoot)
%
% Processes all WAV files in inputFolder using a Rautu-style haptic
% transformation:
%
%   1. Convert source speech to mono.
%   2. Normalize every stimulus to the same RMS level.
%      If the requested target RMS would cause clipping in any file, a
%      single lower RMS target is chosen for the ENTIRE stimulus set.
%   3. Filter normalized speech through a 31-channel gammatone filterbank
%      with Mel-spaced centre frequencies from 150 to 7000 Hz.
%   4. Use gammatoneFast(..., align=true) to compensate filterbank delays.
%   5. Extract the Hilbert amplitude envelope independently in each band.
%   6. Average envelopes across bands. No low-pass filtering is applied.
%   7. Scale all composite envelopes using ONE global envelope scale.
%   8. Amplitude-modulate a 150-Hz sinusoidal carrier.
%   9. Apply ONE global haptic gain to all files.
%  10. Save normalized speech, raw/scaled envelopes, haptic WAV files,
%      QC figures, and CSV/MAT manifests.
%
% REQUIRED DEPENDENCY
%   The IoSR Matlab Toolbox must be on the MATLAB path, with its original
%   package-folder structure preserved:
%
%       <toolbox_root>\+iosr\+auditory\gammatoneFast.m
%
%   Add <toolbox_root> (the folder containing +iosr) to the MATLAB path.
%
%   This function calls:
%
%       filtered = iosr.auditory.gammatoneFast( ...
%           x, centerFreqs, fs, align)
%
%   where align=true enables delay alignment.
%
% INPUTS
%   inputFolder : Folder containing the common-folder WAV stimuli produced
%                 by prepare_target_audio_common_folder.m.
%
%   outputRoot  : Root output folder. Subfolders are created automatically:
%                   normalized_speech/
%                   envelopes/
%                   haptic_wav/
%                   qc/
%
% NAME-VALUE OPTIONS
%   'TargetSpeechRMSdBFS' : Desired common RMS level in dBFS.
%                           Default = -25.
%
%   'PeakLimit'           : Maximum allowed absolute speech sample value.
%                           Default = 0.99.
%
%   'NumBands'            : Number of gammatone bands.
%                           Default = 31.
%
%   'LowFrequency'        : Lowest centre frequency in Hz.
%                           Default = 150.
%
%   'HighFrequency'       : Highest centre frequency in Hz.
%                           Default = 7000.
%
%   'CarrierFrequency'    : Vibrotactile carrier frequency in Hz.
%                           Default = 150.
%
%   'HapticGain'          : ONE multiplicative gain applied to all final
%                           haptic signals after global envelope scaling.
%                           Default = 0.95.
%
%   'BitsPerSample'       : WAV bit depth for saved speech/haptic files.
%                           Default = 24.
%
%   'SaveQC'              : Save one QC PNG per stimulus.
%                           Default = true.
%
% OUTPUT
%   manifest : MATLAB table containing file-level QC/statistics.
%
% MANIFEST FIELDS
%   filename
%   fs
%   duration_s
%   original_rms
%   normalized_rms
%   normalized_rms_dbfs
%   original_peak
%   normalized_peak
%   speech_gain
%   carrier_frequency_hz
%   haptic_rms
%   haptic_peak
%   raw_envelope_rms
%   raw_envelope_peak
%   scaled_envelope_rms
%   scaled_envelope_peak
%   envelope_source_corr
%
% NOTES
%   - No low-pass filter is applied to the extracted envelope.
%   - The speech RMS target is identical across files.
%   - Envelope scaling is global across the complete set, not filewise.
%   - HapticGain is identical across files.
%
% EXAMPLE
%   manifest = create_haptic_stimuli( ...
%       'D:\project\stimuli\common', ...
%       'D:\project\stimuli\haptic');
%
% -------------------------------------------------------------------------
% Project: pre-register haptic entrainment
% -------------------------------------------------------------------------

%% Parse inputs

p = inputParser;

addRequired(p, 'inputFolder', @(x) ischar(x) || isstring(x));
addRequired(p, 'outputRoot', @(x) ischar(x) || isstring(x));

addParameter(p, 'TargetSpeechRMSdBFS', -25, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x));

addParameter(p, 'PeakLimit', 0.99, ...
    @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);

addParameter(p, 'NumBands', 31, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 1 && mod(x,1) == 0);

addParameter(p, 'LowFrequency', 150, ...
    @(x) isnumeric(x) && isscalar(x) && x > 0);

addParameter(p, 'HighFrequency', 7000, ...
    @(x) isnumeric(x) && isscalar(x) && x > 0);

addParameter(p, 'CarrierFrequency', 150, ...
    @(x) isnumeric(x) && isscalar(x) && x > 0);

addParameter(p, 'HapticGain', 0.95, ...
    @(x) isnumeric(x) && isscalar(x) && x > 0);

addParameter(p, 'BitsPerSample', 24, ...
    @(x) isnumeric(x) && isscalar(x) && ismember(x,[8 16 24 32]));

addParameter(p, 'SaveQC', true, ...
    @(x) islogical(x) || (isnumeric(x) && isscalar(x)));

parse(p, inputFolder, outputRoot, varargin{:});
opt = p.Results;

inputFolder = char(inputFolder);
outputRoot  = char(outputRoot);

if opt.HighFrequency <= opt.LowFrequency
    error('HighFrequency must be greater than LowFrequency.');
end

gammatonePath = which('iosr.auditory.gammatoneFast');

if isempty(gammatonePath)
    error([ ...
        'iosr.auditory.gammatoneFast was not found on the MATLAB path. ', ...
        'Restore the IoSR package folder name to +iosr and add the folder ', ...
        'containing +iosr to the MATLAB path. For example: ', ...
        'addpath(''E:\S0406\gammatone_filterbank-1.17.0'')']);
end

fprintf('Using gammatone implementation:\n%s\n', gammatonePath);

%% Locate input WAV files

files = dir(fullfile(inputFolder, '*.wav'));

if isempty(files)
    error('No WAV files found in: %s', inputFolder);
end

[~, order] = sort(lower({files.name}));
files = files(order);

nFiles = numel(files);

%% Create output folders

normalizedFolder = fullfile(outputRoot, 'normalized_speech');
envelopeFolder   = fullfile(outputRoot, 'envelopes');
hapticFolder     = fullfile(outputRoot, 'haptic_wav');
qcFolder         = fullfile(outputRoot, 'qc');

folders = {outputRoot, normalizedFolder, envelopeFolder, ...
           hapticFolder, qcFolder};

for i = 1:numel(folders)
    if ~exist(folders{i}, 'dir')
        mkdir(folders{i});
    end
end

%% Pass 0: inspect all files and determine one common achievable RMS target

requestedRMS = 10^(opt.TargetSpeechRMSdBFS / 20);

originalRMS  = zeros(nFiles,1);
originalPeak = zeros(nFiles,1);
fsList       = zeros(nFiles,1);
nSamples     = zeros(nFiles,1);

% Maximum common target RMS that would keep every file below PeakLimit.
maxAllowedTargetRMS = inf(nFiles,1);

for i = 1:nFiles

    inFile = fullfile(files(i).folder, files(i).name);
    [x, fs] = audioread(inFile);

    x = local_make_mono(x);
    x = double(x(:));

    if isempty(x) || all(x == 0)
        error('Stimulus is empty or silent: %s', files(i).name);
    end

    if fs/2 <= opt.HighFrequency
        error(['Sampling rate for %s is too low. Nyquist frequency must ', ...
               'be greater than %.1f Hz.'], files(i).name, opt.HighFrequency);
    end

    r = local_rms(x);
    pk = max(abs(x));

    originalRMS(i)  = r;
    originalPeak(i) = pk;
    fsList(i)       = fs;
    nSamples(i)     = numel(x);

    % If x is multiplied by targetRMS/r, peak becomes:
    % pk * targetRMS/r.
    % Require this <= PeakLimit.
    maxAllowedTargetRMS(i) = opt.PeakLimit * r / pk;
end

commonRMS = min(requestedRMS, min(maxAllowedTargetRMS));

if commonRMS < requestedRMS
    warning(['Requested speech RMS of %.2f dBFS would cause clipping in at ', ...
             'least one stimulus. A single common RMS of %.2f dBFS will be ', ...
             'used for ALL files.'], ...
             opt.TargetSpeechRMSdBFS, 20*log10(commonRMS));
end

commonRMSdBFS = 20 * log10(commonRMS);

%% Centre frequencies: 31 equally spaced positions on Mel scale

melLow  = local_hz2mel(opt.LowFrequency);
melHigh = local_hz2mel(opt.HighFrequency);

melCenters = linspace(melLow, melHigh, opt.NumBands);
centerFreqs = local_mel2hz(melCenters);

%% Preallocate storage for second global scaling step

rawEnvelopes = cell(nFiles,1);
normSpeech   = cell(nFiles,1);

speechGain       = zeros(nFiles,1);
normalizedRMS    = zeros(nFiles,1);
normalizedPeak   = zeros(nFiles,1);
rawEnvelopeRMS   = zeros(nFiles,1);
rawEnvelopePeak  = zeros(nFiles,1);
envSourceCorr    = zeros(nFiles,1);

globalEnvelopePeak = 0;

%% Pass 1: normalize speech and derive raw aligned envelopes

fprintf('Pass 1/2: normalizing speech and extracting envelopes...\n');

for i = 1:nFiles

    inFile = fullfile(files(i).folder, files(i).name);
    [x, fs] = audioread(inFile);

    x = local_make_mono(x);
    x = double(x(:));

    % -------------------------------------------------------------
    % Common RMS normalization
    % -------------------------------------------------------------

    gain = commonRMS / local_rms(x);
    xNorm = x * gain;

    % This should only guard floating-point tolerance because commonRMS
    % was chosen globally to satisfy PeakLimit.
    if max(abs(xNorm)) > opt.PeakLimit + 1e-12
        error('Unexpected peak-limit violation for %s.', files(i).name);
    end

    % -------------------------------------------------------------
    % Gammatone filter bank with alignment explicitly ON
    % -------------------------------------------------------------

    filtered = iosr.auditory.gammatoneFast( ...
        xNorm, centerFreqs, fs, true);

    % Standardize orientation to samples x bands.
    if size(filtered,1) == opt.NumBands && size(filtered,2) == numel(xNorm)
        filtered = filtered.';
    end

    if size(filtered,1) ~= numel(xNorm) || size(filtered,2) ~= opt.NumBands
        error(['Unexpected dimensions returned by gammatoneFast for %s. ', ...
               'Expected samples x %d bands.'], files(i).name, opt.NumBands);
    end

    % -------------------------------------------------------------
    % Hilbert envelope in each band; NO low-pass filtering
    % -------------------------------------------------------------

    bandEnvelope = abs(hilbert(filtered));

    % Composite broadband envelope
    env = mean(bandEnvelope, 2);

    % -------------------------------------------------------------
    % Envelope/source correlation
    %
    % Compare the Rautu-style composite envelope with the broadband
    % Hilbert magnitude of the normalized source waveform.
    % No extra low-pass filtering is applied to either envelope.
    % -------------------------------------------------------------

    sourceEnvelope = abs(hilbert(xNorm));

    if std(env) == 0 || std(sourceEnvelope) == 0
        thisCorr = NaN;
    else
        C = corrcoef(env, sourceEnvelope);
        thisCorr = C(1,2);
    end

    % -------------------------------------------------------------
    % Save normalized speech now
    % -------------------------------------------------------------

    [~, baseName] = fileparts(files(i).name);

    normOut = fullfile(normalizedFolder, ...
        sprintf('%s_norm.wav', baseName));

    audiowrite(normOut, xNorm, fs, ...
        'BitsPerSample', opt.BitsPerSample);

    % Store for global envelope scaling in pass 2
    normSpeech{i}   = xNorm;
    rawEnvelopes{i} = env;

    speechGain(i)      = gain;
    normalizedRMS(i)   = local_rms(xNorm);
    normalizedPeak(i)  = max(abs(xNorm));
    rawEnvelopeRMS(i)  = local_rms(env);
    rawEnvelopePeak(i) = max(env);
    envSourceCorr(i)   = thisCorr;

    globalEnvelopePeak = max(globalEnvelopePeak, max(env));

end

if globalEnvelopePeak <= 0 || ~isfinite(globalEnvelopePeak)
    error('Invalid global envelope peak.');
end

%% Pass 2: one global envelope scale + one global haptic gain

fprintf('Pass 2/2: creating haptic carrier signals and QC outputs...\n');

scaledEnvelopeRMS  = zeros(nFiles,1);
scaledEnvelopePeak = zeros(nFiles,1);
hapticRMS          = zeros(nFiles,1);
hapticPeak         = zeros(nFiles,1);
duration_s         = zeros(nFiles,1);

for i = 1:nFiles

    fs    = fsList(i);
    xNorm = normSpeech{i};
    env   = rawEnvelopes{i};

    [~, baseName] = fileparts(files(i).name);

    % -------------------------------------------------------------
    % GLOBAL envelope scaling
    %
    % Every file is divided by the SAME maximum envelope value from
    % the whole stimulus set.
    % -------------------------------------------------------------

    envScaled = env ./ globalEnvelopePeak;

    % 150-Hz carrier
    t = (0:numel(envScaled)-1)' / fs;
    carrier = sin(2*pi*opt.CarrierFrequency*t);

    % ONE global haptic gain, identical for every file
    haptic = opt.HapticGain .* envScaled .* carrier;

    % -------------------------------------------------------------
    % Save envelope data
    % -------------------------------------------------------------

    envelopeFile = fullfile(envelopeFolder, ...
        sprintf('%s_envelope.mat', baseName));

    rawEnvelope       = env; %#ok<NASGU>
    scaledEnvelope    = envScaled; %#ok<NASGU>
    samplingRate      = fs; %#ok<NASGU>
    carrierFrequency  = opt.CarrierFrequency; %#ok<NASGU>
    gammatoneCentersHz = centerFreqs; %#ok<NASGU>
    globalEnvPeak     = globalEnvelopePeak; %#ok<NASGU>
    commonSpeechRMS   = commonRMS; %#ok<NASGU>
    commonSpeechRMSdB = commonRMSdBFS; %#ok<NASGU>

    save(envelopeFile, ...
        'rawEnvelope', ...
        'scaledEnvelope', ...
        'samplingRate', ...
        'carrierFrequency', ...
        'gammatoneCentersHz', ...
        'globalEnvPeak', ...
        'commonSpeechRMS', ...
        'commonSpeechRMSdB');

    % -------------------------------------------------------------
    % Save haptic WAV
    % -------------------------------------------------------------

    hapticOut = fullfile(hapticFolder, ...
        sprintf('%s_haptic150.wav', baseName));

    if max(abs(haptic)) > 1
        error(['Haptic signal exceeds digital full scale for %s. ', ...
               'Reduce HapticGain.'], files(i).name);
    end

    audiowrite(hapticOut, haptic, fs, ...
        'BitsPerSample', opt.BitsPerSample);

    % -------------------------------------------------------------
    % QC metrics
    % -------------------------------------------------------------

    duration_s(i)         = numel(xNorm) / fs;
    scaledEnvelopeRMS(i)  = local_rms(envScaled);
    scaledEnvelopePeak(i) = max(envScaled);
    hapticRMS(i)          = local_rms(haptic);
    hapticPeak(i)         = max(abs(haptic));

    % -------------------------------------------------------------
    % QC figure
    % -------------------------------------------------------------

    if opt.SaveQC
        local_save_qc_figure( ...
            xNorm, ...
            envScaled, ...
            haptic, ...
            fs, ...
            files(i).name, ...
            envSourceCorr(i), ...
            qcFolder, ...
            baseName);
    end

end

%% Create manifest table

filename = string({files.name})';

normalized_rms_dbfs = 20*log10(normalizedRMS);

carrier_frequency_hz = repmat(opt.CarrierFrequency, nFiles, 1);

manifest = table( ...
    filename, ...
    fsList, ...
    duration_s, ...
    originalRMS, ...
    normalizedRMS, ...
    normalized_rms_dbfs, ...
    originalPeak, ...
    normalizedPeak, ...
    speechGain, ...
    carrier_frequency_hz, ...
    hapticRMS, ...
    hapticPeak, ...
    rawEnvelopeRMS, ...
    rawEnvelopePeak, ...
    scaledEnvelopeRMS, ...
    scaledEnvelopePeak, ...
    envSourceCorr, ...
    'VariableNames', { ...
        'filename', ...
        'fs', ...
        'duration_s', ...
        'original_rms', ...
        'normalized_rms', ...
        'normalized_rms_dbfs', ...
        'original_peak', ...
        'normalized_peak', ...
        'speech_gain', ...
        'carrier_frequency_hz', ...
        'haptic_rms', ...
        'haptic_peak', ...
        'raw_envelope_rms', ...
        'raw_envelope_peak', ...
        'scaled_envelope_rms', ...
        'scaled_envelope_peak', ...
        'envelope_source_corr'});

%% Save manifest

csvFile = fullfile(outputRoot, 'haptic_stimuli_manifest.csv');
matFile = fullfile(outputRoot, 'haptic_stimuli_manifest.mat');

writetable(manifest, csvFile);

settings = struct;
settings.inputFolder          = inputFolder;
settings.outputRoot           = outputRoot;
settings.requestedSpeechRMSdBFS = opt.TargetSpeechRMSdBFS;
settings.actualSpeechRMSdBFS  = commonRMSdBFS;
settings.actualSpeechRMS      = commonRMS;
settings.peakLimit            = opt.PeakLimit;
settings.numBands             = opt.NumBands;
settings.lowFrequency         = opt.LowFrequency;
settings.highFrequency        = opt.HighFrequency;
settings.centerFrequenciesHz  = centerFreqs;
settings.carrierFrequency     = opt.CarrierFrequency;
settings.hapticGain           = opt.HapticGain;
settings.globalEnvelopePeak   = globalEnvelopePeak;
settings.bitsPerSample        = opt.BitsPerSample;
settings.saveQC               = logical(opt.SaveQC);
settings.alignGammatone       = true;
settings.envelopeLowPassHz    = [];
settings.envelopeLowPassUsed  = false;

save(matFile, 'manifest', 'settings');

%% Summary

fprintf('\nFinished creating haptic stimuli.\n');
fprintf('Input files:                 %d\n', nFiles);
fprintf('Common speech RMS:           %.2f dBFS\n', commonRMSdBFS);
fprintf('Global raw-envelope peak:    %.8f\n', globalEnvelopePeak);
fprintf('Global haptic gain:          %.4f\n', opt.HapticGain);
fprintf('Carrier frequency:           %.1f Hz\n', opt.CarrierFrequency);
fprintf('Manifest:                    %s\n', csvFile);
fprintf('MAT settings/manifest:       %s\n\n', matFile);

end


%% ========================================================================
% Local helper functions
% ========================================================================

function x = local_make_mono(x)

if size(x,2) > 1
    x = mean(x, 2);
end

x = x(:);

end


function r = local_rms(x)

x = double(x(:));

r = sqrt(mean(x.^2));

end


function mel = local_hz2mel(hz)
% O'Shaughnessy-style Mel conversion.

mel = 2595 .* log10(1 + hz./700);

end


function hz = local_mel2hz(mel)
% Inverse O'Shaughnessy-style Mel conversion.

hz = 700 .* (10.^(mel./2595) - 1);

end


function local_save_qc_figure(x, envScaled, haptic, fs, filename, ...
    envCorr, qcFolder, baseName)

t = (0:numel(x)-1)' / fs;

fig = figure( ...
    'Visible', 'off', ...
    'Color', 'w', ...
    'Position', [100 100 1400 850]);

tl = tiledlayout(fig, 3, 1, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

% Normalized speech
nexttile;
plot(t, x);
xlim([t(1) t(end)]);
ylabel('Amplitude');
title('Normalized speech');
grid on;

% Composite envelope
nexttile;
plot(t, envScaled);
xlim([t(1) t(end)]);
ylabel('Scaled envelope');
title(sprintf('Composite aligned envelope | corr(source envelope) = %.3f', ...
    envCorr));
grid on;

% Haptic waveform
nexttile;
plot(t, haptic);
xlim([t(1) t(end)]);
xlabel('Time (s)');
ylabel('Amplitude');
title('150-Hz amplitude-modulated haptic signal');
grid on;

title(tl, strrep(filename, '_', '\_'), ...
    'Interpreter', 'tex');

qcFile = fullfile(qcFolder, sprintf('%s_qc.png', baseName));

exportgraphics(fig, qcFile, 'Resolution', 150);
close(fig);

end

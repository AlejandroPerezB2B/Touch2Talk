% ============================================================
% Resample masker WAV files from 48 kHz to 44.1 kHz
% ============================================================

sourceFolder = 'E:\S0406\News\Four_talker_masker_sets';
destinationFolder = 'E:\S0406\News\masker_44100Hz';

if ~exist(destinationFolder, 'dir')
    mkdir(destinationFolder);
end

files = dir(fullfile(sourceFolder, 'masker_set_*.wav'));

fprintf('Found %d masker files.\n\n', numel(files));

targetFs = 44100;

for i = 1:numel(files)

    inFile = fullfile(files(i).folder, files(i).name);

    [x, fs] = audioread(inFile);

    fprintf('%02d/%02d %s: %d Hz -> %d Hz\n', ...
        i, numel(files), files(i).name, fs, targetFs);

    if fs == targetFs

        y = x;

    else

        % High-quality MATLAB resampling
        y = resample(x, targetFs, fs);

    end

    outFile = fullfile(destinationFolder, files(i).name);

    audiowrite(outFile, y, targetFs, ...
        'BitsPerSample', 24);

end

fprintf('\nFinished.\n');
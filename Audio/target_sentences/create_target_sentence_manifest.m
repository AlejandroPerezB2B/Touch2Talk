%% create_target_sentence_manifest.m
%
% Creates and validates the master manifest for the Spanish target
% sentence recordings.
%
% ROOT:
%   E:\Formas_1_a_6_sin_ruido
%
% -------------------------------------------------------------------------
% PHYSICAL FORMA STRUCTURE
% -------------------------------------------------------------------------
%
%   FORMA 1-1 y 2b   -> HP family 1 + LP family 2b
%   FORMA 2-2 y 3b   -> HP family 2 + LP family 3b
%   FORMA 3-3 y 4b   -> HP family 3 + LP family 4b
%   FORMA 4-4 y 5b   -> HP family 4 + LP family 5b
%   FORMA 5-5 y 6b   -> HP family 5 + LP family 6b
%   FORMA 6-6 y 1b   -> HP family 6 + LP family 1b
%
% -------------------------------------------------------------------------
% KNOWN MISSING WAV FILES
% -------------------------------------------------------------------------
%
% In FORMA 3-3 y 4b the following WAV files are genuinely absent:
%
%   3.6
%   4b.4
%   3.10
%   3.21
%
% These four missing recordings belong to four different HP-LP pairs:
%
%   3.6  <-> 3b.6
%   4.4  <-> 4b.4
%   3.10 <-> 3b.10
%   3.21 <-> 3b.21
%
% Therefore the four incomplete pairs are excluded from the usable
% pair manifest.
%
% Expected physical inventory:
%
%   FORMA 1 = 50 WAVs
%   FORMA 2 = 50 WAVs
%   FORMA 3 = 46 WAVs
%   FORMA 4 = 50 WAVs
%   FORMA 5 = 50 WAVs
%   FORMA 6 = 50 WAVs
%
%   Total existing WAVs = 296
%
% Expected usable paired inventory:
%
%   150 theoretical pairs
%   - 4 incomplete pairs
%   = 146 complete pairs
%
%   146 x 2 = 292 usable recordings
%
% -------------------------------------------------------------------------
% IMPORTANT
% -------------------------------------------------------------------------
%
% The physical order/item numbering in the source materials is NOT used
% to infer which recordings are missing. Missing recordings are validated
% directly from their stimulus codes.
%
% -------------------------------------------------------------------------

clear;
clc;


%% ========================================================================
% USER SETTINGS
% ========================================================================

rootDir = 'E:\Formas_1_a_6_sin_ruido';

formaFolders = { ...
    'FORMA 1-1 y 2b', ...
    'FORMA 2-2 y 3b', ...
    'FORMA 3-3 y 4b', ...
    'FORMA 4-4 y 5b', ...
    'FORMA 5-5 y 6b', ...
    'FORMA 6-6 y 1b'};

nFormas = 6;


%% Expected physical file counts

expectedFilesPerForma = [50 50 46 50 50 50];

expectedTotalFiles = sum(expectedFilesPerForma);   % 296


%% Expected family structure

expectedHPFamily = [1 2 3 4 5 6];

expectedLPFamily = [2 3 4 5 6 1];


%% Expected physical locations of HP/LP counterparts

expectedHPForma = [1 2 3 4 5 6];

expectedLPForma = [6 1 2 3 4 5];


%% ========================================================================
% KNOWN MISSING WAV FILES
% ========================================================================

missingStimulusCodes = [ ...
    "3.6"
    "4b.4"
    "3.10"
    "3.21"
    ];


%% Corresponding incomplete target pairs
%
% Note that 4b.4 belongs to target pair 4.4.

excludedPairIDs = [ ...
    "3.6"
    "4.4"
    "3.10"
    "3.21"
    ];

nExcludedPairs = numel(excludedPairIDs);

expectedCompletePairs = 150 - nExcludedPairs;     % 146

expectedUsableRecordings = expectedCompletePairs * 2;  % 292


%% Output directory

outputDir = fullfile(rootDir, 'Stimulus_manifests');

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end


%% ========================================================================
% PREALLOCATE MASTER MANIFEST
% ========================================================================

manifest = table( ...
    zeros(expectedTotalFiles,1), ...
    zeros(expectedTotalFiles,1), ...
    zeros(expectedTotalFiles,1), ...
    zeros(expectedTotalFiles,1), ...
    zeros(expectedTotalFiles,1), ...
    strings(expectedTotalFiles,1), ...
    strings(expectedTotalFiles,1), ...
    strings(expectedTotalFiles,1), ...
    strings(expectedTotalFiles,1), ...
    strings(expectedTotalFiles,1), ...
    strings(expectedTotalFiles,1), ...
    zeros(expectedTotalFiles,1), ...
    zeros(expectedTotalFiles,1), ...
    zeros(expectedTotalFiles,1), ...
    strings(expectedTotalFiles,1), ...
    strings(expectedTotalFiles,1), ...
    repmat("UNASSIGNED",expectedTotalFiles,1), ...
    false(expectedTotalFiles,1), ...
    strings(expectedTotalFiles,1), ...
    'VariableNames', { ...
        'ManifestID', ...
        'Forma', ...
        'FormaItem', ...
        'TargetFamily', ...
        'SentenceNumber', ...
        'Predictability', ...
        'StimulusCode', ...
        'TargetPairID', ...
        'AudioFilename', ...
        'AudioFolder', ...
        'FullAudioPath', ...
        'SampleRate', ...
        'NumChannels', ...
        'Duration_s', ...
        'TargetWord', ...
        'Sentence', ...
        'StimulusUse', ...
        'CompletePair', ...
        'ExclusionReason'});


row = 0;


%% ========================================================================
% SCAN PHYSICAL FORMA FOLDERS
% ========================================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('SCANNING TARGET-SENTENCE AUDIO\n');
fprintf('============================================================\n\n');


for forma = 1:nFormas

    folderName = formaFolders{forma};
    folderPath = fullfile(rootDir, folderName);


    if ~exist(folderPath, 'dir')

        error('FORMA folder not found:\n%s', folderPath);

    end


    wavFiles = dir(fullfile(folderPath, '*.wav'));


    fprintf('FORMA %d\n', forma);
    fprintf('Folder: %s\n', folderName);
    fprintf('WAV files found: %d\n', numel(wavFiles));


    %% Validate expected physical count

    if numel(wavFiles) ~= expectedFilesPerForma(forma)

        error(['Unexpected number of WAV files in FORMA %d.\n\n' ...
               'Folder: %s\n' ...
               'Expected: %d\n' ...
               'Found: %d'], ...
               forma, ...
               folderPath, ...
               expectedFilesPerForma(forma), ...
               numel(wavFiles));

    end


    %% ====================================================================
    % PROCESS FILES
    % ====================================================================

    for f = 1:numel(wavFiles)

        row = row + 1;

        fileName = wavFiles(f).name;
        fullPath = fullfile(folderPath, fileName);

        [~, baseName, ext] = fileparts(fileName);


        if ~strcmpi(ext,'.wav')

            error('Unexpected file extension:\n%s', fullPath);

        end


        %% ---------------------------------------------------------------
        % Parse filename
        %
        % Expected:
        %
        %   Y - X.H.wav
        %   Y - Xb.H.wav
        %
        % Y is retained as FormaItem but is NOT used to infer omissions.
        % ---------------------------------------------------------------

        tokens = regexp( ...
            baseName, ...
            '^\s*(\d+)\s*-\s*([1-6])(b?)\.(\d{1,2})\s*$', ...
            'tokens', ...
            'once');


        if isempty(tokens)

            error(['Unexpected filename format:\n%s\n\n' ...
                   'Expected Y - X.H.wav or Y - Xb.H.wav'], ...
                   fullPath);

        end


        formaItem = str2double(tokens{1});
        targetFamily = str2double(tokens{2});
        bMarker = tokens{3};
        sentenceNumber = str2double(tokens{4});


        %% Basic range checks

        if formaItem < 1 || formaItem > 50

            error( ...
                'Invalid FORMA item number in %s.', ...
                fileName);

        end


        if sentenceNumber < 1 || sentenceNumber > 25

            error( ...
                'Invalid sentence number in %s.', ...
                fileName);

        end


        %% Predictability

        if isempty(bMarker)

            predictability = "H";

        else

            predictability = "L";

        end


        %% Canonical stimulus code

        if predictability == "H"

            stimulusCode = sprintf( ...
                '%d.%d', ...
                targetFamily, ...
                sentenceNumber);

        else

            stimulusCode = sprintf( ...
                '%db.%d', ...
                targetFamily, ...
                sentenceNumber);

        end


        %% HP/LP target-pair identifier

        targetPairID = sprintf( ...
            '%d.%d', ...
            targetFamily, ...
            sentenceNumber);


        %% ---------------------------------------------------------------
        % Validate family against physical FORMA
        % ---------------------------------------------------------------

        if predictability == "H"

            expectedFamily = expectedHPFamily(forma);

        else

            expectedFamily = expectedLPFamily(forma);

        end


        if targetFamily ~= expectedFamily

            error(['Unexpected target family.\n\n' ...
                   'File: %s\n' ...
                   'FORMA: %d\n' ...
                   'Predictability: %s\n' ...
                   'Detected family: %d\n' ...
                   'Expected family: %d'], ...
                   fileName, ...
                   forma, ...
                   predictability, ...
                   targetFamily, ...
                   expectedFamily);

        end


        %% Audio metadata

        info = audioinfo(fullPath);


        %% Store

        manifest.ManifestID(row) = row;
        manifest.Forma(row) = forma;
        manifest.FormaItem(row) = formaItem;
        manifest.TargetFamily(row) = targetFamily;
        manifest.SentenceNumber(row) = sentenceNumber;
        manifest.Predictability(row) = predictability;
        manifest.StimulusCode(row) = string(stimulusCode);
        manifest.TargetPairID(row) = string(targetPairID);
        manifest.AudioFilename(row) = string(fileName);
        manifest.AudioFolder(row) = string(folderName);
        manifest.FullAudioPath(row) = string(fullPath);
        manifest.SampleRate(row) = info.SampleRate;
        manifest.NumChannels(row) = info.NumChannels;
        manifest.Duration_s(row) = info.Duration;

        manifest.TargetWord(row) = "";
        manifest.Sentence(row) = "";
        manifest.StimulusUse(row) = "UNASSIGNED";
        manifest.CompletePair(row) = false;
        manifest.ExclusionReason(row) = "";

    end


    fprintf('  -> parsed successfully.\n\n');

end


%% ========================================================================
% TOTAL PHYSICAL INVENTORY CHECK
% ========================================================================

if row ~= expectedTotalFiles

    error( ...
        'Expected %d WAV files but parsed %d.', ...
        expectedTotalFiles, ...
        row);

end


%% Sort by physical FORMA and available item number

manifest = sortrows( ...
    manifest, ...
    {'Forma','FormaItem'});

manifest.ManifestID = (1:height(manifest))';


%% ========================================================================
% DUPLICATE PHYSICAL ITEM CHECK
% ========================================================================
%
% Because the source documentation/order may contain omissions, we do NOT
% require FORMA 3 to contain a particular set of FormaItem values.
%
% However, an item number must not occur twice within the same FORMA.

fprintf('\n');
fprintf('============================================================\n');
fprintf('PHYSICAL FORMA ITEM CHECK\n');
fprintf('============================================================\n');


for forma = 1:nFormas

    idx = manifest.Forma == forma;

    observedItems = manifest.FormaItem(idx);


    if numel(unique(observedItems)) ~= numel(observedItems)

        error( ...
            'Duplicate physical item numbers detected in FORMA %d.', ...
            forma);

    end


    fprintf( ...
        'FORMA %d: %d unique physical item numbers.\n', ...
        forma, ...
        numel(observedItems));

end


%% ========================================================================
% VALIDATE THE FOUR KNOWN MISSING WAV CODES
% ========================================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('KNOWN MISSING WAV VALIDATION\n');
fprintf('============================================================\n');


for k = 1:numel(missingStimulusCodes)

    code = missingStimulusCodes(k);


    if any(manifest.StimulusCode == code)

        error(['Stimulus %s is specified as missing, ' ...
               'but a corresponding WAV file was found.'], ...
               code);

    end


    fprintf('Confirmed missing: %s\n', code);

end


%% ========================================================================
% ENSURE THERE ARE NO OTHER MISSING STIMULUS CODES
% ========================================================================
%
% Generate the theoretical inventory of 300 stimulus codes and compare it
% against the physical inventory.
%
% This is important because it verifies that the ONLY absent WAVs are:
%
%   3.6
%   4b.4
%   3.10
%   3.21

expectedCodes = strings(300,1);

c = 0;


for family = 1:6

    for sentenceNumber = 1:25

        c = c + 1;

        expectedCodes(c) = string( ...
            sprintf('%d.%d',family,sentenceNumber));

    end


    for sentenceNumber = 1:25

        c = c + 1;

        expectedCodes(c) = string( ...
            sprintf('%db.%d',family,sentenceNumber));

    end

end


observedCodes = manifest.StimulusCode;

actuallyMissingCodes = setdiff( ...
    expectedCodes, ...
    observedCodes);


unexpectedCodes = setdiff( ...
    observedCodes, ...
    expectedCodes);


if ~isempty(unexpectedCodes)

    fprintf(2,'\nUnexpected stimulus codes found:\n');
    disp(unexpectedCodes);

    error('Unexpected stimulus codes detected.');

end


if ~isequal( ...
        sort(actuallyMissingCodes), ...
        sort(missingStimulusCodes))

    fprintf(2,'\nExpected missing codes:\n');
    disp(sort(missingStimulusCodes));

    fprintf(2,'Actually missing codes:\n');
    disp(sort(actuallyMissingCodes));

    error(['Physical stimulus inventory does not match the ' ...
           'specified four missing WAV files.']);

end


fprintf('\nNo additional missing stimulus codes detected.\n');


%% ========================================================================
% UNIQUE CODE / PATH CHECKS
% ========================================================================

if numel(unique(manifest.StimulusCode)) ~= height(manifest)

    error('Duplicate StimulusCode values detected.');

end


if numel(unique(manifest.FullAudioPath)) ~= height(manifest)

    error('Duplicate audio paths detected.');

end


%% ========================================================================
% REPORT H/L COUNTS
% ========================================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('PREDICTABILITY COUNTS\n');
fprintf('============================================================\n');


for forma = 1:nFormas

    nH = sum( ...
        manifest.Forma == forma & ...
        manifest.Predictability == "H");

    nL = sum( ...
        manifest.Forma == forma & ...
        manifest.Predictability == "L");


    fprintf( ...
        'FORMA %d: H = %d, L = %d, Total = %d\n', ...
        forma, ...
        nH, ...
        nL, ...
        nH+nL);

end


%% ========================================================================
% IDENTIFY COMPLETE AND INCOMPLETE HP-LP PAIRS
% ========================================================================

allPairIDs = strings(150,1);

counter = 0;


for family = 1:6

    for sentenceNumber = 1:25

        counter = counter + 1;

        allPairIDs(counter) = string( ...
            sprintf('%d.%d',family,sentenceNumber));

    end

end


completePairIDs = strings(0,1);
incompletePairIDs = strings(0,1);


for k = 1:numel(allPairIDs)

    pairID = allPairIDs(k);

    idxPair = manifest.TargetPairID == pairID;

    nH = sum( ...
        idxPair & ...
        manifest.Predictability == "H");

    nL = sum( ...
        idxPair & ...
        manifest.Predictability == "L");


    if nH == 1 && nL == 1

        completePairIDs(end+1,1) = pairID; %#ok<SAGROW>

    else

        incompletePairIDs(end+1,1) = pairID; %#ok<SAGROW>

    end

end


%% ========================================================================
% VALIDATE INCOMPLETE PAIRS
% ========================================================================

if ~isequal( ...
        sort(incompletePairIDs), ...
        sort(excludedPairIDs))

    fprintf(2,'\nExpected incomplete pairs:\n');
    disp(sort(excludedPairIDs));

    fprintf(2,'Observed incomplete pairs:\n');
    disp(sort(incompletePairIDs));

    error('Unexpected incomplete HP-LP pair structure.');

end


if numel(completePairIDs) ~= expectedCompletePairs

    error( ...
        'Expected %d complete pairs but found %d.', ...
        expectedCompletePairs, ...
        numel(completePairIDs));

end


%% Mark complete pair membership

manifest.CompletePair = ...
    ismember(manifest.TargetPairID,completePairIDs);


%% ========================================================================
% FLAG SURVIVING COUNTERPARTS OF INCOMPLETE PAIRS
% ========================================================================
%
% Four WAVs survive physically but cannot be used because their counterpart
% is missing:
%
%   3b.6
%   4.4
%   3b.10
%   3b.21

orphanIdx = ~manifest.CompletePair;


manifest.StimulusUse(orphanIdx) = ...
    "EXCLUDED_INCOMPLETE_PAIR";

manifest.ExclusionReason(orphanIdx) = ...
    "Counterpart WAV is missing";


%% ========================================================================
% CREATE EXCLUDED-PAIR TABLE
% ========================================================================

excludedPairs = table( ...
    ["3.6";"4.4";"3.10";"3.21"], ...
    ["3.6";"4b.4";"3.10";"3.21"], ...
    ["3b.6";"4.4";"3b.10";"3b.21"], ...
    ["HP";"LP";"HP";"HP"], ...
    repmat("Incomplete HP-LP pair",4,1), ...
    'VariableNames', { ...
        'TargetPairID', ...
        'MissingStimulusCode', ...
        'ExistingCounterpartCode', ...
        'MissingPredictability', ...
        'Reason'});


%% ========================================================================
% PREALLOCATE COMPLETE PAIR MANIFEST
% ========================================================================

pairManifest = table( ...
    zeros(expectedCompletePairs,1), ...
    strings(expectedCompletePairs,1), ...
    zeros(expectedCompletePairs,1), ...
    zeros(expectedCompletePairs,1), ...
    zeros(expectedCompletePairs,1), ...
    zeros(expectedCompletePairs,1), ...
    strings(expectedCompletePairs,1), ...
    strings(expectedCompletePairs,1), ...
    strings(expectedCompletePairs,1), ...
    strings(expectedCompletePairs,1), ...
    zeros(expectedCompletePairs,1), ...
    zeros(expectedCompletePairs,1), ...
    strings(expectedCompletePairs,1), ...
    strings(expectedCompletePairs,1), ...
    strings(expectedCompletePairs,1), ...
    strings(expectedCompletePairs,1), ...
    strings(expectedCompletePairs,1), ...
    repmat("UNASSIGNED",expectedCompletePairs,1), ...
    'VariableNames', { ...
        'PairNumber', ...
        'TargetPairID', ...
        'TargetFamily', ...
        'SentenceNumber', ...
        'HP_Forma', ...
        'HP_FormaItem', ...
        'HP_StimulusCode', ...
        'HP_AudioFilename', ...
        'HP_AudioFolder', ...
        'HP_FullAudioPath', ...
        'LP_Forma', ...
        'LP_FormaItem', ...
        'LP_StimulusCode', ...
        'LP_AudioFilename', ...
        'LP_AudioFolder', ...
        'LP_FullAudioPath', ...
        'TargetWord', ...
        'StimulusUse'});


%% ========================================================================
% BUILD COMPLETE PAIR MANIFEST
% ========================================================================

pairRow = 0;


for family = 1:6

    for sentenceNumber = 1:25

        pairID = string( ...
            sprintf('%d.%d',family,sentenceNumber));


        %% Skip incomplete pairs

        if ismember(pairID,excludedPairIDs)

            continue

        end


        idxHP = ...
            manifest.TargetPairID == pairID & ...
            manifest.Predictability == "H";

        idxLP = ...
            manifest.TargetPairID == pairID & ...
            manifest.Predictability == "L";


        if sum(idxHP) ~= 1 || sum(idxLP) ~= 1

            error( ...
                'Complete-pair validation failed for %s.', ...
                pairID);

        end


        hpRow = find(idxHP);
        lpRow = find(idxLP);


        %% Counterparts should be in different physical FORMAs

        if manifest.Forma(hpRow) == manifest.Forma(lpRow)

            error( ...
                'Pair %s has H and L in the same FORMA.', ...
                pairID);

        end


        pairRow = pairRow + 1;


        %% Store pair

        pairManifest.PairNumber(pairRow) = pairRow;

        pairManifest.TargetPairID(pairRow) = pairID;

        pairManifest.TargetFamily(pairRow) = family;

        pairManifest.SentenceNumber(pairRow) = sentenceNumber;


        %% HP

        pairManifest.HP_Forma(pairRow) = ...
            manifest.Forma(hpRow);

        pairManifest.HP_FormaItem(pairRow) = ...
            manifest.FormaItem(hpRow);

        pairManifest.HP_StimulusCode(pairRow) = ...
            manifest.StimulusCode(hpRow);

        pairManifest.HP_AudioFilename(pairRow) = ...
            manifest.AudioFilename(hpRow);

        pairManifest.HP_AudioFolder(pairRow) = ...
            manifest.AudioFolder(hpRow);

        pairManifest.HP_FullAudioPath(pairRow) = ...
            manifest.FullAudioPath(hpRow);


        %% LP

        pairManifest.LP_Forma(pairRow) = ...
            manifest.Forma(lpRow);

        pairManifest.LP_FormaItem(pairRow) = ...
            manifest.FormaItem(lpRow);

        pairManifest.LP_StimulusCode(pairRow) = ...
            manifest.StimulusCode(lpRow);

        pairManifest.LP_AudioFilename(pairRow) = ...
            manifest.AudioFilename(lpRow);

        pairManifest.LP_AudioFolder(pairRow) = ...
            manifest.AudioFolder(lpRow);

        pairManifest.LP_FullAudioPath(pairRow) = ...
            manifest.FullAudioPath(lpRow);


        pairManifest.TargetWord(pairRow) = "";

        pairManifest.StimulusUse(pairRow) = ...
            "UNASSIGNED";

    end

end


if pairRow ~= expectedCompletePairs

    error( ...
        'Expected %d complete pairs but constructed %d.', ...
        expectedCompletePairs, ...
        pairRow);

end


%% ========================================================================
% VALIDATE CROSS-FORMA STRUCTURE
% ========================================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('COMPLETE HP-LP PAIR VALIDATION\n');
fprintf('============================================================\n');


for family = 1:6

    idx = pairManifest.TargetFamily == family;

    nPairs = sum(idx);


    hpFormas = unique(pairManifest.HP_Forma(idx));
    lpFormas = unique(pairManifest.LP_Forma(idx));


    if numel(hpFormas) ~= 1 || ...
            hpFormas ~= expectedHPForma(family)

        error( ...
            'Unexpected HP FORMA for family %d.', ...
            family);

    end


    if numel(lpFormas) ~= 1 || ...
            lpFormas ~= expectedLPForma(family)

        error( ...
            'Unexpected LP FORMA for family %d.', ...
            family);

    end


    fprintf( ...
        ['Family %d: HP FORMA %d <-> LP FORMA %d ' ...
         ': %d complete pairs\n'], ...
        family, ...
        hpFormas, ...
        lpFormas, ...
        nPairs);

end


%% ========================================================================
% AUDIO FORMAT CHECK
% ========================================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('AUDIO FORMAT CHECK\n');
fprintf('============================================================\n');


uniqueSampleRates = unique(manifest.SampleRate);

fprintf('Sample rates detected:\n');
disp(uniqueSampleRates);


if numel(uniqueSampleRates) > 1

    warning(['Target recordings contain multiple sample rates. ' ...
             'No resampling has been performed.']);

end


multiIdx = find(manifest.NumChannels > 1);


if isempty(multiIdx)

    fprintf('All existing target recordings are mono.\n');

else

    fprintf('Multichannel recordings detected:\n');

    for k = 1:numel(multiIdx)

        i = multiIdx(k);

        fprintf( ...
            '  %s : %d channels\n', ...
            manifest.AudioFilename(i), ...
            manifest.NumChannels(i));

    end

end


%% ========================================================================
% CREATE FORMA SUMMARY
% ========================================================================

formaSummary = table( ...
    (1:6)', ...
    expectedHPFamily', ...
    expectedLPFamily', ...
    zeros(6,1), ...
    zeros(6,1), ...
    zeros(6,1), ...
    zeros(6,1), ...
    'VariableNames', { ...
        'Forma', ...
        'HP_Family', ...
        'LP_Family', ...
        'N_H', ...
        'N_L', ...
        'N_Total', ...
        'MeanDuration_s'});


for forma = 1:6

    idx = manifest.Forma == forma;

    formaSummary.N_H(forma) = sum( ...
        idx & manifest.Predictability == "H");

    formaSummary.N_L(forma) = sum( ...
        idx & manifest.Predictability == "L");

    formaSummary.N_Total(forma) = sum(idx);

    formaSummary.MeanDuration_s(forma) = ...
        mean(manifest.Duration_s(idx));

end


%% ========================================================================
% SAVE OUTPUTS
% ========================================================================

masterCsvPath = fullfile( ...
    outputDir, ...
    'target_sentence_master_manifest.csv');

pairCsvPath = fullfile( ...
    outputDir, ...
    'target_sentence_pair_manifest.csv');

excludedCsvPath = fullfile( ...
    outputDir, ...
    'target_sentence_excluded_pairs.csv');

summaryCsvPath = fullfile( ...
    outputDir, ...
    'target_sentence_forma_summary.csv');

matPath = fullfile( ...
    outputDir, ...
    'target_sentence_manifest.mat');


writetable(manifest,masterCsvPath);

writetable(pairManifest,pairCsvPath);

writetable(excludedPairs,excludedCsvPath);

writetable(formaSummary,summaryCsvPath);


save( ...
    matPath, ...
    'manifest', ...
    'pairManifest', ...
    'excludedPairs', ...
    'formaSummary', ...
    'rootDir', ...
    'formaFolders', ...
    'missingStimulusCodes', ...
    'excludedPairIDs', ...
    'expectedHPFamily', ...
    'expectedLPFamily', ...
    'expectedHPForma', ...
    'expectedLPForma');


%% ========================================================================
% FINAL SUMMARY
% ========================================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('TARGET-SENTENCE MANIFEST COMPLETE\n');
fprintf('============================================================\n');


fprintf( ...
    'Existing physical WAV files:     %d\n', ...
    height(manifest));

fprintf( ...
    'Existing H recordings:           %d\n', ...
    sum(manifest.Predictability == "H"));

fprintf( ...
    'Existing L recordings:           %d\n', ...
    sum(manifest.Predictability == "L"));

fprintf( ...
    'Known missing WAV files:         %d\n', ...
    numel(missingStimulusCodes));

fprintf( ...
    'Incomplete HP-LP pairs:          %d\n', ...
    numel(excludedPairIDs));

fprintf( ...
    'Complete usable HP-LP pairs:     %d\n', ...
    height(pairManifest));

fprintf( ...
    'Usable paired recordings:        %d\n', ...
    2 * height(pairManifest));

fprintf( ...
    'Existing orphan counterparts:    %d\n', ...
    sum(~manifest.CompletePair));


fprintf('\nKnown missing WAV files:\n');

for k = 1:numel(missingStimulusCodes)

    fprintf( ...
        '  %s\n', ...
        missingStimulusCodes(k));

end


fprintf('\nExcluded incomplete pairs:\n');

for k = 1:height(excludedPairs)

    fprintf( ...
        '  Pair %s: missing %s; counterpart %s exists\n', ...
        excludedPairs.TargetPairID(k), ...
        excludedPairs.MissingStimulusCode(k), ...
        excludedPairs.ExistingCounterpartCode(k));

end


fprintf('\nComplete pairs by family:\n');

for family = 1:6

    fprintf( ...
        '  Family %d: %d complete pairs\n', ...
        family, ...
        sum(pairManifest.TargetFamily == family));

end


fprintf('\nOutput directory:\n%s\n',outputDir);

fprintf('\nFiles created:\n');
fprintf('  %s\n',masterCsvPath);
fprintf('  %s\n',pairCsvPath);
fprintf('  %s\n',excludedCsvPath);
fprintf('  %s\n',summaryCsvPath);
fprintf('  %s\n',matPath);


fprintf('\n');
fprintf('No audio files were modified.\n');
fprintf('No missing WAV files were synthesized or replaced.\n');
fprintf('Incomplete target pairs were excluded from pairManifest.\n');
fprintf('No calibration/main assignment was performed.\n');
fprintf('No haptic-condition assignment was performed.\n');
fprintf('No masker/TMR processing was performed.\n');


%% ========================================================================
% DISPLAY SUMMARY TABLES
% ========================================================================

fprintf('\nFORMA SUMMARY\n');
disp(formaSummary);

fprintf('\nEXCLUDED / INCOMPLETE PAIRS\n');
disp(excludedPairs);
function summary_table = printAutotuningSummary(resultsInput)
% printAutotuningSummary Print a compact summary for autotuning output.

data = loadAutotuningData(resultsInput);
summary_table = data.summary_table;

if isempty(summary_table)
    fprintf('No autotuning runs were found.\n');
    return;
end

fprintf('\nAutotuning Summary\n');
disp(summary_table);
end

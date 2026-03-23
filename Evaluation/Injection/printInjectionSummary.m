function summary_table = printInjectionSummary(resultsInput)
% printInjectionSummary Print a compact estimator summary for injection studies.

data = loadInjectionData(resultsInput);
summary_table = data.summary_table;

if isempty(summary_table)
    fprintf('No injection-study runs were found.\n');
    return;
end

fprintf('\nInjection Study Summary\n');
disp(summary_table);
end

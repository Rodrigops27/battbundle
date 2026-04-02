classdef BundleEvalHelpers
    methods(Static)
        function paths = buildPromotedSummaryPaths(layer_name, suite_version, scenario_id)
            output_dir = fullfile('results', layer_name, suite_version);
            stem = BundleEvalHelpers.composePromotedStem(layer_name, suite_version, scenario_id);
            paths = struct();
            paths.output_dir = output_dir;
            paths.stem = stem;
            paths.json_file = fullfile(output_dir, [stem '.json']);
            paths.markdown_file = fullfile(output_dir, [stem '.md']);
        end

        function stem = composePromotedStem(layer_name, suite_version, scenario_id)
            stem = sprintf('%s__%s__%s__summary', ...
                BundleEvalHelpers.sanitizeToken(layer_name), ...
                BundleEvalHelpers.sanitizeToken(suite_version), ...
                BundleEvalHelpers.sanitizeToken(scenario_id));
        end

        function json_file = buildPromotedParamsPath(suite_version, scenario_id)
            stem = sprintf('autotuning__%s__%s__tuned_params', ...
                BundleEvalHelpers.sanitizeToken(suite_version), ...
                BundleEvalHelpers.sanitizeToken(scenario_id));
            json_file = fullfile('results', 'autotuning', suite_version, [stem '.json']);
        end

        function repo_root = resolveBundleRepoRoot()
            candidates = {pwd, fileparts(mfilename('fullpath'))};
            repo_root = '';
            for idx = 1:numel(candidates)
                repo_root = BundleEvalHelpers.findBundleRepoRoot(candidates{idx});
                if ~isempty(repo_root)
                    return;
                end
            end

            error('BundleEvalHelpers:RepoRootNotFound', ...
                ['Could not locate the bundle repository root. Run the script from the ', ...
                 'repository workspace or update resolveBundleRepoRoot().']);
        end

        function repo_root = findBundleRepoRoot(start_dir)
            repo_root = '';
            if isempty(start_dir)
                return;
            end

            current_dir = char(start_dir);
            while ~isempty(current_dir)
                if exist(fullfile(current_dir, 'data'), 'dir') == 7 && ...
                        exist(fullfile(current_dir, 'models'), 'dir') == 7 && ...
                        exist(fullfile(current_dir, 'Evaluation'), 'dir') == 7 && ...
                        exist(fullfile(current_dir, 'utility'), 'dir') == 7
                    repo_root = current_dir;
                    return;
                end

                parent_dir = fileparts(current_dir);
                if isempty(parent_dir) || strcmp(parent_dir, current_dir)
                    return;
                end
                current_dir = parent_dir;
            end
        end

        function ensureDir(dir_path)
            if isempty(dir_path)
                return;
            end
            if exist(dir_path, 'dir') ~= 7
                mkdir(dir_path);
            end
        end

        function path_out = resolveRepoPath(path_in, repo_root)
            path_in = char(path_in);
            if isempty(path_in)
                path_out = path_in;
                return;
            end
            if BundleEvalHelpers.isAbsolutePath(path_in)
                path_out = path_in;
            else
                path_out = fullfile(repo_root, path_in);
            end
        end

        function tf = isAbsolutePath(path_in)
            path_in = char(path_in);
            tf = ~isempty(regexp(path_in, '^[A-Za-z]:[\\/]|^\\\\', 'once'));
        end

        function upsertAtl20P25ModelValidationMarkdown(markdown_file, validation_results, model_file, dataset_file, results_file)
            begin_marker = '<!-- ATL20_P25_MODEL_VALIDATION:BEGIN -->';
            end_marker = '<!-- ATL20_P25_MODEL_VALIDATION:END -->';
            generated_block = BundleEvalHelpers.renderAtl20P25ModelValidationBlock( ...
                validation_results, model_file, dataset_file, results_file, ...
                begin_marker, end_marker);

            if exist(markdown_file, 'file') == 2
                markdown_text = fileread(markdown_file);
            else
                markdown_text = ['# Models' newline newline];
            end

            pattern = [regexptranslate('escape', begin_marker) '.*?' regexptranslate('escape', end_marker)];
            if ~isempty(regexp(markdown_text, pattern, 'once'))
                markdown_text = regexprep(markdown_text, pattern, generated_block, 'dotexceptnewline');
            else
                if ~endsWith(markdown_text, newline)
                    markdown_text = [markdown_text newline]; %#ok<AGROW>
                end
                markdown_text = [markdown_text newline generated_block newline]; %#ok<AGROW>
            end

            BundleEvalHelpers.writeMarkdownArtifact(markdown_file, markdown_text);
        end

        function markdown_text = renderAtl20P25ModelValidationBlock(validation_results, model_file, dataset_file, results_file, begin_marker, end_marker)
            if nargin < 5
                begin_marker = '<!-- ATL20_P25_MODEL_VALIDATION:BEGIN -->';
            end
            if nargin < 6
                end_marker = '<!-- ATL20_P25_MODEL_VALIDATION:END -->';
            end

            metrics = BundleEvalHelpers.fieldOr(validation_results, 'metrics', struct());
            case_results = BundleEvalHelpers.fieldOr(validation_results, 'cases', struct([]));
            summary_rows = BundleEvalHelpers.tableRows(BundleEvalHelpers.fieldOr(validation_results, 'summary_table', table()));
            case_rows = BundleEvalHelpers.caseMetricsTable(case_results);

            lines = { ...
                begin_marker; ...
                '## ATL20 P25 Application-Dataset Evaluation'; ...
                ''; ...
                sprintf('- ESC model: `%s`', BundleEvalHelpers.normalizeStoredPath(model_file)); ...
                sprintf('- dataset: `%s`', BundleEvalHelpers.normalizeStoredPath(dataset_file)); ...
                sprintf('- saved validation MAT: `%s`', BundleEvalHelpers.normalizeStoredPath(results_file)); ...
                sprintf('- generated: `%s`', datestr(now, 'yyyy-mm-dd HH:MM:SS')); ...
                sprintf('- cases: `%s`', BundleEvalHelpers.scalarToMarkdownText(BundleEvalHelpers.fieldOr(validation_results, 'case_count', NaN))); ...
                ''; ...
                '### Aggregate Metrics'; ...
                ''; ...
                sprintf('- mean RMSE: `%s mV`', BundleEvalHelpers.scalarToMarkdownText(BundleEvalHelpers.fieldOr(metrics, 'mean_voltage_rmse_mv', NaN))); ...
                sprintf('- mean error: `%s mV`', BundleEvalHelpers.scalarToMarkdownText(BundleEvalHelpers.aggregateCaseMetric(case_results, 'voltage_mean_error_mv', 'mean'))); ...
                sprintf('- mean MAE: `%s mV`', BundleEvalHelpers.scalarToMarkdownText(BundleEvalHelpers.aggregateCaseMetric(case_results, 'voltage_mae_mv', 'mean'))); ...
                sprintf('- mean max abs error: `%s mV`', BundleEvalHelpers.scalarToMarkdownText(BundleEvalHelpers.aggregateCaseMetric(case_results, 'voltage_max_abs_error_mv', 'mean'))); ...
                sprintf('- worst-case RMSE: `%s mV`', BundleEvalHelpers.scalarToMarkdownText(BundleEvalHelpers.fieldOr(metrics, 'max_voltage_rmse_mv', NaN))); ...
                ''; ...
                '### Case Summary'; ...
                ''};

            lines = BundleEvalHelpers.appendMarkdownLines(lines, BundleEvalHelpers.markdownTableFromStructArray(summary_rows));
            lines = BundleEvalHelpers.appendMarkdownLines(lines, {''; '### Per-Case Detailed Metrics'; ''});
            lines = BundleEvalHelpers.appendMarkdownLines(lines, BundleEvalHelpers.markdownTableFromStructArray(case_rows));
            lines = BundleEvalHelpers.appendMarkdownLines(lines, {''; end_marker});
            markdown_text = strjoin(lines, newline);
        end

        function rows = caseMetricsTable(case_results)
            if isempty(case_results)
                rows = struct([]);
                return;
            end

            rows = repmat(struct( ...
                'case_name', '', ...
                'source_file', '', ...
                'temperature_degC', NaN, ...
                'samples', NaN, ...
                'voltage_rmse_mv', NaN, ...
                'voltage_mean_error_mv', NaN, ...
                'voltage_mae_mv', NaN, ...
                'voltage_max_abs_error_mv', NaN, ...
                'voltage_corr', NaN, ...
                'fit_slope', NaN, ...
                'fit_intercept', NaN), numel(case_results), 1);

            for idx = 1:numel(case_results)
                metrics = BundleEvalHelpers.fieldOr(case_results(idx), 'metrics', struct());
                voltage_fit = BundleEvalHelpers.fieldOr(metrics, 'voltage_fit', [NaN, NaN]);
                rows(idx).case_name = char(BundleEvalHelpers.fieldOr(case_results(idx), 'name', ''));
                rows(idx).source_file = char(BundleEvalHelpers.fieldOr(case_results(idx), 'source_file', ''));
                rows(idx).temperature_degC = BundleEvalHelpers.fieldOr(case_results(idx), 'tc', NaN);
                rows(idx).samples = BundleEvalHelpers.fieldOr(case_results(idx), 'sample_count', NaN);
                rows(idx).voltage_rmse_mv = BundleEvalHelpers.fieldOr(metrics, 'voltage_rmse_mv', NaN);
                rows(idx).voltage_mean_error_mv = BundleEvalHelpers.fieldOr(metrics, 'voltage_mean_error_mv', NaN);
                rows(idx).voltage_mae_mv = BundleEvalHelpers.fieldOr(metrics, 'voltage_mae_mv', NaN);
                rows(idx).voltage_max_abs_error_mv = BundleEvalHelpers.fieldOr(metrics, 'voltage_max_abs_error_mv', NaN);
                rows(idx).voltage_corr = BundleEvalHelpers.fieldOr(metrics, 'voltage_corr', NaN);
                rows(idx).fit_slope = BundleEvalHelpers.getVectorValue(voltage_fit, 1);
                rows(idx).fit_intercept = BundleEvalHelpers.getVectorValue(voltage_fit, 2);
            end
        end

        function artifact = buildAutotuningSummaryArtifact(autotuning_results, heavy_results_file, summary_file, markdown_file, suite_version, scenario_id)
            artifact = struct();
            artifact.artifact_class = 'summary';
            artifact.kind = 'autotuning_summary';
            artifact.layer = 'autotuning';
            artifact.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            artifact.suite_version = suite_version;
            artifact.scenario_id = scenario_id;
            artifact.summary_json_file = BundleEvalHelpers.normalizeStoredPath(summary_file);
            artifact.summary_markdown_file = BundleEvalHelpers.normalizeStoredPath(markdown_file);
            artifact.heavy_results_file = BundleEvalHelpers.normalizeStoredPath(heavy_results_file);
            artifact.figure_root = BundleEvalHelpers.normalizeStoredPath(fullfile('results', 'figures', 'autotuning', suite_version, scenario_id));
            artifact.run_name = BundleEvalHelpers.fieldOr(autotuning_results.config, 'run_name', '');
            artifact.saved_results_file = BundleEvalHelpers.normalizeStoredPath(BundleEvalHelpers.fieldOr(autotuning_results, 'saved_results_file', ''));
            artifact.summary_table = BundleEvalHelpers.tableRows(BundleEvalHelpers.fieldOr(autotuning_results, 'summary_table', table()));
            artifact.scenarios = BundleEvalHelpers.summarizeAutotuningScenarios(BundleEvalHelpers.fieldOr(autotuning_results.config, 'scenarios', struct([])));
        end

        function markdown_text = renderAutotuningSummaryMarkdown(artifact)
            lines = { ...
                '# Promoted Autotuning Summary'; ...
                ''; ...
                sprintf('- layer: `%s`', artifact.layer); ...
                sprintf('- suite: `%s`', artifact.suite_version); ...
                sprintf('- scenario: `%s`', artifact.scenario_id); ...
                sprintf('- run name: `%s`', artifact.run_name); ...
                sprintf('- generated: `%s`', artifact.created_on); ...
                sprintf('- promoted JSON: `%s`', artifact.summary_json_file); ...
                sprintf('- heavy MAT: `%s`', artifact.heavy_results_file); ...
                sprintf('- figures root: `%s`', artifact.figure_root); ...
                ''};

            scenario_rows = artifact.scenarios;
            if ~isempty(scenario_rows)
                lines = BundleEvalHelpers.appendMarkdownLines(lines, {'## Scenario Metadata'; ''});
                lines = BundleEvalHelpers.appendMarkdownLines(lines, BundleEvalHelpers.markdownTableFromStructArray(scenario_rows));
                lines = BundleEvalHelpers.appendMarkdownLines(lines, {''});
            end

            lines = BundleEvalHelpers.appendMarkdownLines(lines, {'## Per-Estimator Metrics'; ''});
            lines = BundleEvalHelpers.appendMarkdownLines(lines, BundleEvalHelpers.markdownTableFromStructArray(artifact.summary_table));
            lines = BundleEvalHelpers.appendMarkdownLines(lines, {''});
            markdown_text = strjoin(lines, newline);
        end

        function artifact = buildAutotuningTunedParamsArtifact(autotuning_results, heavy_results_file, json_file, suite_version, scenario_id)
            artifact = struct();
            artifact.artifact_class = 'summary';
            artifact.kind = 'autotuning_tuned_params';
            artifact.layer = 'autotuning';
            artifact.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            artifact.suite_version = suite_version;
            artifact.scenario_id = scenario_id;
            artifact.tuned_params_json_file = BundleEvalHelpers.normalizeStoredPath(json_file);
            artifact.heavy_results_file = BundleEvalHelpers.normalizeStoredPath(heavy_results_file);
            artifact.run_name = BundleEvalHelpers.fieldOr(autotuning_results.config, 'run_name', '');
            artifact.scenarios = BundleEvalHelpers.summarizeAutotuningTunedParams( ...
                BundleEvalHelpers.fieldOr(autotuning_results.config, 'scenarios', struct([])), ...
                BundleEvalHelpers.fieldOr(autotuning_results, 'summary_table', table()));
        end

        function scenarios = summarizeAutotuningScenarios(raw_scenarios)
            scenarios = struct([]);
            if isempty(raw_scenarios)
                return;
            end

            scenarios = repmat(struct( ...
                'name', '', ...
                'suite_version', '', ...
                'dataset_file', '', ...
                'esc_model_file', '', ...
                'rom_model_file', '', ...
                'estimator_names', {{}}), numel(raw_scenarios), 1);

            for idx = 1:numel(raw_scenarios)
                scenario = raw_scenarios(idx);
                scenarios(idx).name = BundleEvalHelpers.fieldOr(scenario, 'name', '');
                scenarios(idx).suite_version = BundleEvalHelpers.fieldOr(scenario, 'suite_version', '');
                if isfield(scenario, 'datasetSpec')
                    scenarios(idx).dataset_file = BundleEvalHelpers.normalizeStoredPath(BundleEvalHelpers.fieldOr(scenario.datasetSpec, 'dataset_file', ''));
                end
                if isfield(scenario, 'modelSpec')
                    scenarios(idx).esc_model_file = BundleEvalHelpers.normalizeStoredPath(BundleEvalHelpers.fieldOr(scenario.modelSpec, 'esc_model_file', ''));
                    scenarios(idx).rom_model_file = BundleEvalHelpers.normalizeStoredPath(BundleEvalHelpers.fieldOr(scenario.modelSpec, 'rom_model_file', ''));
                end
                scenarios(idx).estimator_names = BundleEvalHelpers.normalizeCellstr(BundleEvalHelpers.fieldOr(scenario, 'estimator_names', {}));
            end
        end

        function scenarios = summarizeAutotuningTunedParams(raw_scenarios, summary_table)
            scenarios = struct([]);
            if isempty(raw_scenarios)
                return;
            end

            summary_rows = BundleEvalHelpers.tableRows(summary_table);
            scenarios = repmat(struct( ...
                'name', '', ...
                'suite_version', '', ...
                'dataset_file', '', ...
                'esc_model_file', '', ...
                'rom_model_file', '', ...
                'estimators', struct([])), numel(raw_scenarios), 1);

            for idx = 1:numel(raw_scenarios)
                scenario = raw_scenarios(idx);
                scenarios(idx).name = BundleEvalHelpers.fieldOr(scenario, 'name', '');
                scenarios(idx).suite_version = BundleEvalHelpers.fieldOr(scenario, 'suite_version', '');
                if isfield(scenario, 'datasetSpec')
                    scenarios(idx).dataset_file = BundleEvalHelpers.normalizeStoredPath(BundleEvalHelpers.fieldOr(scenario.datasetSpec, 'dataset_file', ''));
                end
                if isfield(scenario, 'modelSpec')
                    scenarios(idx).esc_model_file = BundleEvalHelpers.normalizeStoredPath(BundleEvalHelpers.fieldOr(scenario.modelSpec, 'esc_model_file', ''));
                    scenarios(idx).rom_model_file = BundleEvalHelpers.normalizeStoredPath(BundleEvalHelpers.fieldOr(scenario.modelSpec, 'rom_model_file', ''));
                end
                scenarios(idx).estimators = BundleEvalHelpers.collectScenarioTunedEstimators( ...
                    BundleEvalHelpers.fieldOr(scenario, 'name', ''), summary_rows);
            end
        end

        function estimators = collectScenarioTunedEstimators(scenario_name, summary_rows)
            estimators = struct([]);
            if isempty(summary_rows)
                return;
            end

            rows = summary_rows(arrayfun(@(row) strcmp(char(BundleEvalHelpers.fieldOr(row, 'Scenario', '')), char(scenario_name)), summary_rows));
            if isempty(rows)
                return;
            end

            estimators = repmat(struct( ...
                'estimator_name', '', ...
                'objective_metric', '', ...
                'best_objective_value', NaN, ...
                'tuned_parameters', struct([])), numel(rows), 1);

            for idx = 1:numel(rows)
                row = rows(idx);
                tuned_parameters = struct([]);
                param_idx = 0;
                if isfield(row, 'ProcessNoiseField') && ~isempty(row.ProcessNoiseField)
                    param_idx = param_idx + 1;
                    tuned_parameters(param_idx).name = char(row.ProcessNoiseField);
                    tuned_parameters(param_idx).value = row.ProcessNoise;
                end
                if isfield(row, 'SensorNoiseField') && ~isempty(row.SensorNoiseField)
                    param_idx = param_idx + 1;
                    tuned_parameters(param_idx).name = char(row.SensorNoiseField);
                    tuned_parameters(param_idx).value = row.SensorNoise;
                end

                estimators(idx).estimator_name = char(BundleEvalHelpers.fieldOr(row, 'Estimator', ''));
                estimators(idx).objective_metric = char(BundleEvalHelpers.fieldOr(row, 'ObjectiveMetric', ''));
                estimators(idx).best_objective_value = BundleEvalHelpers.fieldOr(row, 'ObjectiveValue', NaN);
                estimators(idx).tuned_parameters = tuned_parameters;
            end
        end

        function tuning_spec = resolveStep4TuningSpec(profile_file, tuned_params_file, scenario_name)
            tuning_spec = struct( ...
                'kind', 'autotuning_profile', ...
                'param_file', profile_file, ...
                'scenario_name', scenario_name, ...
                'selection_policy', 'best_objective', ...
                'fallback_to_default', true);

            if exist(profile_file, 'file') == 2
                return;
            end

            if exist(tuned_params_file, 'file') ~= 2
                warning('BundleEvalHelpers:MissingTuningProfile', ...
                    ['Neither the heavy autotuning MAT profile nor the promoted tuned-params JSON was found. ', ...
                     'Step 4 will fall back to default tuning if needed.']);
                return;
            end

            reconstructed_profile_file = BundleEvalHelpers.reconstructAutotuningProfileFromJson( ...
                tuned_params_file, profile_file, scenario_name);
            tuning_spec.param_file = reconstructed_profile_file;
        end

        function profile_file = reconstructAutotuningProfileFromJson(json_file, desired_profile_file, default_scenario_name)
            src = jsondecode(fileread(json_file));
            scenarios = BundleEvalHelpers.fieldOr(src, 'scenarios', struct([]));
            if isempty(scenarios)
                error('BundleEvalHelpers:BadTunedParamsJson', ...
                    'No scenarios were found in %s.', json_file);
            end
            if ~isstruct(scenarios)
                error('BundleEvalHelpers:BadTunedParamsJson', ...
                    'Expected struct scenarios in %s.', json_file);
            end
            scenarios = scenarios(:);

            runs = struct([]);
            run_idx = 0;
            for scenario_idx = 1:numel(scenarios)
                scenario = scenarios(scenario_idx);
                scenario_name = BundleEvalHelpers.fieldOr(scenario, 'name', default_scenario_name);
                estimators = BundleEvalHelpers.fieldOr(scenario, 'estimators', struct([]));
                if isempty(estimators)
                    continue;
                end
                estimators = estimators(:);
                for est_idx = 1:numel(estimators)
                    est = estimators(est_idx);
                    tuning = struct();
                    tuned_parameters = BundleEvalHelpers.fieldOr(est, 'tuned_parameters', struct([]));
                    if ~isempty(tuned_parameters)
                        tuned_parameters = tuned_parameters(:);
                        for param_idx = 1:numel(tuned_parameters)
                            param_name = BundleEvalHelpers.fieldOr(tuned_parameters(param_idx), 'name', '');
                            if isempty(param_name)
                                continue;
                            end
                            tuning.(param_name) = BundleEvalHelpers.fieldOr(tuned_parameters(param_idx), 'value', NaN);
                        end
                    end

                    run_idx = run_idx + 1;
                    runs(run_idx, 1).estimator_name = BundleEvalHelpers.fieldOr(est, 'estimator_name', '');
                    runs(run_idx, 1).scenario_name = scenario_name;
                    runs(run_idx, 1).objective_metric = BundleEvalHelpers.fieldOr(est, 'objective_metric', '');
                    runs(run_idx, 1).best_objective = BundleEvalHelpers.fieldOr(est, 'best_objective_value', NaN);
                    runs(run_idx, 1).best_tuning = tuning;
                end
            end

            if isempty(runs)
                error('BundleEvalHelpers:BadTunedParamsJson', ...
                    'No estimator tuning entries could be reconstructed from %s.', json_file);
            end

            autotuning_results = struct();
            autotuning_results.kind = 'autotuning_results';
            autotuning_results.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            autotuning_results.runs = runs;

            profile_file = desired_profile_file;
            BundleEvalHelpers.ensureDir(fileparts(profile_file));
            save(profile_file, 'autotuning_results');
        end

        function writeNoiseSweepSummaryArtifacts(results_file, summary_file, markdown_file, suite_version, scenario_id)
            BundleEvalHelpers.ensureDir(fileparts(summary_file));
            BundleEvalHelpers.ensureDir(fileparts(markdown_file));

            saved_noise = load(results_file, 'sweepResults');
            if ~isfield(saved_noise, 'sweepResults')
                error('BundleEvalHelpers:MissingNoiseSweepResults', ...
                    'Expected variable "sweepResults" in %s.', results_file);
            end

            noise_summary = BundleEvalHelpers.buildNoiseSweepSummaryArtifact( ...
                saved_noise.sweepResults, results_file, summary_file, markdown_file, ...
                suite_version, scenario_id);
            BundleEvalHelpers.writeJsonArtifact(summary_file, noise_summary);
            BundleEvalHelpers.writeMarkdownArtifact(markdown_file, BundleEvalHelpers.renderNoiseSweepSummaryMarkdown(noise_summary));
        end

        function artifact = buildNoiseSweepSummaryArtifact(sweep_results, heavy_results_file, summary_file, markdown_file, suite_version, scenario_id)
            artifact = struct();
            artifact.artifact_class = 'summary';
            artifact.kind = 'noise_cov_summary';
            artifact.layer = 'evaluation';
            artifact.suite_version = char(suite_version);
            artifact.scenario_id = char(scenario_id);
            artifact.created_on = char(datetime('now', 'TimeZone', 'local', ...
                'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
            artifact.summary_json_file = BundleEvalHelpers.normalizeStoredPath(summary_file);
            artifact.summary_markdown_file = BundleEvalHelpers.normalizeStoredPath(markdown_file);
            artifact.heavy_results_file = BundleEvalHelpers.normalizeStoredPath(heavy_results_file);
            artifact.saved_results_file = BundleEvalHelpers.normalizeStoredPath(BundleEvalHelpers.fieldOr(sweep_results, 'saved_results_file', ''));
            artifact.dataset_mode = char(BundleEvalHelpers.fieldOr(sweep_results, 'dataset_mode', 'unknown'));
            artifact.sweep_mode = char(BundleEvalHelpers.fieldOr(sweep_results, 'sweep_mode', 'unknown'));
            artifact.total_runs = BundleEvalHelpers.fieldOr(sweep_results, 'total_runs', NaN);
            artifact.elapsed_seconds = BundleEvalHelpers.fieldOr(sweep_results, 'elapsed_seconds', NaN);
            artifact.sigma_w_values = reshape(BundleEvalHelpers.fieldOr(sweep_results, 'sigma_w_values', []), 1, []);
            artifact.sigma_v_values = reshape(BundleEvalHelpers.fieldOr(sweep_results, 'sigma_v_values', []), 1, []);
            artifact.n_sigma_w = numel(artifact.sigma_w_values);
            artifact.n_sigma_v = numel(artifact.sigma_v_values);
            artifact.estimator_names = BundleEvalHelpers.normalizeCellstr(BundleEvalHelpers.fieldOr(sweep_results, 'estimator_names', {}));
            artifact.summary_table = BundleEvalHelpers.tableRows(BundleEvalHelpers.fieldOr(sweep_results, 'summary_table', table()));
        end

        function markdown_text = renderNoiseSweepSummaryMarkdown(artifact)
            lines = { ...
                '# Promoted Noise-Covariance Sweep Summary'; ...
                ''; ...
                sprintf('- layer: `%s`', artifact.layer); ...
                sprintf('- suite: `%s`', artifact.suite_version); ...
                sprintf('- scenario: `%s`', artifact.scenario_id); ...
                sprintf('- generated: `%s`', artifact.created_on); ...
                sprintf('- promoted JSON: `%s`', artifact.summary_json_file); ...
                sprintf('- heavy MAT: `%s`', artifact.heavy_results_file); ...
                sprintf('- saved MAT: `%s`', artifact.saved_results_file); ...
                sprintf('- dataset mode: `%s`', artifact.dataset_mode); ...
                sprintf('- sweep mode: `%s`', artifact.sweep_mode); ...
                sprintf('- estimators: `%d`', numel(artifact.estimator_names)); ...
                sprintf('- total runs: `%s`', BundleEvalHelpers.scalarToMarkdownText(artifact.total_runs)); ...
                sprintf('- elapsed seconds: `%s`', BundleEvalHelpers.scalarToMarkdownText(artifact.elapsed_seconds)); ...
                sprintf('- sigma_w points: `%d`', artifact.n_sigma_w); ...
                sprintf('- sigma_v points: `%d`', artifact.n_sigma_v); ...
                sprintf('- sigma_w axis: `%s`', BundleEvalHelpers.escapeMarkdown(strjoin(cellstr(string(artifact.sigma_w_values)), ', '))); ...
                sprintf('- sigma_v axis: `%s`', BundleEvalHelpers.escapeMarkdown(strjoin(cellstr(string(artifact.sigma_v_values)), ', '))); ...
                ''};

            lines = BundleEvalHelpers.appendMarkdownLines(lines, {'## Per-Estimator Best Metrics'; ''});
            lines = BundleEvalHelpers.appendMarkdownLines(lines, BundleEvalHelpers.markdownTableFromStructArray(artifact.summary_table));
            lines = BundleEvalHelpers.appendMarkdownLines(lines, {''});
            markdown_text = strjoin(lines, newline);
        end

        function cfg = buildStep5NoiseSweepConfig(estimator_names, results_file)
            repo_root = BundleEvalHelpers.resolveBundleRepoRoot();
            cfg = struct();
            cfg.dataset_mode = 'esc';
            cfg.sweep_mode = 'grid';
            cfg.tc = 25;
            cfg.ts = 1;
            cfg.esc_model_file = fullfile(repo_root, 'models', 'ATL20model_P25.mat');
            cfg.rom_file = fullfile(repo_root, 'models', 'ROM_ATL20_beta.mat');
            cfg.esc_dataset_file = fullfile( ...
                repo_root, 'data', 'evaluation', 'processed', 'desktop_atl20_bss_v1', 'nominal', ...
                'esc_bus_coreBattery_dataset.mat');
            cfg.raw_bus_file = fullfile( ...
                repo_root, 'data', 'evaluation', 'raw', 'omtlife8ahc_hp', 'Bus_CoreBatteryData_Data.mat');
            cfg.estimator_names = estimator_names;
            cfg.use_parallel = true;
            cfg.auto_start_pool = true;
            cfg.SaveResults = true;
            cfg.results_file = BundleEvalHelpers.resolveRepoPath(results_file, repo_root);
            cfg.NoiseSummaryfigs = false;
            cfg.PlotSocRmsefigs = true;
            cfg.PlotVoltageRmsefigs = true;
            cfg.PlotEaEkfCovfigs = true;
        end

        function cfg = buildStep6InitSocSweepConfig(estimator_names, results_file, tuning_spec)
            repo_root = BundleEvalHelpers.resolveBundleRepoRoot();
            cfg = struct();
            cfg.tc = 25;
            cfg.ts = 1;
            cfg.dataset_mode = 'esc';
            cfg.SweepSummaryfigs = false;
            cfg.PlotSocEstimationfigs = true;
            cfg.PlotVoltageEstimationfigs = true;
            cfg.SaveResults = true;
            cfg.results_file = results_file;
            cfg.parallel = struct( ...
                'use_parallel', true, ...
                'auto_start_pool', true, ...
                'pool_size', []);
            cfg.esc_dataset_file = fullfile( ...
                repo_root, 'data', 'evaluation', 'processed', 'desktop_atl20_bss_v1', ...
                'nominal', 'esc_bus_coreBattery_dataset.mat');
            cfg.rom_dataset_file = fullfile( ...
                repo_root, 'data', 'evaluation', 'processed', 'behavioral_nmc30_bss_v1', ...
                'nominal', 'rom_bus_coreBattery_dataset.mat');
            cfg.raw_bus_file = fullfile( ...
                repo_root, 'data', 'evaluation', 'raw', 'omtlife8ahc_hp', ...
                'Bus_CoreBatteryData_Data.mat');
            cfg.esc_model_file = fullfile(repo_root, 'models', 'ATL20model_P25.mat');
            cfg.rom_file = fullfile(repo_root, 'models', 'ROM_ATL20_beta.mat');
            cfg.estimator_names = estimator_names;
            cfg.tuning = tuning_spec;
        end

        function case_cfg = loadInjectionCaseFromManifest(manifest_file)
            manifest = jsondecode(fileread(manifest_file));
            case_cfg = manifest.injection_config;
            case_cfg.case_id = char(BundleEvalHelpers.fieldOr(manifest, 'case_id', ''));
            case_cfg.overwrite = false;
        end

        function cases = combineInjectionCases(varargin)
            if nargin == 0
                cases = struct([]);
                return;
            end

            all_fields = {};
            for idx = 1:nargin
                all_fields = union(all_fields, fieldnames(varargin{idx}), 'stable');
            end

            cases = repmat(struct(), nargin, 1);
            for idx = 1:nargin
                for field_idx = 1:numel(all_fields)
                    field_name = all_fields{field_idx};
                    if isfield(varargin{idx}, field_name)
                        cases(idx, 1).(field_name) = varargin{idx}.(field_name);
                    else
                        cases(idx, 1).(field_name) = [];
                    end
                end
            end
        end

        function exportFigureCollection(collection, output_root, prefix, figure_format)
            if nargin < 4 || isempty(figure_format)
                figure_format = 'png';
            end

            BundleEvalHelpers.ensureDir(output_root);
            BundleEvalHelpers.exportFigureNode(collection, output_root, prefix, figure_format);
            BundleEvalHelpers.closeAllFigureNodes(collection);
        end

        function exportFigureNode(node, output_root, prefix, figure_format)
            if isempty(node)
                return;
            end

            if isgraphics(node, 'figure')
                BundleEvalHelpers.exportSingleFigure(node, fullfile(output_root, [BundleEvalHelpers.sanitizeToken(prefix) '.' figure_format]), figure_format);
                return;
            end

            if isstruct(node)
                fields = fieldnames(node);
                for idx = 1:numel(fields)
                    BundleEvalHelpers.exportFigureNode(node.(fields{idx}), output_root, [prefix '_' fields{idx}], figure_format);
                end
                return;
            end

            if iscell(node)
                for idx = 1:numel(node)
                    BundleEvalHelpers.exportFigureNode(node{idx}, output_root, sprintf('%s_%02d', prefix, idx), figure_format);
                end
                return;
            end

            if (isnumeric(node) || isa(node, 'matlab.ui.Figure') || isa(node, 'matlab.graphics.Graphics')) && all(isgraphics(node))
                for idx = 1:numel(node)
                    BundleEvalHelpers.exportFigureNode(node(idx), output_root, sprintf('%s_%02d', prefix, idx), figure_format);
                end
            end
        end

        function closeAllFigureNodes(node)
            if isempty(node)
                return;
            end

            if isgraphics(node, 'figure')
                close(node);
                return;
            end

            if isstruct(node)
                fields = fieldnames(node);
                for idx = 1:numel(fields)
                    BundleEvalHelpers.closeAllFigureNodes(node.(fields{idx}));
                end
                return;
            end

            if iscell(node)
                for idx = 1:numel(node)
                    BundleEvalHelpers.closeAllFigureNodes(node{idx});
                end
                return;
            end

            if isnumeric(node) && all(isgraphics(node))
                close(node(ishandle(node)));
            end
        end

        function exportSingleFigure(fig_handle, output_file, figure_format)
            BundleEvalHelpers.ensureDir(fileparts(output_file));
            switch lower(char(figure_format))
                case 'png'
                    exportgraphics(fig_handle, output_file, 'Resolution', 150);
                case 'pdf'
                    exportgraphics(fig_handle, output_file, 'ContentType', 'vector');
                otherwise
                    saveas(fig_handle, output_file);
            end
        end

        function rows = tableRows(tbl)
            if isempty(tbl)
                rows = struct([]);
                return;
            end
            if isstruct(tbl)
                rows = tbl;
                return;
            end
            rows = table2struct(tbl);
        end

        function writeJsonArtifact(output_file, artifact)
            BundleEvalHelpers.ensureDir(fileparts(output_file));
            fid = fopen(output_file, 'w');
            if fid < 0
                error('BundleEvalHelpers:OpenFailed', ...
                    'Could not open %s for writing.', output_file);
            end
            cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fprintf(fid, '%s', jsonencode(artifact, 'PrettyPrint', true));
        end

        function writeMarkdownArtifact(output_file, markdown_text)
            BundleEvalHelpers.ensureDir(fileparts(output_file));
            fid = fopen(output_file, 'w');
            if fid < 0
                error('BundleEvalHelpers:OpenFailed', ...
                    'Could not open %s for writing.', output_file);
            end
            cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fprintf(fid, '%s', markdown_text);
        end

        function lines = appendMarkdownLines(lines, new_lines)
            lines = BundleEvalHelpers.normalizeMarkdownLines(lines);
            lines = [lines; BundleEvalHelpers.normalizeMarkdownLines(new_lines)];
        end

        function lines = markdownTableFromStructArray(rows)
            if isempty(rows)
                lines = {'_No rows available._'};
                return;
            end

            if ~isstruct(rows)
                error('BundleEvalHelpers:BadMarkdownRows', ...
                    'Expected a struct array to render a Markdown table.');
            end

            fields = fieldnames(rows);
            header = ['| ' strjoin(fields.', ' | ') ' |'];
            separator = ['| ' strjoin(repmat({'---'}, 1, numel(fields)), ' | ') ' |'];
            lines = cell(numel(rows) + 2, 1);
            lines{1} = header;
            lines{2} = separator;
            for row_idx = 1:numel(rows)
                values = cell(1, numel(fields));
                for field_idx = 1:numel(fields)
                    values{field_idx} = BundleEvalHelpers.scalarToMarkdownText(rows(row_idx).(fields{field_idx}));
                end
                lines{row_idx + 2} = ['| ' strjoin(values, ' | ') ' |'];
            end
            lines = BundleEvalHelpers.normalizeMarkdownLines(lines);
        end

        function lines = normalizeMarkdownLines(lines)
            if isstring(lines)
                lines = cellstr(lines(:));
            elseif ischar(lines)
                lines = {lines};
            elseif isempty(lines)
                lines = cell(0, 1);
            elseif ~iscell(lines)
                error('BundleEvalHelpers:BadMarkdownLines', ...
                    'Expected Markdown content as a char vector, string array, or cell array.');
            end
            lines = lines(:);
        end

        function text = scalarToMarkdownText(value)
            if ischar(value)
                text = BundleEvalHelpers.escapeMarkdown(char(value));
            elseif isstring(value) && isscalar(value)
                text = BundleEvalHelpers.escapeMarkdown(char(value));
            elseif isnumeric(value) && isscalar(value)
                if isnan(value)
                    text = 'NaN';
                else
                    text = num2str(value, '%.6g');
                end
            elseif islogical(value) && isscalar(value)
                text = char(string(value));
            elseif isempty(value)
                text = '';
            elseif iscell(value)
                text = BundleEvalHelpers.escapeMarkdown(strjoin(BundleEvalHelpers.normalizeCellstr(value), ', '));
            else
                text = BundleEvalHelpers.escapeMarkdown(strrep(jsonencode(value), '|', '\|'));
            end
            text = strrep(text, newline, ' ');
        end

        function text = escapeMarkdown(text)
            text = strrep(char(text), '|', '\|');
        end

        function value = getVectorValue(values, index)
            value = NaN;
            if isempty(values) || numel(values) < index
                return;
            end
            value = values(index);
        end

        function token = sanitizeToken(value)
            token = regexprep(char(value), '[^A-Za-z0-9._-]+', '_');
            token = regexprep(token, '_+', '_');
            token = strtrim(token);
            if isempty(token)
                token = 'artifact';
            end
        end

        function value = fieldOr(s, field_name, default_value)
            if isstruct(s) && isfield(s, field_name) && ~isempty(s.(field_name))
                value = s.(field_name);
            else
                value = default_value;
            end
        end

        function values = normalizeCellstr(values)
            if ischar(values)
                values = {values};
            elseif isa(values, 'string')
                values = cellstr(values(:));
            elseif isempty(values)
                values = {};
            elseif ~iscell(values)
                error('BundleEvalHelpers:BadCellstr', ...
                    'Expected a char vector, string array, or cell array.');
            end
        end

        function value = aggregateCaseMetric(case_results, metric_field, mode)
            value = NaN;
            if isempty(case_results)
                return;
            end

            values = NaN(numel(case_results), 1);
            for idx = 1:numel(case_results)
                metrics = BundleEvalHelpers.fieldOr(case_results(idx), 'metrics', struct());
                values(idx) = BundleEvalHelpers.fieldOr(metrics, metric_field, NaN);
            end

            switch lower(char(mode))
                case 'mean'
                    value = mean(values, 'omitnan');
                case 'max'
                    value = max(values, [], 'omitnan');
                otherwise
                    error('BundleEvalHelpers:BadAggregateMode', ...
                        'Unsupported aggregate mode "%s".', mode);
            end
        end

        function path_out = normalizeStoredPath(path_in)
            if isempty(path_in)
                path_out = '';
            else
                path_out = BundleEvalHelpers.relativizeRepoPath(path_in, BundleEvalHelpers.resolveBundleRepoRoot());
            end
        end

        function path_out = relativizeRepoPath(path_in, repo_root)
            path_out = strrep(char(path_in), '\', '/');
            path_out = regexprep(path_out, '/+', '/');
            repo_root = strrep(char(repo_root), '\', '/');
            repo_root = regexprep(repo_root, '/+', '/');
            repo_prefix = [repo_root '/'];
            if strcmpi(path_out, repo_root)
                path_out = '.';
            elseif strncmpi(path_out, repo_prefix, numel(repo_prefix))
                path_out = path_out(numel(repo_prefix) + 1:end);
            end
        end
    end
end

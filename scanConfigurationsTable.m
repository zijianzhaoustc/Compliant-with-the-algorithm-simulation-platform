function t = scanConfigurationsTable(plan)
%SCANCONFIGURATIONSTABLE Full per-row plan including all fixed parameters.
rows=rmfield(plan,'params');
for i=1:numel(plan), rows(i).parameters_json=string(jsonencode(plan(i).params)); end
t=struct2table(rows);
end

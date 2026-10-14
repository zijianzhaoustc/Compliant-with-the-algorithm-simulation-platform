function rows=timestampImportQuality(data)
%TIMESTAMPIMPORTQUALITY Small per-channel audit; never duplicate tag arrays.
rows=table();
if ~isfield(data,'metadata'), return; end
for device=["F","S"]
    if ~isfield(data.metadata,device), continue; end
    meta=data.metadata.(device);
    if ~isfield(meta,'timestampOrder'), continue; end
    channels=["SPD1","SPD2","SYNC"];
    for k=1:numel(meta.timestampOrder)
        q=meta.timestampOrder{k};
        row=table(device,channels(k),string(q.file),q.timestampCount,q.wasReordered, ...
            q.descendingAdjacentCount,string(q.indexBasis),'VariableNames', ...
            {'device','channel','source_file','timestamp_count','was_reordered', ...
            'descending_adjacent_count','association_index_basis'});
        rows=[rows;row]; %#ok<AGROW>
    end
end
end

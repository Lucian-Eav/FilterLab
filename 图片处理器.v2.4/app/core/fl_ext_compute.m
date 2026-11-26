function R=fl_ext_compute(ids,inputs,settings)
%FL_EXT_COMPUTE Replay from resolved pixels, metadata and module settings.
R.Modules=ids; R.Inputs=inputs; R.Options=settings; R.Results=cell(1,4);
R.OutputDir=''; R.Figures={}; R.Metrics=table();
R.Summary=fl_ext_catalog(ids);
for id=ids
    switch id
        case 1
            m=fl_ext_moire(inputs.mountain.Image,inputs.screen_moire.Image,inputs.screen_moire.Meta,settings{id});
        case 2
            m=fl_ext_document(inputs.notebook.Image,inputs.notebook.Meta,settings{id});
        case 3
            m=fl_ext_motion(inputs.mountain.Image,settings{id});
        case 4
            m=fl_ext_allpass(inputs.naishu.Image,settings{id});
    end
    R.Results{id}=m;
    rows=m.Metrics;
    rows=addvars(rows,repmat(id,height(rows),1),'Before',1,'NewVariableNames','Module');
    if width(R.Metrics)==0, R.Metrics=rows; else, R.Metrics=[R.Metrics;rows]; end
end
end

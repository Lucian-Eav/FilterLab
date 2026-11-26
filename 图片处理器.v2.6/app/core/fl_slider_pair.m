function field = fl_slider_pair(parent,slider,tag,step,format,scale,varargin)
%FL_SLIDER_PAIR Pair a native slider with a range-checked numeric edit field.
% Scale converts slider units to display units (100 for percentages).
if nargin < 6, scale = 1; end
field = uieditfield(parent,'numeric','Limits',slider.Limits*scale, ...
    'Value',slider.Value*scale,'ValueDisplayFormat',format,'Tag',tag,varargin{:});
fig = ancestor(slider,'figure');
legacyKeys = ~isprop(slider,'Step') || isequal(getappdata(fig,'FlTestLegacySlider'),true);
if legacyKeys
    legacyChange = legacyRouter(fig);
else
    slider.Step = step;
end
hint = sprintf('范围 %g 至 %g；滑块聚焦后按 ← / → 微调 %g。', ...
    field.Limits(1),field.Limits(2),step*scale);
slider.Tooltip = hint; field.Tooltip = hint;
callback = slider.ValueChangedFcn;
preview = slider.ValueChangingFcn;
slider.ValueChangingFcn = @drag;
slider.ValueChangedFcn = @sliderChanged;
field.ValueChangedFcn = @(s,e)commit(s.Value/scale,e);
setappdata(slider,'NumberField',field);
setappdata(slider,'FineStep',step);
setappdata(slider,'InitialValue',slider.Value);

    function v = snap(v)
        lo = slider.Limits(1); hi = slider.Limits(2);
        v = min(hi,max(lo,round(lo + round((v-lo)/step)*step,12)));
    end
    function drag(s,e)
        field.Value = snap(e.Value)*scale;
        if ~isempty(preview), preview(s,e); end
    end
    function sliderChanged(s,e)
        v = s.Value;
        if legacyKeys && ~isempty(e) && isobject(e) && isprop(e,'PreviousValue')
            legacyChange(s,e,step,@commit);
            return;
        end
        commit(v,e);
    end
    function commit(v,e)
        v = snap(v);
        slider.Value = v; field.Value = v*scale;
        if ~isempty(callback)
            setappdata(fig,'FlCommittingSlider',slider);
            cleanup = onCleanup(@()clearCommit(fig));
            callback(slider,e);
        end
    end
end

function clearCommit(fig)
if isgraphics(fig) && isappdata(fig,'FlCommittingSlider')
    rmappdata(fig,'FlCommittingSlider');
end
end

function receive = legacyRouter(fig)
% Older sliders report their built-in movement before WindowKeyPressFcn.
% Wait briefly for that matching key, then submit one exact edit. Pointer-only
% changes use the thumb's absolute position. No key alone can edit a control.
receive = getappdata(fig,'FlLegacySliderRouter');
if ~isempty(receive), return; end
receive = @offer;
setappdata(fig,'FlLegacySliderRouter',receive);
pending = []; clock = [];
oldKey = fig.WindowKeyPressFcn; oldDown = fig.WindowButtonDownFcn;
fig.WindowKeyPressFcn = @key;
fig.WindowButtonDownFcn = @pointer;
addlistener(fig,'ObjectBeingDestroyed',@shutdown);
    function offer(s,e,stride,apply)
        finish(0);
        pending = struct('Control',s,'Previous',e.PreviousValue,'Absolute',s.Value, ...
            'Step',stride,'Apply',apply,'Event',e);
        if isempty(clock)
            clock = timer('ExecutionMode','singleShot','StartDelay',.1, ...
                'Name','FilterLab legacy slider commit','TimerFcn',@(~,~)finish(0));
        end
        start(clock);
    end
    function finish(direction)
        if isempty(pending), return; end
        edit = pending; pending = [];
        if ~isempty(clock) && strcmp(clock.Running,'on'), stop(clock); end
        if ~isgraphics(edit.Control) || strcmp(fig.BeingDeleted,'on'), return; end
        value = edit.Absolute;
        if direction ~= 0, value = edit.Previous + direction*edit.Step; end
        edit.Apply(value,edit.Event);
    end
    function key(src,e)
        direction = 0;
        if isempty(e.Modifier)
            direction = double(strcmp(e.Key,'rightarrow')) - double(strcmp(e.Key,'leftarrow'));
        end
        finish(direction);
        if ~isempty(oldKey), feval(oldKey,src,e); end
    end
    function pointer(src,e)
        finish(0);
        if ~isempty(oldDown), feval(oldDown,src,e); end
    end
    function shutdown(~,~)
        pending = [];
        if ~isempty(clock) && isvalid(clock), stop(clock); delete(clock); end
    end
end

function check_spectrum_lesson_gui(appDir,artifactDir)
% Actual button callbacks, snapshot lifetime and linked image data.
addpath(appDir,fullfile(appDir,'core'));
if ~isfolder(artifactDir), mkdir(artifactDir); end
host=FL_photo('Visible','off');
cleanup=onCleanup(@()discard(host)); %#ok<NASGU>
press(widget(host,'PhotoEnterEditor'));
change(widget(host,'PhotoToolSelect'),'PhotoTabFrequency');
entry=widget(host,'PhotoFrequencyLesson');
assert(strcmp(entry.Enable,'on'),'The frequency lesson needs a photo-free entry.');
press(entry); lesson=widget(groot,'SpectrumLesson');
assert(strcmp(lesson.Visible,'on')); assert(widget(lesson,'LessonStep').Value==1);
frame=lesson.Position; narrower=frame; narrower(3:4)=[900 620]; lesson.Position=narrower; drawnow;
grid=findall(lesson,'-depth',1,'Type','uigridlayout'); assert(isscalar(grid));
awaitWidth(grid,900);
lesson.Position=frame; awaitWidth(grid,frame(3));
press(entry); assert(widget(groot,'SpectrumLesson')==lesson,'Repeated click reopened the lesson.');
step=widget(lesson,'LessonStep');
for n=2:5
    press(widget(lesson,'LessonNext')); assert(step.Value==n);
end
press(widget(lesson,'LessonPrevious')); assert(step.Value==4);
change(step,2);
change(widget(lesson,'LessonSource'),'vertical');
change(widget(lesson,'LessonCycles'),8);
change(widget(lesson,'LessonFilter'),'all');
change(widget(lesson,'LessonShift'),0);
change(widget(lesson,'LessonView'),'magnitude');
start=picture(lesson,'LessonSpectrumAxes'); input=picture(lesson,'LessonInputAxes');
change(widget(lesson,'LessonShift'),4);
shifted=picture(lesson,'LessonInputAxes');
assert(~isequal(input,shifted),'Shift control did not move the stripes.');
next=picture(lesson,'LessonSpectrumAxes');
assert(max(abs(double(start(:))-double(next(:))))<1e-9,'Shift changed the magnitude image.');
change(widget(lesson,'LessonView'),'phase');
phase=picture(lesson,'LessonSpectrumAxes');
change(widget(lesson,'LessonShift'),8);
assert(~isequaln(phase,picture(lesson,'LessonSpectrumAxes')),'Phase view failed to respond to translation.');
change(widget(lesson,'LessonView'),'mask');
change(widget(lesson,'LessonFilter'),'low');
change(widget(lesson,'LessonCutoff'),0.01);
low=picture(lesson,'LessonOutputAxes');
assert(max(double(low(:)))-min(double(low(:)))<1e-9,'A low-pass cutoff below the stripes should leave only DC.');
change(widget(lesson,'LessonCutoff'),0.2);
passed=picture(lesson,'LessonOutputAxes'); assert(max(double(passed(:)))-min(double(passed(:)))>0.1);
press(widget(lesson,'LessonRestore'));
% Capture a calibrated stripe experiment with 3 panels visible.
change(step,2); change(widget(lesson,'LessonSource'),'vertical');
change(widget(lesson,'LessonCycles'),8); change(widget(lesson,'LessonFilter'),'all');
change(widget(lesson,'LessonView'),'magnitude'); drawnow;
exportapp(lesson,fullfile(artifactDir,'条纹与频谱.png'));
% Load a non-square photo via the normal editor and open the second entry.
api=getappdata(host,'PhotoActions'); [xx,yy]=meshgrid(1:111,1:73);
photo=uint8(cat(3,mod(3*xx,255),mod(4*yy,255),mod(2*xx+yy,255)));
path=fullfile(artifactDir,'lesson-test-input.png'); imwrite(photo,path); api.Open(path);
change(widget(host,'PhotoView'),'spectrum'); before=getappdata(host,'PhotoState');
entry=widget(host,'PhotoViewSpectrumLesson'); assert(strcmp(entry.Visible,'on'));
press(entry); assert(~isgraphics(lesson),'Changed photo still uses the old snapshot.');
lesson=widget(groot,'SpectrumLesson'); change(widget(lesson,'LessonStep'),5);
change(widget(lesson,'LessonSource'),'photo');
actual=picture(lesson,'LessonInputAxes'); assert(isequal(size(actual,1),73)&&isequal(size(actual,2),111));
assert(max(actual(:))>min(actual(:))); change(widget(lesson,'LessonFilter'),'high');
change(widget(lesson,'LessonCutoff'),0.12); drawnow;
assert(isequaln(before,getappdata(host,'PhotoState')),'Teaching controls changed editor state.');
change(widget(host,'PhotoView'),'split'); assert(strcmp(entry.Visible,'off'));
close(host); assert(~isgraphics(lesson),'Parent closure should dispose of its own lesson.');
fprintf('PASS: both GUI buttons, all five steps, shifts, phase, filter cutoffs, snapshot and cleanup.\n');
end

function awaitWidth(grid,width)
start=tic;
while abs(grid.Position(3)-width)>4 && toc(start)<5
    drawnow; pause(0.04);
end
assert(abs(grid.Position(3)-width)<=4,'Resized classroom does not fill the window.');
end
function h=widget(parent,tag)
h=findall(parent,'Tag',tag); assert(isscalar(h),'Missing or duplicate control: %s',tag);
end
function press(button)
assert(strcmp(button.Enable,'on'),'Disabled button: %s',button.Tag);
feval(button.ButtonPushedFcn,button,[]); drawnow;
end
function change(control,value)
control.Value=value; feval(control.ValueChangedFcn,control,[]); drawnow;
end
function pixels=picture(fig,tag)
image=findall(widget(fig,tag),'Type','image'); assert(isscalar(image),'Expected image in %s',tag);
pixels=image.CData;
end
function discard(h)
if isgraphics(h), delete(h); end
end

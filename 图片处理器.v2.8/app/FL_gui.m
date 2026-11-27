function fig = FL_gui(varargin)
%FL_GUI  打开 FilterLab 自然照片处理器。
% FL_gui                  打开照片工作区
% FL_gui('File','my.jpg')  直接载入照片
% 旧版信号滤波实验界面使用 FL_lab_gui。
fig = FL_photo(varargin{:});
end

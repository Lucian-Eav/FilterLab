function Y = fl_photo_geometry(X, operations)
%FL_PHOTO_GEOMETRY  按记录从原图重放裁剪、90 度旋转与翻转。
% Y=fl_photo_geometry(X,{struct('Type','crop','Value',[x y width height]), ...
%                        struct('Type','rotate','Value',1)})
% 坐标为每一步输入图像的原分辨率、1 起始整数；rotate 正数为逆时针。
% flip-h/flip-v 沿当前图像方向翻转。所有操作不插值、不改像素值。
if isempty(X)||ndims(X)~=3||size(X,3)~=3||~isnumeric(X)||~isreal(X)
    error('fl_photo_geometry:image','输入必须为非空 RGB 图像。');
end
if nargin<2, operations={}; end
if ~iscell(operations), error('fl_photo_geometry:operations','编辑记录必须为元胞数组。'); end
Y=X;
for k=1:numel(operations)
    op=operations{k};
    if ~isstruct(op)||~isscalar(op)||~isfield(op,'Type')
        error('fl_photo_geometry:operation','无效的几何编辑记录。');
    end
    switch op.Type
        case 'crop'
            if ~isfield(op,'Value'), error('fl_photo_geometry:crop','裁剪记录缺少选区。'); end
            r=op.Value;
            validateattributes(r,{'numeric'},{'real','finite','vector','numel',4,'integer','positive'});
            if r(1)+r(3)-1>size(Y,2)||r(2)+r(4)-1>size(Y,1)
                error('fl_photo_geometry:bounds','裁剪选区超出了当前照片。');
            end
            Y=Y(r(2):r(2)+r(4)-1,r(1):r(1)+r(3)-1,:);
        case 'rotate'
            if ~isfield(op,'Value'), error('fl_photo_geometry:rotate','旋转记录缺少方向。'); end
            validateattributes(op.Value,{'numeric'},{'real','finite','scalar','integer'});
            Y=rot90(Y,mod(op.Value,4));
        case 'flip-h'
            Y=Y(:,end:-1:1,:);
        case 'flip-v'
            Y=Y(end:-1:1,:,:);
        otherwise
            error('fl_photo_geometry:type','未知几何操作。');
    end
end
end

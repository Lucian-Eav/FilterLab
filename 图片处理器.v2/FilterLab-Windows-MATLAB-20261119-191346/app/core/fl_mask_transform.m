function [T,imageSize]=fl_mask_transform(originalSize,geometry)
%FL_MASK_TRANSFORM Original pixel-centre coordinates -> edited pixel centres.
imageSize=double(originalSize(1:2)); T=eye(3);
for k=1:numel(geometry)
    op=geometry{k}; h=imageSize(1); w=imageSize(2);
    switch op.Type
        case 'crop'
            r=op.Value; A=[1 0 1-r(1);0 1 1-r(2);0 0 1]; imageSize=[r(4) r(3)];
        case 'flip-h', A=[-1 0 w+1;0 1 0;0 0 1];
        case 'flip-v', A=[1 0 0;0 -1 h+1;0 0 1];
        case 'rotate'
            A=eye(3);
            for j=1:mod(op.Value,4)
                A=[0 1 0;-1 0 imageSize(2)+1;0 0 1]*A; imageSize=fliplr(imageSize);
            end
        otherwise, error('fl_mask_transform:operation','未知构图操作。');
    end
    T=A*T;
end
end

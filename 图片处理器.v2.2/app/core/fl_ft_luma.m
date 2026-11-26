function y = fl_ft_luma(x)
%FL_FT_LUMA Rec.709 luminance of a normalized RGB image.
y = .2126*x(:,:,1) + .7152*x(:,:,2) + .0722*x(:,:,3);
end

function blocked = fl_barrier_columns(n, w, offset)
%FL_BARRIER_COLUMNS Opaque columns of the grating, with a rightward pixel offset.
validateattributes(w, {'numeric'}, {'scalar','real','finite','integer','positive','<=',flintmax/2});
validateattributes(offset, {'numeric'}, {'scalar','real','finite','integer','>=',-flintmax,'<=',flintmax});
w = double(w);
period = 2*w;
phase = mod(double(offset), period);
blocked = mod((0:n-1) - phase, period) >= w;
end

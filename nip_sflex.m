function [J_est, extras] = nip_sflex(y, L, basis, reg_par)
%  [J_est, extras] = nip_sflex(y, L, basis, reg_par)
% Implements "Large-scale EEG/MEG source localization with spatial
% flexibility." by Haufe et al 2011
%
% Input:
%       y -> NcxNt. Matrix containing the data,
%       L -> NcxNd. Lead Field matrix
%       basis-> NdxNs. Matrix containing the spatial basis functions.
%       reg_par-> Scalar. Regularization parameter (1e-6 by default)
% Output:
%       J_rec -> NdxNt. Reconstructed activity (solution)
%       extras.regpar -> Scalar. Optimum regularization parameter
%
% Additional comments: Uses the DAL optimization toolbox.
% 
% Juan S. Castano C.
% 13 June 2013
NDUM = 3;

[Nc Nt] = size(y);
Nd = size(L,2);

if nargin <=3
    reg_par = 1e-6;
end

L = nip_translf(L);
for i = 1:3
    L(:,:,i) = L(:,:,i)*basis; % J simulado FINAL
end
nbasis = size(basis,2); 

L = nip_translf(L);

% A = sparse(kron(speye(Nt), L)); 

% A = nip_translf(A);
% A = permute(A,[1 3 2]);



% [xx0,~] = nip_loreta(y,L,diag(nip_lcmv(y,L)));
% xx0f =reshape(xx0',[3*Nt,nbasis]);

xx0f = zeros(3*Nt,nbasis);
% [xx,status]=dalsqgl(zeros(3,nbasis*Nt), A, y(:), reg_par);

XX = {@xforth, @xback, Nc*Nt, nbasis*NDUM*Nt};

opt.solver = 'qn';

[xx,status]=dalsqgl(xx0f, XX, y(:), reg_par,opt);
% xx = xx(:);
% xx = reshape(xx,[nbasis*3,Nt]);
index = 1:3:Nd;
for i = 0:2
    xxf(index+i,:) = xx(1+i:3:end,:)';
    xxf(index+i,:) = basis*xxf(index+i,:); % J simulado FINAL
end
J_est = xxf;

extras =[];
  
function xfo = xforth(x)
 Q = size(x, 2);
  [in1 indum] = find(x);
  in2 = unique(ceil(in1./(Nt)));
  l = length(in2)/NDUM;
  if l == 0
      xfo = zeros(Nc*Nt, Q);
  else
      xfo = reshape((L(:, in2)*reshape(permute(reshape(full(x(in1, :)), NDUM, Nt, l, Q), [1 3 2 4]), NDUM*l, Nt*Q)), Nc*Nt, Q);
  end
end
  
function xba = xback(x)
  xba = reshape(permute(reshape(L'*reshape(x, Nc, Nt), NDUM, nbasis, Nt), [1 3 2]), NDUM*Nt*nbasis, []);
end

end
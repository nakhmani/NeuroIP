function [J_rec extras] = nip_tfmxne_port(y,L,varargin)
% function [J_rec extras] = nip_tfmxne_port(y,L,varargin)
% Solve the inverse problem using the TF-MxNE approach as introduced by
% Gramfort et al 2012.
%  Input:
%         y -> NcxNt. Matrix containing the data,
%         L -> Ncx3Nd. Lead Field matrix
%         Additional options -> Key - Value pair:
%                 'sreg' -> scalar. Percentage of spatial
%                       regularization (between 0 and 1).
%                 'treg' -> scalar. Percentage of temporal
%                       regularization (between 0 and 1).
%                 options.a -> scalar. Time shift for the time frequency
%                       transform.
%                 options.m -> scalar. Frequency bins for the time frequency
%                       transform.
%                 options.tol -> Scalar. Default 5e-2
%   Output:
%         J_rec -> 3NdxNt. Reconstructed activity (solution)
%         extras. -> Currently empty
%
% Comments:
% Almost a literal translation of the python function tf_mixed_norm_solver found in:
% https://github.com/mne-tools/mne-python/blob/0ac3ac1a1634673da013109f38daf4f162cae117/mne/inverse_sparse/mxne_optim.py
% Juan S. Castano C.
% jscastanoc@gmail.com
% 14 Aug 2013

Ndor = size(L,2);
% Q = nip_lcmv(y,L);
% Q = nip_energy(Q);
% Q = Q - min(Q);
% idx = find(Q >= 0.1*max(Q));
% idx = (idx-1)*3;
% idx = repmat(idx,[1,3])';
% off = repmat([1 2 3],[1,length(idx)]);
% idx = idx(:)'+off;
% fprintf('Solving using %d elements\n',length(idx));
idx = 1:1:Ndor;
L_or = L;

L = L(:,idx);
[Nc Nd] = size(L);
Nt = size(y,2);

p = inputParser;

def_a = 10;
def_m = 100;
def_sreg = 80;
def_treg= 1;
def_maxiter = 10;
def_tol = 2e-2;
def_gof = 0.3;
def_lipschitz = [];
def_optimgof = false;

addParamValue(p,'a',def_a);
addParamValue(p,'m',def_m);
addParamValue(p,'sreg',def_sreg);
addParamValue(p,'treg',def_treg);
addParamValue(p,'maxiter',def_maxiter);
addParamValue(p,'tol',def_tol);
addParamValue(p,'gof',def_gof);
addParamValue(p,'lipschitz',def_lipschitz);
addParamValue(p,'optimgof',def_optimgof);

parse(p,varargin{:})
options = p.Results;


tol = options.tol;
sreg = options.sreg;
treg = options.treg;
a = options.a;
M = options.m;
lipschitz_k = options.lipschitz;




% Initialization of the TF-MxNE algorithm
c = dgtreal(y','gauss',a,M);
T = size(c,2);
K = size(c,1);
Z = sparse(0,K*T);
Y = sparse(Nd,K*T);
J_rec = sparse(Nd,Nt);


% Calculate scale leadfield matrix to use normalized reg parameters
tau = 1;
tempGY = L'*y;
aux = sum(reshape(tempGY.^2',[],Nd/3)',2);
basepar = 0.01*sqrt(max(aux(:)));

L = L/basepar;
L_or = L_or/basepar;

% mu = basepar*sreg; % Spatial regularization parameterlambda = basepar*treg; % Time regularization parameter
clear tempGY;

R = y;

active_set = logical(sparse(1,Nd));
Y_time_as = [];
Y_as = [];

if isempty(options.lipschitz)
    lipschitz_k = 0.9*lipschitz_contant(y, L, 5e-2, a, M);
    %     lipschitz_k = 1.1*5e5;
end
mu_lc = sreg/lipschitz_k;
lambda_lc = treg/lipschitz_k;
stop =false;
fprintf('Running TF-MxNE algorithm... \n');

eta = 0;

rescum = [];

temp =  reshape(full(Z)',K,T,[]);
error = inf;
gof_0 = inf;
nn = 1;
while true
    rev_line = '';
    %     Z = sparse(0,K*T);
    Y = sparse(Nd,K*T);
    J_rec = sparse(Nd,Nt);
    tau = 1;
    temp =  reshape(full(Z)',K,T,[]);
    %     active_set = logical(sparse(1,Nd));
    Y_time_as = [];
    Y_as = [];
    for i = 1:100
        tic;        
        
        Z_0 = Z;   active_set0 = active_set;
        
        % The next section is supposed to be a shortcut// However it has a bug that
        % I haven't found... yet.
        % Don't Worry though, the code works well without it, it just takes a little
        % longer.
        %         if (sum(full(active_set))/3 < size(R,1)) && ~isempty(Y_time_as)
        %             GTR = L'*R./lipschitz_k;
        %             A = GTR;
        %             A(find(Y_as),:) = A(find(Y_as),:) + Y_time_as(find(Y_as),1:Nt);
        %             [~, active_set_l21] = prox_l21(A,mu_lc,3);
        %             idx_actsetl21 = find(active_set_l21);
        %
        %             aux = dgtreal(GTR(idx_actsetl21,:)','gauss',a,M);
        %             aux = permute(aux,[3 1 2]);
        %             aux = reshape(aux,sum(active_set_l21),[]);
        %
        %             B = Y(idx_actsetl21,:) + aux;
        %             [Z, active_set_l1] = prox_l1(B,lambda_lc,3);
        %             active_set_l21(idx_actsetl21) = active_set_l1;
        %             active_set_l1 = active_set_l21;
        %         else
        temp = dgtreal(R','gauss',a,M);
        temp = permute(temp,[3 1 2]);
        temp = reshape(temp,Nc,[]);
        Y = Y + L'*temp/lipschitz_k;
        [Z, active_set_l1] = prox_l1(Y,lambda_lc,3);
        %         end
        [Z, active_set_l21] = prox_l21(Z,mu_lc,3);
        active_set = active_set_l1;
        active_set(find(active_set_l1)) = active_set_l21;
        
        error_0 = error;
        if norm(active_set - active_set0) == 0
            error = norm(Z-Z_0)/norm(Z_0);
        else
            error = inf;
        end
%         stop = max(abs(Z-Z_0)./abs(Z_0)) < tol;
        stop = error < tol || error_0 < error || ...
            (sum(full(active_set))==0 && i > 1) || ((sum(full(active_set)) > sum(full(active_set0))) && i > 1) ;
        
        msg = sprintf('Iteration # %d, Stop: %d, Elapsed time: %f \nCoeff~=0: %d \nRegPar S:%d T:%d \n'...
            ,i,error,eta,sum(full(active_set))/3, mu_lc, lambda_lc);
        fprintf([rev_line, msg]);
        rev_line = repmat(sprintf('\b'),1,length(msg));
        if i < options.maxiter
            
            
            
            
            % line 7 of algorithm 1 (see Ref paper)
            tau_0 = tau;
            
            % line 8 of algorithm 1 (see Ref paper)
            tau = 0.5+sqrt(1+4*tau_0^2)/2;
            
            Y = sparse(Nd,K*T);
            dt = (tau_0-1)/tau;
            Y(find(active_set),:) = (1 + dt)*Z;
            Y(find(active_set0),:)= Y(find(active_set0),:) - dt*Z_0;
            
            
            Y_as = active_set0|active_set;
            
            temp =  reshape(full(Y)',K,T,[]);
            temp = flipdim(temp,2);
            Y_old = Y_time_as;
            Y_time_as = flipud(idgtreal(temp,'gauss',a,M))';
            
            % Residual
            R = y - L(:, find(Y_as))*Y_time_as(find(Y_as),1:Nt);
        end
        
        if stop
            disp('Converged')
            break
        end
        eta = toc;
    end
    
    fprintf(' \nDone!... \nTransforming solution to the time domain: \n%d non-zero time series \n'...
        , sum(active_set))
    
    temp =  reshape(full(Z)',K,T,[]);
    temp = flipdim(temp,2);
    
    J_recf = sparse(Nd,size(Y_time_as,2));
    J_recf(find(active_set),:) = flipud(idgtreal(temp,'gauss',a,M))';
    J_recf = J_recf(:,1:Nt);
    Jf = zeros(Ndor,Nt);
    Jf(idx,:) = J_recf;
    
    resnorm = norm(y-L_or*Jf, 'fro')/norm(y, 'fro');
%     rescum = [rescum,resnorm];
%     plot(rescum);
%     pause(0.1)
    fprintf('\nGOF = %8.5e\n', resnorm);
    
    if gof_0 < resnorm;
        J_rec = Jf_0;
    else
        Jf_0 = Jf;
        J_rec = Jf;
    end
    if nn >= options.maxiter || resnorm < options.gof...
            || ~options.optimgof || gof_0 < resnorm
%     if nn >= options.maxiter || resnorm < options.gof...
%             || ~options.optimgof
        break;
    else
        mu_lc = 0.75*mu_lc;
        lambda_lc = 0.75*lambda_lc;
    end
    gof_0 = resnorm;
    nn = nn+1;
end

extras = [];
end

function sm =  safe_max_abs(A, ia)
if isempty(ia)
    sm = 0;
else
    sm = max(max(abs(A(ia))));
end
end

function sm = safe_max_abs_diff(A,ia,B,ib)
if isempty(ia)
    A = 0;
else
    A = A(ia);
end
if isempty(ia)
    B = 0;
else
    B = B(ib);
end
if isempty(A)&&isempty(B)
    sm = 0;
else
    sm = max(max(abs(A-B)));
end
end


function [Y active_set] = prox_l21(Y,mu,n_orient)
n_pos = size(Y,1)/n_orient;

rows_norm = sqrt(sum(reshape(abs(Y).^2',[],n_pos)',2));
shrink = max(1 - mu./max(rows_norm,mu),0);
active_set = (shrink > 0);
shrink = shrink(active_set);
if n_orient>1
    active_set = repmat(active_set,1,n_orient);
    active_set = reshape(active_set',n_orient,[]);
    active_set = active_set(:)';
end
temp = reshape(repmat(shrink,1,n_orient),length(shrink),n_orient)';
temp = temp(:);
Y = Y(find(active_set),:).*repmat(temp,1,size(Y,2));
end


function [Y active_set] = prox_l1(Y,lambda,n_orient)
n_pos = size(Y,1)/n_orient;
norms = sqrt(sum(reshape((abs(Y).^2),n_orient,[]),1));
shrink = max(1-lambda./max(norms,lambda),0);
shrink = reshape(shrink',n_pos,[]);
active_set = logical(sum(shrink,2));
shrink = shrink(find(active_set),:);

if n_orient>1
    active_set = repmat(active_set,1,n_orient);
    active_set = reshape(active_set',n_orient,[]);
    active_set = active_set(:)';
end

Y = Y(active_set,:);
if length(Y) > 0
    for i = 1:n_orient
        Y(i:n_orient:size(Y,1),:) = Y(i:n_orient:size(Y,1),:).*shrink;
    end
end
end

% function a = norm_l21(Z)
%
%     if isempty
% end
% function a = norm_l1(Z)
%
% end

function k = lipschitz_contant(y, L, tol, a, M)
Nt = size(y,2);
Nd = size(L,2);
iv = ones(Nd,Nt);
v = dgtreal(iv', 'gauss', a,M);
T = size(v,2);
K = size(v,1);

l = 5e5;
l_old = 0;
fprintf('Lipschitz constant estimation: \n')
rev_line = '';
tic
for i = 1 : 100
    msg = sprintf('Iteration = %d, Diff: %d, Lipschitz Constant: %d\nTime per iteration %d ',i,abs(l-l_old)/l_old,l,toc);
    tic
    fprintf([rev_line, msg]);
    rev_line = repmat(sprintf('\b'),1,length(msg));
    l_old = l;
    aux = idgtreal(v,'gauss',a,M)';
    iv = real(aux);
    Lv = L*iv;
    LtLv = L'*Lv;
    w = dgtreal(LtLv', 'gauss', a,M);
    l = max(max(max(abs(w))));
    v = w/l;
    if abs(l-l_old)/l_old < tol
        break
    end
end
fprintf('\n');
k = l;
toc
end
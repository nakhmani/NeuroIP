% Script to generate dataset in the cluster and then rename it and copy it
% in to another directory.

%%%%%%%%%%%%%%%%%%%%%%%%%
% Juan S. Castano C.    %
% jscastanoc@gmail.com  %
% 19 Aug 2013           %
%%%%%%%%%%%%%%%%%%%%%%%%%


% Initialization and creation of the structures used in some functions
close all; clc; clear

addpath('../../external/source_toolbox/haufe/')
addpath('../../external/source_toolbox/nolte/')
addpath('../../external/source_toolbox/simulations/')
rng('default')
rng('shuffle');

warning off

load clab_example;
load clab_10_10;
clab = clab_10_10;
% data_name = 'icbm152b_sym';
data_name = 'montreal';

sa = prepare_sourceanalysis(clab, data_name);

temp = sa.V_cortex_coarse;
L = nip_translf(temp); % Leadfield matrix
L = L(find(ismember(clab_example,clab)),:);
clear temp

cfg.cortex = sa.cortex_coarse;
cfg.L = L;
cfg.fs = 100; % Sample frequency (Hz)
cfg.t = 0:1/cfg.fs:1.5; % Time vector (seconds)
model = nip_create_model(cfg);
clear L sa;


Ntrials = [5 20 50 100 250];
act_sources = [1 3 5];
% Ntrials = [210];
snr_meas = 0;
snr_bio = -5;
% snr_bio = [5]
snr = [];
% t = model.t;
% L = model.L;
% fs = model.fs
% cortex = model.cortex;
% clear model;

n_exp = 50;


jobs_c = 1;
methods = {'LOR','TF-MxNE','S+T','S-FLEX'};
for c_meth = 1:numel(methods)
    for j = 1:n_exp
        cur_jobs = [];
        copy_res = {};
        for l = 1:act_sources
            for i = Ntrials
                %                 [y, Jclean, actidx] = nip_simtrials(L, cortex.vc, ...
                %                     source_act, t, Nspurious , i, snr_meas, snr_bio(k));
                dir = strcat('/home/jscastanoc/sim_trials_final/',num2str(Nf),'/');
                file_name = strcat(dir,'Exp',num2str(j),'Ntrials',...
                    num2str(i),'BioNoise',num2str(snr_bio),'.mat');
                load(file_name);
                model.y = mgjob.results{1};
                jobs(jobs_c) =  mgsub({'J_rec', 'time'},'core_matgrid_test', ...
                    {model , methods{c_meth}});
                cur_jobs = [cur_jobs jobs(jobs_c)];
                jobs_c = jobs_c + 1;
                dir = strcat('/home/jscastanoc/Results_final/',num2str(act_sources(l)));
                file_name = strcat(dir,'/Exp',num2str(j),'Ntrials',...
                    num2str(i),'BioNoise',num2str(snr_bio),'.mat');
                %                 copy_res{jobs_c} = {file_name,jobs(jobs_c)}
                copy_res{end+1} = file_name;
                %                 y_clean = L*Jclean;
                %                 noise = y-y_clean;
                %                 %             y = model.y;
                %                 snr = [snr 20*log10(norm(y_clean)/norm(noise))];
            end
        end
        mgwait(cur_jobs);
        
        % Copy results
        aux = 1;
        for cc_res = cur_jobs
            or = strcat('/home/jscastanoc/svn_test/matgrid/jobs/',num2str(cc_res),'/mgjob_results.mat');
            dest = copy_res{aux};
            try
                movefile(or,dest);
            catch
                err_var = true;
                save(file_name,'err_var');
            end
            aux = aux+1;
        end
        mgclear(cur_jobs);
    end
end
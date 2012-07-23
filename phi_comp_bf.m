function [phi_MIP prob prob_prod_MIP MIP] = phi_comp_bf(options,M,x0,xp,xf,x0_s,p)
% compute small phi of a given purview...?
% 
% options = the options
% M = a system
% x0 = state of the system??
% xp = 
% xf = 
% x0_s = 
% p = TPM as a 2^N x N matrix
% b_table
% BRs
% FRs


% op_fb = options(1);
% op_phi = options(2);
% op_disp = options(3);
% op_single = options(4);
% op_ex = options(5);
op_context = options(6);
op_whole = options(7);
op_min = options(9);
op_normalize = options(14);
op_small_phi = options(16);

global BRs, global FRs, global b_table

Np = length(xp);
N0 = length(x0);
Nf = length(xf);

%% unpartitioned transition repertoire
if op_context == 0 % conservative
    
    current = convi(x0); past = convi(xp); future = convi(xf);
    
    if isempty(BRs{current,past})
        BRs{current,past} = comp_pers_single(current,past,x0_s,p,1);    
    end
    prob_bw = BRs{current,past};

    if isempty(FRs{current,future})
        FRs{current,future} = comp_pers_single(current,future,x0_s,p,2);
    end
    prob_fw = FRs{current,future};
    

    prob = cell(2,1);
    prob{1} = prob_bw;
    prob{2} = prob_fw;
else % progressive
    prob = partial_prob_comp_bf(M,x0,xp,xf,x0_s,p,b_table,op_whole,op_context);
end

%% more than one
if Np ~= 0
    [xp_b1 xp_b2 Np_b] = bipartition(xp,Np); % partition of xp
else
    xp_b1{1} = []; xp_b2{1} = []; Np_b = 1;
end
if Nf ~= 0
    [xf_b1 xf_b2 Nf_b] = bipartition(xf,Nf); % partition of xf
else
    xf_b1{1} = []; xf_b2{1} = []; Nf_b = 1;
end
[x0_b1 x0_b2 N0_b] = bipartition(x0,N0,1); % partition of x0

% THIS OPTION IS NOT SETUP FOR THE GUI
if op_min == 0 % PHI IS SUM OF BACKWARD AND FORWARD
    
    phi_cand = zeros(Np_b,N0_b,Nf_b,2); % THE LAST DIMENSION IS PHI, PHI_NORM
    prob_prod_vec = cell(Np_b,N0_b,Nf_b);
    
    for i=1: Np_b % past
        xp_1 = xp_b1{i};
        xp_2 = xp_b2{i};
        for j=1: N0_b % present
            x0_1 = x0_b1{j};
            x0_2 = x0_b2{j};
            for k=1: Nf_b % future
                xf_1 = xf_b1{k};
                xf_2 = xf_b2{k};
                Norm = Normalization(xp_1,xp_2,x0_1,x0_2,xf_1,xf_2);
                
                if Norm ~= 0
                    if op_context == 0
                        prob_bp1 = BRs{convi(x0_1),convi(xp_1)};
                        prob_bp2 = BRs{convi(x0_2),convi(xp_2)};
                        prob_fp1 = FRs{convi(x0_1),convi(xf_1)};
                        prob_fp2 = FRs{convi(x0_2),convi(xf_2)};
                        prob_bp = prob_prod_comp(prob_bp1,prob_bp2,xp,xp_1,0);
                        prob_fp = prob_prod_comp(prob_fp1,prob_fp2,xf,xf_1,0);
                        
                        if op_small_phi == 0
                            phi = KLD(prob_bw,prob_bp) + KLD(prob_fw,prob_fp);
                        elseif op_small_phi == 1
                            phi = emd_hat_gd_metric_mex(prob_bw,prob_bp,gen_dist_matrix(length(prob_bw))) +...
                                emd_hat_gd_metric_mex(prob_fw,prob_fp,gen_dist_matrix(length(prob_fp)));
                        elseif op_small_phi == 2
                            phi = k_distance(prob_bw,prob_bp) + k_distance(prob_fw,prob_fp);
                        end
                        
                        prob_prod = cell(2,1);
                        prob_prod{1} = prob_bp;
                        prob_prod{2} = prob_fp;
                        prob_prod_vec{i,j,k} = prob_prod;
                    else
                        prob_prod = partial_prob_comp_bfp(M,xp_1,xp_2,x0_1,x0_2,xf_1,xf_2,x0_s,p,b_table,op_whole,op_context);
                        
                        if(op_small_phi == 0)
                            phi = KLD(prob(:),prob_prod(:));
                        elseif (op_small_phi == 1)
                            phi = emd_hat_gd_metric_mex(prob(:),prob_prod(:),gen_dist_matrix(length(prob(:))));
                        elseif op_small_phi == 2
                            phi = k_distance(prob(:),prob_prod(:));
                        end
                        
                        prob_prod_vec{i,j,k} = prob_prod;
                    end
                else
                    prob_prod_vec{i,j,k} = [];
                    phi = Inf;
                end
                
                phi_cand(i,j,k,1) = phi;
                phi_cand(i,j,k,2) = phi_cand(i,j,k,1)/Norm;
                
                % fprintf('phi=%f phi_norm=%f %s-%s -%s\n',phi,phi/Norm,mod_mat2str(xp_1),mod_mat2str(x0_1),mod_mat2str(xf_1));
            end
        end
    end
    
    [min_norm_phi i j k] = min3(phi_cand(:,:,:,2),phi_cand(:,:,:,1),op_normalize);
    phi_MIP = phi_cand(i,j,k,1);
    prob_prod_MIP = prob_prod_vec{i,j,k};
    
    MIP = cell(2,3);
    MIP{1,1} = xp_b1{i};
    MIP{2,1} = xp_b2{i};
    MIP{1,2} = x0_b1{j};
    MIP{2,2} = x0_b2{j};
    MIP{1,3} = xf_b1{k};
    MIP{2,3} = xf_b2{k};


else % OP_MIN = 1, PHI IS MINIMUM OF BACKWARDS AND FORWARDS COMPUTATIONS
    
    phi_cand = zeros(Np_b,N0_b,2,2);
    prob_prod_vec = cell(Np_b,N0_b,2);
    
    for i=1: Np_b % past or future
        xp_1 = xp_b1{i};
        xp_2 = xp_b2{i};
        
        for j=1: N0_b % present
            x0_1 = x0_b1{j};
            x0_2 = x0_b2{j};
            Norm = Normalization(xp_1,xp_2,x0_1,x0_2);
            
            current_1 = convi(x0_1);
            current_2 = convi(x0_2);
            other_1 = convi(xp_1);
            other_2 = convi(xp_2);
            
            for bf=1: 2 % past or future
                
                if Norm ~= 0
                    
                    if bf == 1
                        if isempty(BRs{current_1,other_1})
                            BRs{current_1,other_1} = comp_pers_single(current_1,other_1,x0_s,p,bf);
                        end
                        prob_p1 = BRs{current_1,other_1};
                        
                        if isempty(BRs{current_2,other_2})
                            BRs{current_2,other_2} = comp_pers_single(current_2,other_2,x0_s,p,bf);
                        end
                        prob_p2 = BRs{current_2,other_2};
                        
                    else
                        
                        if isempty(FRs{current_1,other_1})
                            FRs{current_1,other_1} = comp_pers_single(current_1,other_1,x0_s,p,bf);
                        end
                        prob_p1 = FRs{current_1,other_1};
                        
                        if isempty(FRs{current_2,other_2})
                            FRs{current_2,other_2} = comp_pers_single(current_2,other_2,x0_s,p,bf);
                        end
                        prob_p2 = FRs{current_2,other_2};

                    end
                    
                    prob_p = prob_prod_comp(prob_p1,prob_p2,xp,xp_1,0);
                    
                    if (op_small_phi == 0)
                        phi = KLD(prob{bf},prob_p);
                    elseif (op_small_phi == 1)
                        phi = emd_hat_gd_metric_mex(prob{bf},prob_p,gen_dist_matrix(length(prob_p)));
                    elseif op_small_phi == 2
                        phi = k_distance(prob{bf},prob_p);
                    end
                    prob_prod_vec{i,j,bf} = prob_p;
                else
                    prob_prod_vec{i,j,bf} = [];
                    phi = Inf;
                end
                
                phi_cand(i,j,bf,1) = phi;
                phi_cand(i,j,bf,2) = phi/Norm;
            end
        end
    end
    
    MIP = cell(2,2,2);
    phi_MIP = zeros(1,2);
    prob_prod_MIP = cell(2,1);
    for bf = 1: 2
        [phi_MIP(bf) i j] = min2(phi_cand(:,:,bf,1),phi_cand(:,:,bf,2),op_normalize);
        prob_prod_MIP{bf} = prob_prod_vec{i,j,bf};
        
        MIP{1,1,bf} = xp_b1{i};
        MIP{2,1,bf} = xp_b2{i};
        MIP{1,2,bf} = x0_b1{j};
        MIP{2,2,bf} = x0_b2{j};
    end
    
end

end

function Norm = Normalization(xp_1,xp_2,x0_1,x0_2,xf_1,xf_2)

if nargin == 4
    Norm = min(length(x0_1),length(xp_2)) + min(length(x0_2),length(xp_1));
else
    Norm = min(length(x0_1),length(xp_2)) + min(length(x0_2),length(xp_1)) ...
        + min(length(x0_1),length(xf_2)) + min(length(x0_2),length(xf_1));
end

end

function [X_min i_min j_min k_min] = min3(X,X2,op_normalize)
X_min = Inf; % minimum of normalized phi (or unnormalized if op_normalize == 0)
X_min2 = Inf; % minimum of phi
i_min = 1;
j_min = 1;
k_min = 1;

if (op_normalize == 1)
    for i=1: size(X,1)
        for j=1: size(X,2)
            for k=1: size(X,3)
                if X(i,j,k) <= X_min && X2(i,j,k) <= X_min2
                    X_min = X(i,j,k);
                    X_min2 = X2(i,j,k);
                    i_min = i;
                    j_min = j;
                    k_min = k;
                end            
            end
        end
    end
else
    for i=1: size(X,1)
        for j=1: size(X,2)
            for k=1: size(X,3)
                if X2(i,j,k) <= X_min
    %                 X_min = X(i,j,k);
                    X_min = X2(i,j,k);
                    i_min = i;
                    j_min = j;
                    k_min = k;
                end            
            end
        end
    end
end
end


function [phi_min_choice i_min j_min] = min2(phi,phi_norm,op_normalize)
phi_norm_min = Inf; % minimum of normalized phi
phi_min = Inf; % minimum of phi
i_min = 1;
j_min = 1;

if (op_normalize == 1 || op_normalize == 2)
    for i=1: size(phi,1)
        for j=1: size(phi,2)
%             if phi_norm(i,j) <= phi_norm_min && phi(i,j) <= phi_min
            if phi_norm(i,j) <= phi_norm_min
                phi_min = phi(i,j);
                phi_norm_min = phi_norm(i,j);
                i_min = i;
                j_min = j;
            end
        end
    end
else
    for i=1: size(phi,1)
        for j=1: size(phi,2)
            if phi(i,j) <= phi_min
                phi_min = phi(i,j);
                phi_norm_min = phi_norm(i,j);
                i_min = i;
                j_min = j;
            end
        end
    end
end

if (op_normalize == 0 || op_normalize == 1)
    phi_min_choice = phi_min;
else
    phi_min_choice = phi_norm_min;
end

end

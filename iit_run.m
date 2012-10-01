function iit_run(tpm, in_connect_mat, current_state, in_noise, in_options, in_nodes)
% IIT_RUN Computes concepts, small and big phi, and partition information
% for all subsets of a system (exluding the empty set) over a binary network.
%
%   IIT_RUN(TPM, connect_mat, CURRENT_STATE, NOISE, OPTIONS) takes a TPM in
%   state X node form, that is TPM(i,j) is the probability node_i = 1 at 
%   time t+1 given that the system is in state j at time t. connect_mat is the
%   connectivity matrix of the network such that connect_mat(i,j) = 1 when j has a
%   directed edge to i, and connect_mat(i,j) = 0 otherwise. current_state is the
%   state of the system at time t (only used if the options are not set to
%   compute over all states). NOISE is a global noise put on all
%   outgoing messages and must take a value on the interval [0,.5]. OPTIONS
%   is a structure of options for the algoirthm created using the
%   set_options function
%
%   see also set_options

%% parallel computing

% if a pool is open, close it
if matlabpool('size')
    matlabpool close force;
end

% if parallel option is on, open a new pool
op_parallel = in_options(19);

if op_parallel
    matlabpool;
end


%% begin timer and disp notification
tic

fprintf('\nRunning...\n\n')

%% initialize data

% get num_nodes, the number of nodes in the whole system
% note that in_nodes is the number of nodes in the GRAPH = 2*num_nodes
num_nodes = length(in_nodes)/2;

network.connect_mat = in_connect_mat;
network.options = in_options;
network.nodes = in_nodes;
network.num_nodes = num_nodes;
network.tpm = tpm;
network.full_system = 1:num_nodes;
network.num_subsets = 2^num_nodes;
network.current_state = current_state;
network.num_states = prod([network.nodes(network.full_system).num_states]);

% output_data.tpm = tpm;
% output_data.current_state = current_state;
network.noise = in_noise;
% output_data.num_nodes = num_nodes;

% binary table and states list
% need to rethink use of b_table when allowing for more than binary nodes
network.b_table = cell(network.num_subsets,network.num_nodes);
for i = network.full_system
    for j = 1:2^i
        network.b_table{j,i} = trans2(j-1,i);
    end
end

network.states = zeros(network.num_nodes,network.num_states);
for i = 0:network.num_states - 1
    network.states(:,i+1) = dec2multibase(i,[network.nodes(network.full_system).num_states]);
end


%% setup main function call

% determine if we are averaging over all states or just one
op_average = network.options(18);
if op_average == 0
    state_max = 1;
%     network.states(:,1) = current_state;
else
    state_max = network.num_states;
end

% we should deal with different arguments not being included
% if nargin == 4 
%     connect_mat = ones(num_nodes);
% elseif nargin == 5
%     connect_mat = in_connect_mat;
% end

% find main complex (do system partitions)
op_complex = network.options(15);

% init cell arrays for results
output_data.results(state_max).Big_phi = zeros(network.num_subsets,1); % scalar value per subset per state
output_data.results(state_max).Big_phi_MIP = zeros(network.num_subsets,1); % scalar value per subset per state 
MIP_st = cell(state_max,1);
Complex_st = cell(state_max,1);
prob_M_st = cell(state_max,1);
phi_M_st = cell(state_max,1);
concept_MIP_M_st = cell(state_max,1);
complex_MIP_M_st = cell(state_max,1);
Big_phi_MIP_all_M_st = cell(state_max,1);
complex_MIP_all_M_st = cell(state_max,1);
purviews_M_st = cell(state_max,1);




%% main loop over states

% for each state
for z = 1:state_max
    
    
    if op_average
        this_state = network.states(:,z);
    else
        this_state = current_state;
    end
    
    % init backward rep and forward reps for each state
    network.BRs = cell(network.num_subsets); % backward repertoire
    network.FRs = cell(network.num_subsets); % forward repertoire
        
    fprintf(['State: ' num2str(this_state') '\n'])
   
    % is it possible to reach this state
    check_prob = partial_prob_comp(network.full_system,network.full_system,this_state,tpm,network.b_table,1); % last argument is op_fb = 1;
    state_reachable = sum(check_prob);
    
    if ~state_reachable
        
        fprintf('\tThis state cannot be realized...\n')
        
        Big_phi_M_st{z} = NaN;
        Big_phi_MIP_st{z} = NaN;
        
        % SET OTHERS
        
    else
        
        fprintf('\tComputing state...\n')
        
        % only consider whole system
        % THIS OPTION NEEDS TO BE WORKED OUT!
        if op_complex == 0 

%             [BRs FRs] = comp_pers(this_state,tpm,b_table,options);
%             (network.full_system,this_state,tpm,network.b_table,network.options)
            [Big_phi phi prob_cell MIPs M_IRR network] = big_phi_comp_fb(network.full_system,this_state,network);
            % irreducible points
%             [IRR_REP IRR_phi IRR_MIP M_IRR] = IRR_points(prob_cell,phi,MIPs,M, 0,op_fb);
%             plot_REP(Big_phi, IRR_REP,IRR_phi,IRR_MIP, 1, M, options)


            Big_phi_M_st{z} = Big_phi;
            
            % TODO: WE NEED TO HANDLE MIP IN THIS CASE EVEN WE DON'T FIND
            % THE COMPLEX

        % find the complex
        elseif op_complex == 1
            
            
            [Phi phi_M prob_M M_cell concept_MIP_M purviews_M] = big_phi_all(network, this_state);
                                                                
            % complex search
            [Big_phi_MIP MIP complex_set M_i_max  Phi_MIP complex_MIP_M Big_phi_MIP_all_M complex_MIP_M_all] = ...
                complex_search(Big_phi_M,M_cell, purviews_M, network.num_nodes,prob_M,phi_M,network.options);
            
%             Big_phi_M_st{z}.Phi = Big_phi_M;
            output_data.results(z).Phi = Phi; 
            
%             Big_phi_MIP_st{z} = Phi_MIP;
            output_data.results(z).Phi_MIP = Phi_MIP;
            
            % it looks like MIP is never  used
%             MIP_st{z} = MIP;
            
%             Complex_st{z} = complex_set;
            output_data.results(z).complex_set = complex_set;
            
            prob_M_st{z} = prob_M;
            output_data.results(z).concepts
            
            phi_M_st{z} = phi_M;
            concept_MIP_M_st{z} = concept_MIP_M;
            complex_MIP_M_st{z} = complex_MIP_M;
            Big_phi_MIP_all_M_st{z} = Big_phi_MIP_all_M;
            complex_MIP_all_M_st{z} = complex_MIP_M_all;
            purviews_M_st{z} = purviews_M;
                

        end
    end

end

%% store output data

output_data.network = network;



output_data.Big_phi_M = Big_phi_M_st;
output_data.Big_phi_MIP = Big_phi_MIP_st;
% KILL THIS ONE BELOW
output_data.MIP = MIP_st;
output_data.Complex = Complex_st;
output_data.concepts_M = prob_M_st;
output_data.small_phi_M = phi_M_st;
output_data.concept_MIP_M = concept_MIP_M_st;
output_data.complex_MIP_M = complex_MIP_M_st;
output_data.M_cell = M_cell;
output_data.Big_phi_MIP_all_M = Big_phi_MIP_all_M_st;
output_data.complex_MIP_all_M = complex_MIP_all_M_st;
output_data.purviews_M = purviews_M_st;


%% finish & cleanup: stop timer, save data, open explorer gui, close matlabpool
toc

fprintf('Loading GUI... \n');

save('last_run_output.mat','output_data','-v7.3');

iit_explorer(output_data)

if op_parallel
    matlabpool close force;
end



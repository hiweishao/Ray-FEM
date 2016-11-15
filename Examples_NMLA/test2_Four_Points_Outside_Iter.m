%% %% Four Point Sources Problem Iterative Idea: outside domain (-2,-2),(2,2),(-2,2),(2,-2) 
%  uexact = sqrt(k)*besselh(0,1,k*sqrt((x+2)^2 + (y+2)^2))
%         + sqrt(k)*2*besselh(0,1,k*sqrt((x-2)^2 + (y-2)^2))
%         + sqrt(k)*0.5*besselh(0,1,k*sqrt((x+2)^2 + (y-2)^2))
%         - sqrt(k)*besselh(0,1,k*sqrt((x-2)^2 + (y+2)^2))
clear;
fileID = fopen('result2_iter.txt','a');


%% Load source data
pde = Helmholtz_data_2;
fprintf(fileID,'\n\nFour point sources problem: \n\n  (-2,-2),(2,2),(-2,2),(2,-2) \n\n');


%% Set up
plt = 0;                   % show solution or not
fquadorder = 9;            % numerical quadrature order
solver = 'DIR';            % linear system solver
pct = 1/8;
Nray = 4;
sec_opt = 0;               % NMLA second order correction or not


rec_N = 12;                 % we test rec_N examples

% record h and omega
rec_omega = zeros(1,rec_N);
rec_h = rec_omega;

% record the error and condition number of Standard FEM
rec_S_err = rec_omega;
rec_S_cond = rec_omega;

% record the L2 error of the numerical angle estimation
rec_ang_err1 = rec_omega;   
rec_ang_err2 = rec_omega;  

% record the error and condition number of Numerical Ray-based FEM
rec_NR_err1 = rec_omega;
rec_NR_err2 = rec_omega;
rec_NR_cond1 = rec_omega;
rec_NR_cond2 = rec_omega;


% record the error and condition number of Exact Ray-based FEM
rec_ER_err = rec_omega;
rec_ER_cond = rec_omega;

% record the error and condition number of Phase-based FEM
rec_P_err = rec_omega;
rec_P_best_err = rec_omega;
rec_P_cond = rec_omega;


global omega;
global a;
% rec_lg_a = [2.5 2.1 2 2];
lg_a = 2.5;
sm_a = 1/2;
high_omega = 0*pi;
NPW = 6;



for rec_i = 1: rec_N
    high_omega = high_omega + 10*pi;
    low_omega = sqrt(high_omega);
    h = 1/round((NPW*high_omega)/(2*pi));
    ch = 1/5*max(round((low_omega)/(2*pi)),1);
    if (high_omega >= 20*pi) && (high_omega < 40*pi)
        lg_a = 2.1;
        ch = 1/10*max(round((low_omega)/(2*pi)),1);
    elseif high_omega >= 40*pi
        lg_a = 2;
        ch = 1/10*max(round((low_omega)/(2*pi)),1);
    end
%     lg_a = rec_lg_a(rec_i);
    
    
    


    fprintf(['-'*ones(1,80) '\n']);
    fprintf(['-'*ones(1,80) '\n']);
    fprintf('\ncase %d: \nomega/(2*pi) = %d,  1/h = %d,  1/ch = %d \n\n', rec_i, high_omega/(2*pi), 1/h, 1/ch);
    rec_omega(rec_i) = high_omega;
    rec_h(rec_i) = h;


%% Step 1: Solve the Hemholtz equation with wavenumber sqrt(k) by Standard FEM? mesh size h = 1/k
fprintf(['\n' '-'*ones(1,80) '\n']);
fprintf('Numerical Ray-based FEM: \n\n');
fprintf('Step1: low frequency S-FEM \n');

omega = low_omega;
a = lg_a;
tic;
[node,elem] = squaremesh([-a,a,-a,a],h);
[u_std,~,~,err] = Standard_FEM_IBC(node,elem,omega,pde,fquadorder,solver,plt);
toc;

%% Step 2: Use NMLA to find ray directions d_c with wavenumber sqrt(k)
fprintf(['\n' '-'*ones(1,80) '\n']);
fprintf('\nStep2: NMLA for low frequency \n');

tic;
N = size(node,1);
n = round(sqrt(N));
ln = n;

uu = reshape(u_std,n,n);
uux = uu;   uuy = uu;   % numerical Du

uux(:,2:n-1) = (uu(:,3:n) - uu(:,1:n-2))/(2*h);
uux(:,n) = 2*uux(:,n-1) - uux(:,n-2);
uux(:,1) = 2*uux(:,2) - uux(:,3);
ux = uux(:);


uuy(2:n-1,:) = (uu(3:n,:) - uu(1:n-2,:))/(2*h);
uuy(n,:) = 2*uuy(n-1,:) - uuy(n-2,:);
uuy(1,:) = 2*uuy(2,:) - uuy(3,:);
uy = uuy(:);


% NMLA
Rest = 100 + omega/2;
lnode = node;  % large domain nodes and elements
lelem = elem;

a = sm_a;
[node,elem] = squaremesh([-a,a,-a,a],h);
N = size(node,1);
n = round(sqrt(N));

% ch = 1/round((NPW*low_omega)/(2*pi));
[cnode,celem] = squaremesh([-a,a,-a,a],ch);
cN = size(cnode,1);

cnumray = zeros(cN,Nray);


if (1)
    for i = 1:cN
        x0 = cnode(i,1);  y0 = cnode(i,2);
        c0 = pde.speed(cnode(i,:));
        [cnumray(i,:)] = NMLA_2D(x0,y0,c0,omega,Rest,lnode,lelem,u_std,ux,uy,pde,pct,Nray,'num',plt);
    end
    numray = interpolation(cnode,celem,node,cnumray);
end

if (0)
    numray = zeros(N,Nray);
    for i = 1:N
        x0 = node(i,1);  y0 = node(i,2);
        c0 = pde.speed(node(i,:));
        [numray(i,:)] = NMLA_2D(x0,y0,c0,omega,Rest,node,elem,0,0,0,pde,pct,Nray,'ex',plt);
    end
end


ray = pde.ray(node);
ray = ray(:);
ray = [real(ray), imag(ray)];
ray_dir = atan2(ray(:,2),ray(:,1));
neg_index = find(ray_dir<0);
ray_dir(neg_index) = ray_dir(neg_index) + 2*pi;

diffang = numray(:) - ray_dir;
rec_ang_err1(rec_i) = h*norm(diffang,2)/(h*norm(ray_dir,2));

numray = exp(1i*numray);
toc;


%% Step 3: Solve the original Helmholtz equation by Ray-based FEM with ray directions d_c
fprintf(['\n' '-'*ones(1,80) '\n']);

fprintf('\nStep3: Ray-FEM 1 \n');
tic;
omega = high_omega;
a = sm_a;
[node,elem] = squaremesh([-a,a,-a,a],h);
[uh,~,~,~,rel_L2_err] = Ray_FEM_IBC_1(node,elem,omega,pde,numray,fquadorder,plt);
rec_NR_err1(rec_i) = rel_L2_err;
% rec_NR_cond1(rec_i) = condest(A);
toc;

%% Step 4: NMLA to find original ray directions d_o with wavenumber k
tic;
fprintf(['\n' '-'*ones(1,80) '\n']);
fprintf('\nStep4: NMLA for high frequency \n');

a = lg_a;
ex_Du = pde.Du(lnode);
ex_u = pde.ex_u(lnode);
ux = ex_Du(:,1);
uy = ex_Du(:,2);
ux = reshape(ux,ln,ln);
uy = reshape(uy,ln,ln);
eu = reshape(ex_u,ln,ln);

uu = reshape(uh,n,n);

uux = uu;   uuy = uu;   % numerical Du
nn = round((ln-n)/2) + 1 : round((ln+n)/2); 
eu(nn,nn) = uu;

uux(:,2:n-1) = (uu(:,3:n) - uu(:,1:n-2))/(2*h);
uux(:,n) = 2*uux(:,n-1) - uux(:,n-2);
uux(:,1) = 2*uux(:,2) - uux(:,3);
ux(nn,nn) = uux;

uuy(2:n-1,:) = (uu(3:n,:) - uu(1:n-2,:))/(2*h);
uuy(n,:) = 2*uuy(n-1,:) - uuy(n-2,:);
uuy(1,:) = 2*uuy(2,:) - uuy(3,:);
uy(nn,nn) = uuy;

ux = ux(:);   uy = uy(:);  uh = eu(:);


if (1)
    for i = 1:cN
        x0 = cnode(i,1);  y0 = cnode(i,2);
        c0 = pde.speed(cnode(i,:));
        [cnumray(i,:)] = NMLA_2D(x0,y0,c0,omega,Rest,lnode,lelem,uh,ux,uy,pde,pct,Nray,'num',plt);
    end
    numray = interpolation(cnode,celem,node,cnumray);
end

if (0)
    numray = zeros(N,Nray);
    for i = 1:N
        x0 = node(i,1);  y0 = node(i,2);
        c0 = pde.speed(node(i,:));
        [numray(i,:)] = NMLA_2D(x0,y0,c0,omega,Rest,node,elem,0,0,0,pde,pct,Nray,'ex',plt);
    end
end

diffang = numray(:) - ray_dir;
rec_ang_err2(rec_i) = h*norm(diffang,2)/(h*norm(ray_dir,2));

numray = exp(1i*numray);
toc;

%% Step 5: Solve the original Helmholtz equation by Ray-based FEM with ray directions d_o
fprintf(['\n' '-'*ones(1,80) '\n']);
fprintf('\nStep5: Ray-FEM 2 \n');

tic;
omega = high_omega;
a = sm_a;
[node,elem] = squaremesh([-a,a,-a,a],h);
[uh,~,~,~,rel_L2_err] = Ray_FEM_IBC_1(node,elem,omega,pde,numray,fquadorder,plt);
rec_NR_err2(rec_i) = rel_L2_err;
% rec_NR_cond2(rec_i) = condest(A);
toc;



%% Standard FEM
    if (0)
        fprintf('\nStandard FEM: \n');
        [~,A,~,rel_L2_err] = Standard_FEM_IBC(node,elem,omega,pde,fquadorder,solver,plt);
        rec_S_err(rec_i) = rel_L2_err;
        rec_S_cond(rec_i) = condest(A);
    end
    
    %% Exact Ray-based FEM:
    if (1) 
        fprintf('\nExact Ray-based FEM: \n');
        ray = pde.ray(node);
        [~,A,~,~,rel_L2_err] = Ray_FEM_IBC_1(node,elem,omega,pde,ray,fquadorder,plt);
        rec_ER_err(rec_i) = rel_L2_err;    
        rec_ER_cond(rec_i) = condest(A);
    end
      
    
    %% Phase-based FEM:
    if (0)
        fprintf('\nPhase-based FEM: \n');
        [~,A,~,~,rel_L2_err] = Phase_FEM_IBC(node,elem,omega,pde,fquadorder,plt);
        rec_P_err(rec_i) = rel_L2_err;
        rec_P_cond(rec_i) = condest(A);  
    end


end


%% record and print results
rec = [rec_omega;rec_h;rec_S_err;rec_S_cond;...
    rec_ang_err1;rec_ang_err2;rec_NR_err1;rec_NR_err2;rec_NR_cond1;rec_NR_cond2;...
    rec_ER_cond;rec_ER_err];
save('result2.mat','rec_omega','rec_h','rec_S_err','rec_S_cond','rec_ang_err1',...
    'rec_ang_err2','rec_NR_err1','rec_NR_err2','rec_NR_cond1','rec_NR_cond2',...
    'rec_ER_cond','rec_ER_err');


fprintf( fileID,['\n' '-'*ones(1,80) '\n']);
fprintf( fileID,'omega:                  ');
fprintf( fileID,'&  %1.2e  ',rec_omega );
fprintf( fileID,'\nomega/2pi:              ');
fprintf( fileID,'&  %1.2e  ',rec_omega/(2*pi) );
fprintf( fileID,'\n\nGrid size h:            ');
fprintf( fileID,'&  %1.2e  ',rec_h);
fprintf( fileID,'\n1/h:                    ');
fprintf( fileID,'&  %1.2e  ',1./rec_h);

fprintf( fileID,['\n' '-'*ones(1,80) '\n']);
fprintf( fileID,'\nNumerical Ray-based FEM:\n\n');
fprintf( fileID,'Angle L2 error 1:       ');
fprintf( fileID,'&  %1.2d  ',rec_ang_err1);
fprintf( fileID,'\n\nAngle L2 error 2:       ');
fprintf( fileID,'&  %1.2d  ',rec_ang_err2);
fprintf( fileID,'\n\nRelative L2 error 1:    ');
fprintf( fileID,'&  %1.2d  ',rec_NR_err1);
fprintf( fileID,'\n\nRelative L2 error 2:    ');
fprintf( fileID,'&  %1.2d  ',rec_NR_err2);
fprintf( fileID,'\n\nCondition number 1:     ');
fprintf( fileID,'&  %1.2d  ',rec_NR_cond1);
fprintf( fileID,'\n\nCondition number 2:     ');
fprintf( fileID,'&  %1.2d  ',rec_NR_cond2);


fprintf( fileID,['\n' '-'*ones(1,80) '\n']);
fprintf( fileID,'\nStandard FEM:\n\n');
fprintf( fileID,'Condition number:       ');
fprintf( fileID,'&  %1.2d  ',rec_S_cond);
fprintf( fileID,'\n\nRelative L2 error:      ');
fprintf( fileID,'&  %1.2d  ',rec_S_err);

fprintf( fileID,['\n' '-'*ones(1,80) '\n']);
fprintf( fileID,'\nExact Ray-based FEM:\n\n');
fprintf( fileID,'Condition number:       ');
fprintf( fileID,'&  %1.2d  ',rec_ER_cond);
fprintf( fileID,'\n\nRelative L2 error:      ');
fprintf( fileID,'&  %1.2d  ',rec_ER_err);

fprintf( fileID,['\n' '-'*ones(1,80) '\n']);
fprintf( fileID,'\nPhase-based FEM:\n\n');
fprintf( fileID,'Condition number:       ');
fprintf( fileID,'&  %1.2d  ',rec_P_cond);
fprintf( fileID,'\n\nRelative L2 error:      ');
fprintf( fileID,'&  %1.2d  ',rec_P_err);
fprintf( fileID,['\n' '-'*ones(1,80) '\n']);



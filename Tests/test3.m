%% %% Four Point Sources Problem Iterative Idea: outside domain (-2,-2),(2,2),(-2,2),(2,-2) 
%  uexact = sqrt(k)*besselh(0,1,k*sqrt((x+2)^2 + (y+2)^2))
%         + sqrt(k)*2*besselh(0,1,k*sqrt((x-2)^2 + (y-2)^2))
%         + sqrt(k)*0.5*besselh(0,1,k*sqrt((x+2)^2 + (y-2)^2))
%         - sqrt(k)*besselh(0,1,k*sqrt((x-2)^2 + (y+2)^2))
clear;
fileID = fopen('result3_iter.txt','a');


%% Load source data
pde = Helmholtz_data3;
fprintf(fileID,'\n\nFour point sources problem: \n\n  (-2,-2),(2,2),(-2,2),(2,-2) \n\n');


%% Set up
plt = 0;                   % show solution or not
fquadorder = 6;            % numerical quadrature order
solver = 'DIR';            % linear system solver
pct = 1/10;
Nray = 4;
data = 'num';

rec_N = 1 ;                 % we test rec_N examples

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

% record the interpolation error with exact ray information
rec_int_err = rec_omega;

% record the stability constant C = \omega*|u|_{L^2}/(|f|_{L^2} + |g|_{L^2})
rec_sta_con = rec_omega;

global omega;
global a;
% lg_a,md_a,sm_a have to be chosen to match the mesh size h and ch
% (for example md_a/ch = integer), and the real radius in NMLA as well
% (r1+md_a < lg_a, r2 + sm_a < md_a)
lg_a = 2;
md_a = 1;
sm_a = 1/2;
Rest = 2.5;
high_omega = 60*pi;
NPW = 10;

% cp_omega = [20 40 80 160 320 640 1280]*2*pi;
tstart = tic;
for rec_i = 1: rec_N
%     high_omega = cp_omega(rec_i);
    high_omega = high_omega + 20*pi;
    low_omega = 3*sqrt(high_omega);
%     if high_omega == 10*pi
%         low_omega = sqrt(high_omega);
%     end
    h = 1/(NPW*round(high_omega/(2*pi)));
    ch = 1/(NPW*round(low_omega/(2*pi)));   

    if high_omega >= 10*2*pi;
        lg_a = 17/12;
        md_a = 11/12;
        
    elseif high_omega >= 20*2*pi;
        lg_a = 4/3;
        md_a = 5/6;
%         low_omega = 2*sqrt(high_omega);
%     elseif high_omega >= 30*2*pi;
%         lg_a = 5/4;
%         md_a = 19/24;
% %         low_omega = 2*sqrt(high_omega);
%         h = 1/(NPW*2*round(high_omega/(2*pi))/2);
%         ch = 1/(NPW*2*round(low_omega/(2*pi)/2));
    elseif high_omega >= 60*2*pi;
        lg_a = 5/4;
        md_a = 3/4;
%         low_omega = 2*sqrt(high_omega);
    elseif high_omega >= 70*2*pi;
        lg_a = 7/6;
        md_a = 3/4;
%         low_omega = 2*sqrt(high_omega);
    end
    
    fprintf(['-'*ones(1,80) '\n']);
    fprintf(['-'*ones(1,80) '\n']);
    fprintf('\ncase %d: \nomega/(2*pi) = %d,   1/h = %d   1/ch = %d,  NPW = %d \n\n',...
        rec_i, high_omega/(2*pi), 1/h, 1/ch, NPW);
    rec_omega(rec_i) = high_omega;
    rec_h(rec_i) = h;
    
    
    %% Step 1: Solve the Hemholtz equation with the same source but with a relative low frequency sqrt(\omega) by Standard FEM, mesh size \omega*h = constant
    fprintf(['\n' '-'*ones(1,80) '\n']);
    fprintf('Numerical Ray-based FEM: \n\n');
    fprintf('Step1 \n');
    
    omega = low_omega;
    a = lg_a;
    
    sh = h/3;
    [lsnode,lselem] = squaremesh([-a,a,-a,a],sh);
    [u_std,~,~,err] = Standard_FEM_IBC(lsnode,lselem,omega,pde,fquadorder,solver,plt);
    [lnode,lelem] = squaremesh([-a,a,-a,a],h);
    u_std = interpolation(lsnode,lselem,lnode,u_std);
    err 
    
    if err>0.1
        fprintf('S-FEM is not accurate enough!\n');
%         return;
    end
    
    
    %% Step 2: Use NMLA to find ray directions d_c with low frequency sqrt(\omega)
    fprintf(['\n' '-'*ones(1,80) '\n']);
    fprintf('\nStep2 \n');
    
    [ux,uy] = num_derivative(u_std,h,2);
   
    a = md_a;
    [mnode,melem] = squaremesh([-a,a,-a,a],h);
    mN = size(mnode,1);
    mn = round(sqrt(mN));
    
    [cnode,celem] = squaremesh([-a,a,-a,a],ch);
    cN = size(cnode,1);
    cnumray = zeros(cN,Nray);
    
    fprintf('NMLA time: \n');
    tic;
    for i = 1:cN
        x0 = cnode(i,1);  y0 = cnode(i,2);
        c0 = pde.speed(cnode(i,:));
        [cnumray(i,:)] = NMLA_2D_2nd(x0,y0,c0,omega,Rest,lnode,lelem,u_std,ux,uy,pde,pct,Nray,data,plt);
    end
    toc;
    
    cdiffang1 = cnumray - pde.ray_ang(cnode);
    
    fprintf('Interpolation time: \n');
    tic;
    numray1 = interpolation(cnode,celem,mnode,cnumray);
    toc;
    
    ray_dir = pde.ray_ang(mnode);
    diffang1 = numray1 - ray_dir;
    rec_ang_err1(rec_i) = h*norm(diffang1(:),2)/(h*norm(ray_dir(:),2));
    
    numray = exp(1i*numray1);
    
    clear lnode lelem;
    
    
    %% Step 3: Solve the original Helmholtz equation by Ray-based FEM with ray directions d_c
    fprintf(['\n' '-'*ones(1,80) '\n']); 
    fprintf('\nStep3 \n');
    
    omega = high_omega;
    [uh1,A,~,~,rel_L2_err] = Ray_FEM_IBC_1(mnode,melem,omega,pde,numray,fquadorder,plt);
    rec_NR_err1(rec_i) = rel_L2_err;
%     rec_NR_cond1(rec_i) = condest(A);
    
    
    %% Step 4: NMLA to find original ray directions d_o with wavenumber k
    fprintf(['\n' '-'*ones(1,80) '\n']);
    fprintf('\nStep4 \n');
    
    a = sm_a;
    [node,elem] = squaremesh([-a,a,-a,a],h);
    
    [cnode,celem] = squaremesh([-a,a,-a,a],ch);
    cN = size(cnode,1);
    cnumray = zeros(cN,Nray);
    
    [ux,uy] = num_derivative(uh1,h,2);
    
    fprintf('NMLA time: \n');
    tic;
    for i = 1:cN
        x0 = cnode(i,1);  y0 = cnode(i,2);
        c0 = pde.speed(cnode(i,:));
        [cnumray(i,:)] = NMLA_2D_2nd(x0,y0,c0,omega,Rest,mnode,melem,uh1,ux,uy,pde,pct,Nray,data,plt);
    end
    toc;
    
    fprintf('Interpolation time: \n');
    tic;
    numray2 = interpolation(cnode,celem,node,cnumray);
    toc;
    
    cdiffang2 = cnumray - pde.ray_ang(cnode);
    ray_dir = pde.ray_ang(node);
    diffang2 = numray2 - ray_dir;
    rec_ang_err2(rec_i) = h*norm(diffang2(:),2)/(h*norm(ray_dir(:),2));
    
    numray = exp(1i*numray2);
    
    clear mnode melem;
    
    %% Step 5: Solve the original Helmholtz equation by Ray-based FEM with ray directions d_o
    fprintf(['\n' '-'*ones(1,80) '\n']);
    fprintf('\nStep5 \n');
    
    omega = high_omega;
    [uh2,A,~,~,rel_L2_err] = Ray_FEM_IBC_1(node,elem,omega,pde,numray,fquadorder,plt);
    rec_NR_err2(rec_i) = rel_L2_err;
%     rec_NR_cond2(rec_i) = condest(A);
    
    %% compute the stability constant
%     fval = pde.f(node);
%     [bdNode,~,~] = findboundary(elem);
%     gval = pde.g_IBC(node(bdNode,:));
%     rec_sta_con(rec_i) = omega*h*norm(uh2,2)/(h*norm(fval,2) + sqrt(h)*norm(gval,2));
    
    %% Iteration steps
    if (0)
    iter = 3;
    sN = size(node,1);
    sn = round(sqrt(sN));
    nn = round((mn-sn)/2) + 1 : round((mn+sn)/2);
    n = mn;
    uu = zeros(n);
    for j = 1: iter
        j
        uh = reshape(uh2,sn,sn);
        uu(nn,nn) = uh;
        uh1 = uu(:);
        uux = uu;   uuy = uu;   % numerical Du
        
        uux(:,2:n-1) = (uu(:,3:n) - uu(:,1:n-2))/(2*h);
        uux(:,n) = 2*uux(:,n-1) - uux(:,n-2);
        uux(:,1) = 2*uux(:,2) - uux(:,3);
        ux = uux(:);
        
        
        uuy(2:n-1,:) = (uu(3:n,:) - uu(1:n-2,:))/(2*h);
        uuy(n,:) = 2*uuy(n-1,:) - uuy(n-2,:);
        uuy(1,:) = 2*uuy(2,:) - uuy(3,:);
        uy = uuy(:);
        
        for i = 1:cN
            x0 = cnode(i,1);  y0 = cnode(i,2);
            c0 = pde.speed(cnode(i,:));
            [cnumray(i,:)] = NMLA_2D_2nd(x0,y0,c0,omega,Rest,mnode,melem,uh1,ux,uy,pde,1/5,Nray,data,plt);
        end
        numray2 = interpolation(cnode,celem,node,cnumray);
        
        diffang2 = numray2(:) - ray_dir;
        ang_err = h*norm(diffang1,2)/(h*norm(ray_dir,2))
        
        numray = exp(1i*numray2);
        [uh2,A,~,~,rel_L2_err] = Ray_FEM_IBC_1(node,elem,omega,pde,numray,fquadorder,plt);
        u_err = rel_L2_err
    end
    end 
    
    
    %% Standard FEM
    if (0)
        fprintf('\nStandard FEM: \n');
        [~,A,~,rel_L2_err] = Standard_FEM_IBC(node,elem,omega,pde,fquadorder,solver,plt);
        rec_S_err(rec_i) = rel_L2_err;
        rec_S_cond(rec_i) = condest(A);
    end
    
    %% Exact Ray-based FEM:
    if (1)
        fprintf(['\n' '-'*ones(1,80) '\n']); 
        fprintf('\nExact Ray-based FEM: \n');
        ray = pde.ray(node);
        [~,A,~,~,rel_L2_err] = Ray_FEM_IBC_1(node,elem,omega,pde,ray,fquadorder,plt);
        rec_ER_err(rec_i) = rel_L2_err;
%         rec_ER_cond(rec_i) = condest(A);
        
%         coeff = pde.int_coe(node);
%         c = pde.speed(node);
%         [rec_int_err(rec_i)] = Ray_FEM_L2_Error(coeff,node,elem,omega,c,pde.ex_u,ray,fquadorder);
    end
    
    
    %% Phase-based FEM:
    if (0)
        fprintf('\nPhase-based FEM: \n');
        [~,A,~,~,rel_L2_err] = Phase_FEM_IBC(node,elem,omega,pde,fquadorder,plt);
        rec_P_err(rec_i) = rel_L2_err;
        rec_P_cond(rec_i) = condest(A);
    end
    
    
end

totaltime = toc(tstart);
fprintf('\n\nTotal running time: % d minutes \n', totaltime/60);


%% record and print results
rec = [rec_omega;rec_h;rec_S_err;rec_S_cond;...
    rec_ang_err1;rec_ang_err2;rec_NR_err1;rec_NR_err2;rec_NR_cond1;rec_NR_cond2;...
    rec_ER_cond;rec_ER_err;rec_P_cond;rec_P_err;rec_int_err;rec_sta_con];
save('result3.mat','rec_omega','rec_h','rec_S_err','rec_S_cond','rec_ang_err1',...
    'rec_ang_err2','rec_NR_err1','rec_NR_err2','rec_NR_cond1','rec_NR_cond2',...
    'rec_ER_cond','rec_ER_err','rec_P_cond','rec_P_err','rec_int_err','rec_sta_con');


fprintf( fileID,['\n' '-'*ones(1,80) '\n']);
fprintf( fileID,'omega:                  ');
fprintf( fileID,'%1.2e  ',rec_omega );
fprintf( fileID,'\nomega/2pi:              ');
fprintf( fileID,'%1.2e  ',rec_omega/(2*pi) );
fprintf( fileID,'\n\nGrid size h:            ');
fprintf( fileID,'%1.2e  ',rec_h);
fprintf( fileID,'\n1/h:                    ');
fprintf( fileID,'%1.2e  ',1./rec_h);

fprintf( fileID,['\n' '-'*ones(1,80) '\n']);
fprintf( fileID,'\nNumerical Ray-based FEM:\n\n');
fprintf( fileID,'Angle L2 error 1:       ');
fprintf( fileID,'%1.2d  ',rec_ang_err1);
fprintf( fileID,'\n\nAngle L2 error 2:       ');
fprintf( fileID,'%1.2d  ',rec_ang_err2);
fprintf( fileID,'\n\nRelative L2 error 1:    ');
fprintf( fileID,'%1.2d  ',rec_NR_err1);
fprintf( fileID,'\n\nRelative L2 error 2:    ');
fprintf( fileID,'%1.2d  ',rec_NR_err2);
fprintf( fileID,'\n\nCondition number 1:     ');
fprintf( fileID,'%1.2d  ',rec_NR_cond1);
fprintf( fileID,'\n\nCondition number 2:     ');
fprintf( fileID,'%1.2d  ',rec_NR_cond2);


fprintf( fileID,['\n' '-'*ones(1,80) '\n']);
fprintf( fileID,'\nStandard FEM:\n\n');
fprintf( fileID,'Condition number:       ');
fprintf( fileID,'%1.2d  ',rec_S_cond);
fprintf( fileID,'\n\nRelative L2 error:      ');
fprintf( fileID,'%1.2d  ',rec_S_err);

fprintf( fileID,['\n' '-'*ones(1,80) '\n']);
fprintf( fileID,'\nExact Ray-based FEM:\n\n');
fprintf( fileID,'Condition number:       ');
fprintf( fileID,'%1.2d  ',rec_ER_cond);
fprintf( fileID,'\n\nRelative L2 error:      ');
fprintf( fileID,'%1.2d  ',rec_ER_err);

fprintf( fileID,['\n' '-'*ones(1,80) '\n']);
fprintf( fileID,'\nPhase-based FEM:\n\n');
fprintf( fileID,'Condition number:       ');
fprintf( fileID,'%1.2d  ',rec_P_cond);
fprintf( fileID,'\n\nRelative L2 error:      ');
fprintf( fileID,'%1.2d  ',rec_P_err);
fprintf( fileID,['\n' '-'*ones(1,80) '\n']);

fprintf( fileID,['\n' '-'*ones(1,80) '\n']);
fprintf( fileID,'Interpolation error      ');
fprintf( fileID,'%1.2d  ',rec_int_err);
fprintf( fileID,'\n\nStability constant:      ');
fprintf( fileID,'%1.2d  ',rec_sta_con);
fprintf( fileID,['\n' '-'*ones(1,80) '\n']);

%% Show convergence rate with respect to omega
if (0)
    % stability constant
    figure(1);
    plot(rec_omega/(2*pi), rec_sta_con,'*-');
    axis([0 200 0.35 0.45])% axis tight;
    xlabel('Frequency \omega/2\pi');
    ylabel('Stability constant C_{sta}');
    
    % angle error
    figure(2);
    loglog(rec_omega/(2*pi), rec_ang_err1,'bs-');
    hold on;
    loglog(rec_omega/(2*pi), rec_ang_err2,'r*-');
    axis([0 200 -inf inf])% axis tight;
    xlabel('Frequency \omega/2\pi');
    ylabel('Relative L^2 error');
    legend('Angle Error 1','Angle Error 2','LOCATION','Best');
    
    % NR-FEM error
    figure(3);
    loglog(rec_omega/(2*pi), rec_NR_err1,'bs-');
    hold on;
    loglog(rec_omega/(2*pi), rec_NR_err2,'r*-');
    hold on;
    loglog(rec_omega/(2*pi), rec_ER_err,'ko-');
    hold on;
    loglog(rec_omega/(2*pi), rec_int_err,'g^-');
    axis([0 200 -inf inf]);
    xlabel('Frequency \omega/2\pi');
    ylabel('Relative L^2 error');
    legend('NR-FEM Error 1','NR-FEM Error 2','ER-FEM Error','Interpoltation Error','LOCATION','Best');
    
    % optimality constant
    figure(4);
    plot(rec_omega/(2*pi), rec_NR_err2./rec_int_err,'*-');
    axis([0 200 0.35 0.55])% axis tight;
    xlabel('Frequency \omega/2\pi');
    ylabel('Optimality relation C_{opt}');
end

%% Show convergence rate with respect to h
if (0)
    figure(5);
%     loglog(rec_h, rec_NR_err1,'bs-');
%     hold on;
    loglog(1./rec_h, rec_NR_err2,'r*-');
    hold on;
    loglog(1./rec_h, rec_ER_err,'ko-');
    hold on;
    loglog(1./rec_h, rec_int_err,'g^-');
    axis([50 1000 -inf inf]);
    xlabel('mesh size 1/h');
    ylabel('Relative L^2 error');
    legend('NR-FEM Error 2','ER-FEM Error','Interpoltation Error','LOCATION','Best');    
end


if (1)
    figure(2);
    loglog(rec_omega/(2*pi), rec_ang_err1,'bs-');
    hold on;
    loglog(rec_omega/(2*pi), rec_ang_err2,'r*-');
    axis([0 50 -inf inf])% axis tight;
    xlabel('Frequency \omega/2\pi');
    ylabel('Relative L^2 error');
    legend('Angle Error 1','Angle Error 2','LOCATION','Best');
    
    % NR-FEM error
    figure(3);
    loglog(rec_omega/(2*pi), rec_NR_err1,'bs-');
    hold on;
    loglog(rec_omega/(2*pi), rec_NR_err2,'r*-');
    hold on;
    loglog(rec_omega/(2*pi), rec_ER_err,'ko-');
    hold on;
    axis([0 50 -inf inf]);
    xlabel('Frequency \omega/2\pi');
    ylabel('Relative L^2 error');
    legend('NR-FEM Error 1','NR-FEM Error 2','ER-FEM Error','LOCATION','Best');
    
end
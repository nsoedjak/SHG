%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SHG: Second harmonic generation image reconstruction with least-square 
%       minimization method
%
% Authors: Kui Ren  (kr2002@columbia.edu), Nathan Soedjak (ns3572@columbia.edu)
% Institution: Department of Applied Physics and Applied Mathematics, Columbia University
% Last update: 2023-2-18
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Mathematical model:
% \Delta u + k^2 (1+n) u +i k \sigma u =0
% u = f
% 
% \Delta v + (2k)^2 (1+n) v +i 2k \sigma v = -(2k)^2 \gamma u^2
% v + i2k n*grad v = 0
%
% Internal data: H = \sigma (|u|^2 + |v|^2)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all;  close all;

tic; tb=toc;

% Load geometrical information on the domain
load 'geo-2b2';

% Create a Cartesian grid for inversion
dx=0.025; x=0:dx:2;
dy=0.025; y=0:dy:2;
Nx=length(x);
Ny=length(y);
% [X,Y]=meshgrid(x,y);

% Generate regular finite element mesh on rectangular geometry
[P,E,T]=poimesh(geo,Nx-1,Ny-1); 
%figure;
%pdemesh(P,E,T);
%axis tight; axis square; box on; axis off;
%title('Finite element mesh');

M=Nx*Ny; % total number of nodes in the mesh







%----------------------Start of adjustable parameters----------------------

% Decide which parameter to be reconstructed
MinVar=["gamma"]; % Subset of ["Ref","Sigma","gamma"]

noiselevel=0.00; % set noise level
betan=0e-9; betaS=1*betan; betaG=1*betan; % regularization parameters

MaxIT=500;

Ns=36;

wnum=1; % wave number k

% Set true parameters for wave propagation
rec1=[0.5 0.8; 0.5 0.8]; 
rec2=[1.4 1.7; 1.4 1.7];
rec3=[1.0 1.8; 0.3 0.6];
circ1=[1.0 1.5 0.2];
circ2=[1.5 1.0 0.3];

%reft=0.3*ones(M,1); % true refractive index
%reft=(0.1+0.2*exp(-(P(1,:)-1).^2-(P(2,:)-1).^2))';
reft=0.2+0.2*ind_rec(P,rec1)+0.4*ind_rec(P,rec2)+0.6*ind_rec(P,rec3);

%sigmat=(0.1+0.2*exp(-(P(1,:)-1).^2-(P(2,:)-1).^2))';
%sigmat=0.2+0.2*ind_rec(P,rec1)+0.4*ind_rec(P,rec2)+0.6*ind_rec(P,rec3);
sigmat=0.02*ones(M,1); % true absorption
for k1=1:10
    for k2=1:10
        dom=[0.5+(k1-1)*0.1 0.5+k1*0.1;0.5+(k2-1)*0.1 0.5+k2*0.1];
        sigmat=sigmat+0.02*(sign(rand-0.5)+1)*ind_rec(P,dom);
    end
end

gammat=0.2+0.2*ind_rec(P,rec1)+0.4*ind_rec(P,rec2)+0.6*ind_rec(P,rec3); %true nonlinear susceptibility


% Setup initial guess
ref0=0.2*ones(M,1);
if ~ismember("Ref",MinVar)
    ref0=reft;
end

sigma0=0.02*ones(M,1);
if ~ismember("Sigma",MinVar)
    sigma0=sigmat;
end

gamma0=0.3*ones(M,1);
if ~ismember("gamma",MinVar)
    gamma0=gammat;
end

X0=[ref0' sigma0' gamma0']';
%-----------------------End of adjustable parameters-----------------------








%Plot initial guesses
if ismember("Ref",MinVar)
    ref0g=tri2grid(P,T,ref0,x,y);
    figure;
    ph = pcolor(x,y,ref0g); axis tight; colorbar('SouthOutside');
    axis square; axis off; shading interp;
    ph.ZData = ph.CData;
    caxis([0.2 0.8]);
    title('initial guess of n');
    drawnow;
end
if ismember("Sigma",MinVar)
    sigma0g=tri2grid(P,T,sigma0,x,y);
    figure;
    ph = pcolor(x,y,sigma0g); axis tight; colorbar('SouthOutside');
    axis square; axis off; shading interp;
    ph.ZData = ph.CData;
    caxis([0.01 0.07]);
    title('initial guess of \sigma');
    drawnow;
end
if ismember("gamma",MinVar)
    gamma0g=tri2grid(P,T,gamma0,x,y);
    figure;
    ph = pcolor(x,y,gamma0g); axis tight; colorbar('SouthOutside');
    axis square; axis off; shading interp;
    ph.ZData = ph.CData;
    caxis([0.2 0.8]);
    title('initial guess of \gamma');
    drawnow;
end

% Setup information on sources and boundary edges
SrcInfo=SetSources(Ns);
BdaryInfo=SetBdaryInfo(P,E);

if ismember("Ref", MinVar)
    reftg=tri2grid(P,T,reft,x,y);
    figure;
    ph = pcolor(x,y,reftg); axis tight; colorbar('SouthOutside');
    axis square; axis off; shading interp;
    ph.ZData = ph.CData;
    caxis([0.2 0.8]);
    title('true n');
    drawnow;
end
if ismember("Sigma", MinVar)
    sigmatg=tri2grid(P,T,sigmat,x,y);
    figure;
    ph = pcolor(x,y,sigmatg); axis tight; colorbar('SouthOutside');
    axis square; axis off; shading interp;
    ph.ZData = ph.CData;
    %caxis([0.01 0.07]);
    title('true \sigma');
    drawnow;
end
if ismember("gamma", MinVar)
    gammatg=tri2grid(P,T,gammat,x,y);
    figure;
    ph = pcolor(x,y,gammatg); axis tight; colorbar('SouthOutside');
    axis square; axis off; shading interp;
    ph.ZData = ph.CData;
    caxis([0.2 0.8]);
    title('true gamma');
    drawnow;
end

% Generating synthetic data
disp(' ');
disp(' ');
disp('Generating synthetic data .......');
disp(' ');

srczero=zeros(M,1);
Hm=zeros(M,Ns);
for ks=1:Ns
    
    % Solve the Helmholtz equations
    ut=HelmholtzSolve('u_Forward',SrcInfo,BdaryInfo,ks,P,E,T,wnum,reft,sigmat,srczero);

    srcv = -(2*wnum)^2 * gammat .* ut.^2;
    vt=HelmholtzSolve('Homogeneous_Robin',SrcInfo,BdaryInfo,ks,P,E,T,2*wnum,reft,sigmat,srcv);

    Ht=sigmat.*(abs(ut).^2 + abs(vt).^2);


    %Plot data/solutions
    %utg=tri2grid(P,T,vt,x,y);
    %figure;
    %ph = contourf(x,y,angle(utg)); axis tight; colorbar('SouthOutside');
    %ph = pcolor(x,y,real(utg)); axis tight; colorbar('SouthOutside');
    %axis square; axis off; shading interp;
    %ph.ZData = ph.CData;
    %drawnow;
    %pause
   
    % Add noise to data
	Hm(:,ks)=Ht.*(1+noiselevel*2*(rand(M,1)-0.5));
    
%   disp(['Synthetic data generated for source #: ' num2str(ks)]);
%   disp('  ');

    clear ut Ht;
end
disp('Finished generating synthetic data .......');


% This short part is only for debugging
%[f0 g0]=qTATObj(X0,MinVar,x,y,dx,dy,Nx,Ny,P,E,T,Ns,Hm,SrcInfo,BdaryInfo,wnum);
%g0g=tri2grid(P,T,g0(1:M),x,y);
%g0g=tri2grid(P,T,g0(M+1:2*M),x,y);
%figure;
%pcolor(x,y,g0g); axis tight; colorbar('SouthOutside');
%axis square; shading interp;
%title('Gradient');
%drawnow;

OptimMethod='UNCON';

% Setup the minimization algorithm
disp(' ');
disp(' ');
disp('Minimizing objective function .......');
disp(' ');

f=@(X) SHGObj(X,MinVar,x,y,dx,dy,Nx,Ny,P,E,T,Ns,Hm,SrcInfo,BdaryInfo,wnum,betan,betaS,betaG);

if strcmp(OptimMethod,'UNCON')
    options=optimoptions(@fminunc,'Algorithm','quasi-newton', ...
    'Display','iter-detailed','GradObj','on','TolFun',1e-12,...
    'MaxIter',MaxIT);
    [X,fval,exitflag,output,grad]=fminunc(f,X0,options);
else
    % Set inequality constraint
    Aieq=zeros(1,2*M);
    Bieq=0;
    % Set equality constraint
    Aeq=zeros(1,2*M);
    Beq=0;
    % Set upper and lower bounds
    LB=[0.1*ones(1,M) 0.1*ones(1,M)]';
    UB=[0.9*ones(1,M) 0.4*ones(1,M)]';

    options=optimoptions(@fmincon,'Algorithm','trust-region', ...
    'Display','iter-detailed','GradObj','on','TolFun',1e-12,...
    'MaxIter',MaxIT);
    %options=optimset('Display','iter-detailed','GradObj','on','TolFun',1e-12,'MaxIter',MaxIT);
    %options = optimset('algorithm','sqp','maxfunevals',5000,'maxiter',100);
    %options = optimset(options,'tolx',1e-9,'tolcon',1e-9,'tolfun',1e-6);
    %options = optimset(options,'GradObj','on','GradConstr','off');
    
    [X,fval,exitflag,output,lambda]=fmincon(f,X0,Aieq,Bieq,Aeq,Beq,LB,UB,[],options);
    %[X,fval,exitflag,output]=fmincon(f,X0,zeros(M,M),zeros(M,1),[],[],LB,UB);
end

disp(' ');
disp(' ');
disp('Finished minimizing objective function .......');

disp(' ');
disp(' ');
disp('Plotting final results .......');
disp(' ');

refr=X(1:M);
sigmar=X(M+1:2*M);
gammar=X(2*M+1:3*M);
% Plot reconstruction results
if ismember("Ref",MinVar)
    refrg=tri2grid(P,T,refr,x,y);
    figure;
    ph = pcolor(x,y,refrg); axis tight; colorbar('SouthOutside');
    axis square; axis off; shading interp;
    ph.ZData = ph.CData;
    caxis([0.2 0.8]);
    title('recovered n');
    drawnow;
end
if ismember("Sigma",MinVar)
    sigmarg=tri2grid(P,T,sigmar,x,y);
    figure;
    ph = pcolor(x,y,sigmarg); axis tight; colorbar('SouthOutside');
    axis square; axis off; shading interp;
    ph.ZData = ph.CData;
    %caxis([0.01 0.07]);
    title('recovered \sigma');
    drawnow;
end
if ismember("gamma",MinVar)
    gammarg=tri2grid(P,T,gammar,x,y);
    figure;
    ph = pcolor(x,y,gammarg); axis tight; colorbar('SouthOutside');
    axis square; axis off; shading interp;
    ph.ZData = ph.CData;
    caxis([0.2 0.8]);
    title('recovered gamma');
    drawnow;
end

disp('Finished plotting final results .......');

save Exp01-Info geo P E T SrcInfo BdaryInfo wnum Ns MaxIT ...
                  OptimMethod noiselevel dx dy -ASCII
save Exp01-Results reft ref0 refr sigmat sigma0 sigmar -ASCII

te=toc;
disp(' ');
disp(' ');
disp(['The code ran for: ' num2str(te-tb) ' seconds']);
disp(' ');
disp(' ');

% This last line is used to close MATLAB after the computation. It is 
% only used when runing the code in background.

%exit; % to exit MATLAB
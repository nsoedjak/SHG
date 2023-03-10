%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function evaluate the objective function and its gradients with 
% respect to the optimization variables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [f g]=SHGObj(X,MinVar,x,y,dx,dy,Nx,Ny,P,E,T,...
    Ns,Hm,SrcInfo,BdaryInfo,wnum,betan,betaS,betaG)

M=Nx*Ny; % total number of nodes in the mesh
ne = size(SrcInfo,2); % number of edges/nodes on the domain boundary

refc=X(1:M);% current value of n
sigmac=X(M+1:2*M); % current value of sigma
gammac=X(2*M+1:3*M); %current value of gamma

f=0.0;
g=zeros(3*M,1);
for ks=1:Ns
    
    Hc=zeros(M,1); % predicted data
    rz=zeros(M,1); % residual on measurement locations
    srczero=zeros(M,1); % zero volume source for forward problems
 
    uc=HelmholtzSolve('u_Forward',SrcInfo,BdaryInfo,ks,P,E,T,wnum,refc,sigmac,srczero);

    srcv = -(2*wnum)^2 * gammac .* uc.^2;
    vc=HelmholtzSolve('Homogeneous_Robin',SrcInfo,BdaryInfo,ks,P,E,T,2*wnum,refc,sigmac,srcv);

    Hc=sigmac.*(abs(uc).^2 + abs(vc).^2);
    
    %Hcg=tri2grid(P,T,Hc,x,y);
    %figure;
    %pcolor(x,y,Hcg); axis tight; colorbar('SouthOutside');
    %axis square; axis off; shading interp;
    %drawnow;
    
    HmL=Hm(:,ks);
    rz=(Hc-HmL); % for unnormalized objective function
    %rz=(Hc-HmL)./HmL; % for normalized objective function
    
    % the contribution to the objective function from source ks
    f=f+0.5*sum(rz.^2)*dx*dy;
    
    % the contribution to the gradient from source ks
    if nargout > 1         

        % solve the adjoint equations
        src_u2=-sigmac.*rz.*conj(uc);        
        u2c=HelmholtzSolve('Homogeneous_Dirichlet',SrcInfo,BdaryInfo,ks,P,E,T,wnum,refc,sigmac,src_u2);

        src_v2=-sigmac.*rz.*conj(vc);        
        v2c=HelmholtzSolve('Homogeneous_Robin',SrcInfo,BdaryInfo,ks,P,E,T,2*wnum,refc,sigmac,src_v2);

        src_u3=-2*(2*wnum)^2*gammac.*uc.*v2c;        
        u3c=HelmholtzSolve('Homogeneous_Dirichlet',SrcInfo,BdaryInfo,ks,P,E,T,wnum,refc,sigmac,src_u3);
        
        %wcg=tri2grid(P,T,wc,x,y);
        %figure;
        %pcolor(x,y,real(wcg)); axis tight; colorbar('SouthOutside');
        %axis square; axis off; shading interp;
        %drawnow;
        %pause;
    
        % the gradient w.r.t n            
        if ismember("Ref",MinVar)
            g(1:M)=g(1:M)+2*wnum^2*real(uc.*u2c + 2^2*vc.*v2c + uc.*u3c)*dx*dy;
        end
        % the gradient w.r.t sigma
        if ismember("Sigma",MinVar)
            g(M+1:2*M)=g(M+1:2*M)+(rz.*abs(uc + vc).^2 ...
                +2*wnum*real(1i*uc.*u2c + 2i*vc.*v2c + 1i*uc.*u3c))*dx*dy;
        end
        % the gradient w.r.t. gamma
        if ismember("gamma",MinVar)
            g(2*M+1:3*M)=g(2*M+1:3*M)+2*(2*wnum)^2*real(uc.^2.*v2c)*dx*dy;
        end
        
    end
    
end

% Add regularization terms to both the objective function and its gradients

if ismember("Ref", MinVar)
    [Rx,Ry] = pdegrad(P,T,refc);
    Rx1=pdeprtni(P,T,Rx); Ry1=pdeprtni(P,T,Ry);
    f=f+0.5*betan*sum(Rx1.^2+Ry1.^2)*dx*dy;
    if nargout > 1
        [Rxx, Rxy]=pdegrad(P,T,Rx1); [Ryx, Ryy]=pdegrad(P,T,Ry1);
        Rx2=pdeprtni(P,T,Rxx); Ry2=pdeprtni(P,T,Ryy);
        Deltan=Rx2+Ry2;
        g(1:M)=g(1:M)-betan*Deltan*dx*dy;
        for j=1:ne
            nd=BdaryInfo(1,j);
            g(nd)=g(nd)+betan*(BdaryInfo(3,j)*Rx1(nd)+BdaryInfo(4,j)*Ry1(nd))*BdaryInfo(5,j);
        end
    end
end
if ismember("Sigma", MinVar)
    [Sx,Sy] = pdegrad(P,T,sigmac);
    Sx1=pdeprtni(P,T,Sx); Sy1=pdeprtni(P,T,Sy);
    f=f+0.5*betaS*sum(Sx1.^2+Sy1.^2)*dx*dy;
    if nargout > 1
        [Sxx, Sxy]=pdegrad(P,T,Sx1); [Syx, Syy]=pdegrad(P,T,Sy1);
        Sx2=pdeprtni(P,T,Sxx); Sy2=pdeprtni(P,T,Syy);
        DeltaSigma=Sx2+Sy2;
        g(M+1:2*M)=g(M+1:2*M)-betaS*DeltaSigma*dx*dy;
        for j=1:ne
            nd=BdaryInfo(1,j);
            g(M+nd)=g(M+nd)+betaS*(BdaryInfo(3,j)*Sx1(nd)+BdaryInfo(4,j)*Sy1(nd))*BdaryInfo(5,j);
        end
    end
end
if ismember("gamma", MinVar)
    [Gx,Gy] = pdegrad(P,T,gammac);
    Gx1=pdeprtni(P,T,Gx); Gy1=pdeprtni(P,T,Gy);
    f=f+0.5*betaG*sum(Gx1.^2+Gy1.^2)*dx*dy;
    if nargout > 1
        [Gxx, Gxy]=pdegrad(P,T,Gx1); [Gyx, Gyy]=pdegrad(P,T,Gy1);
        Gx2=pdeprtni(P,T,Gxx); Gy2=pdeprtni(P,T,Gyy);
        DeltaGamma=Gx2+Gy2;
        g(2*M+1:3*M)=g(2*M+1:3*M)-betaG*DeltaGamma*dx*dy;
        for j=1:ne
            nd=BdaryInfo(1,j);
            g(2*M+nd)=g(2*M+nd)+betaG*(BdaryInfo(3,j)*Gx1(nd)+BdaryInfo(4,j)*Gy1(nd))*BdaryInfo(5,j);
        end
    end
end
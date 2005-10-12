function [fval,cost_flag,ys,trend_coeff,info] = DsgeVarLikelihood(xparam1,gend)
% stephane.adjemian@ens.fr [06-17-2005]

global bayestopt_ exo_nbr dr_ estim_params_ Sigma_e_ options_ xparam1_test
global trend_coeff_ dsge_prior_weight 

info = [ ];

mYY = evalin('base', 'mYY');
mYX = evalin('base', 'mYX');
mXY = evalin('base', 'mXY');
mXX = evalin('base', 'mXX');

fval = [];
cost_flag = [];
ys = [];
trend_coeff = [];


xparam1_test = xparam1;
cost_flag  = 1;
nobs = size(options_.varobs,1);

if options_.mode_compute ~= 1 & any(xparam1 < bayestopt_.lb)
  k = find(xparam1 < bayestopt_.lb);
  fval = bayestopt_.penalty*min(1e3,exp(sum(bayestopt_.lb(k)-xparam1(k))));
  cost_flag = 0;
  return;
end

if options_.mode_compute ~= 1 & any(xparam1 > bayestopt_.ub)
  k = find(xparam1 > bayestopt_.ub);
  fval = bayestopt_.penalty*min(1e3,exp(sum(xparam1(k)-bayestopt_.ub(k))));
  cost_flag = 0;
  return;
end

Q = Sigma_e_;
for i=1:estim_params_.nvx
  k = estim_params_.var_exo(i,1);
  Q(k,k) = xparam1(i)*xparam1(i);
end
offset = estim_params_.nvx;
if estim_params_.nvn
  H = zeros(nobs,nobs);
  for i=1:estim_params_.nvn
    k = estim_params_.var_endo(i,1);
    H(k,k) = xparam1(i+offset)*xparam1(i+offset);
  end
  offset = offset+estim_params_.nvn;
end 
if estim_params_.ncx
  for i=1:estim_params_.ncx
    k1 =estim_params_.corrx(i,1);
    k2 =estim_params_.corrx(i,2);
    Q(k1,k2) = xparam1(i+offset)*sqrt(Q(k1,k1)*Q(k2,k2));
    Q(k2,k1) = Q(k1,k2);
  end
  [CholQ,testQ] = chol(Q);
  if testQ %% The variance-covariance matrix of the structural innovations is not definite positive.
           %% We have to compute the eigenvalues of this matrix in order to build the penalty.
    a = eig(Q);
    k = a<0;
    if k > 0
      fval = bayestopt_.penalty*min(1e3,exp(sum(-a(k))));
      cost_flag = 0;
      return
    end
  end
  offset = offset+estim_params_.ncx;
end

if estim_params_.nvn & estim_params_.ncn 
  for i=1:estim_params_.ncn
    k1 = options_.lgyidx2varobs(estim_params_.corrn(i,1));
    k2 = options_.lgyidx2varobs(estim_params_.corrn(i,2));
    H(k1,k2) = xparam1(i+offset)*sqrt(H(k1,k1)*H(k2,k2));
    H(k2,k1) = H(k1,k2);
  end
  [CholH,testH] = chol(H);
  if testH
    a = eig(H);
    k = a<0;
    if k > 0
      fval = bayestopt_.penalty*min(1e3,exp(sum(-a(k))));
      cost_flag = 0;
      return
    end
  end
  offset = offset+estim_params_.ncn;
end

for i=1:estim_params_.np
  assignin('base',deblank(estim_params_.param_names(i,:)),xparam1(i+offset));
end

Sigma_e_ = Q;

indx = strmatch('dsge_prior_weight',estim_params_.param_names);
if ~isempty(indx)
  dsge_prior_weight = xparam1(indx);
end
  


%------------------------------------------------------------------------------
% 2. call model setup & reduction program
%------------------------------------------------------------------------------
[T,R,SteadyState,info] = dynare_resolve;
if info(1) == 1 | info(1) == 2 | info(1) == 5
  fval = bayestopt_.penalty;
  cost_flag = 0;
  return
elseif info(1) == 3 | info(1) == 4 | info(1) == 20
  fval = bayestopt_.penalty*min(1e3,exp(info(2)));
  cost_flag = 0;
  return
end
if options_.loglinear == 1
  constant = log(SteadyState(bayestopt_.mfys));
else
  constant = SteadyState(bayestopt_.mfys);
end
if bayestopt_.with_trend == 1
  trend_coeff = zeros(nobs,1);
  for i=1:nobs
    trend_coeff(i) = evalin('base',bayestopt_.trend_coeff{i});
  end
  trend = constant*ones(1,gend)+trend_coeff*(1:gend);
else
  trend = constant*ones(1,gend);
end


%------------------------------------------------------------------------------
% 3. theorretical moments (second order)
%------------------------------------------------------------------------------
tmp = lyapunov_symm(T,R*Q*R');
NumberOfObservedVariables = size(options_.varobs,1);
NumberOfLags = options_.varlag;
k = NumberOfObservedVariables*NumberOfLags ;
TheoreticalAutoCovarianceOfTheObservedVariables = zeros(NumberOfObservedVariables,NumberOfObservedVariables,NumberOfLags+1);
if estim_params_.nvn
  TheoreticalAutoCovarianceOfTheObservedVariables(:,:,1) = tmp(bayestopt_.mf,bayestopt_.mf)+H;
else
  TheoreticalAutoCovarianceOfTheObservedVariables(:,:,1) = tmp(bayestopt_.mf,bayestopt_.mf);
end    
for lag = 1:options_.varlag
  tmp = T*tmp;
  if estim_params_.nvn
    TheoreticalAutoCovarianceOfTheObservedVariables(:,:,lag+1) = tmp(bayestopt_.mf,bayestopt_.mf) + H;
  else
    TheoreticalAutoCovarianceOfTheObservedVariables(:,:,lag+1) = tmp(bayestopt_.mf,bayestopt_.mf);
  end
end
GYX = zeros(NumberOfObservedVariables,k);
for i=1:NumberOfLags
  GYX(:,(i-1)*NumberOfObservedVariables+1:i*NumberOfObservedVariables) = ...
      TheoreticalAutoCovarianceOfTheObservedVariables(:,:,i+1);
end
GXX = kron(eye(NumberOfLags),TheoreticalAutoCovarianceOfTheObservedVariables(:,:,1));
for i = 1:NumberOfLags-1
  tmp = diag(ones(NumberOfLags-i,1),i) + diag(ones(NumberOfLags-i,1),-i);
  GXX = GXX + kron(tmp,TheoreticalAutoCovarianceOfTheObservedVariables(:,:,i+1));
end
GYY = TheoreticalAutoCovarianceOfTheObservedVariables(:,:,1);
SIGMAu = dsge_prior_weight*gend*TheoreticalAutoCovarianceOfTheObservedVariables(:,:,1) + mYY ;
tmp = dsge_prior_weight*gend*GYX  + mYX;
SIGMAu = SIGMAu - tmp*inv(dsge_prior_weight*gend*GXX+mXX)*tmp';
SIGMAu = SIGMAu/(gend*(dsge_prior_weight+1));

prodlng1 = sum(gammaln(.5*((1+dsge_prior_weight)*gend- ...
			   NumberOfObservedVariables*NumberOfLags ...
			   +1-(1:NumberOfObservedVariables)')));
prodlng2 = sum(gammaln(.5*(dsge_prior_weight*gend- ...
			   NumberOfObservedVariables*NumberOfLags ...
			   +1-(1:NumberOfObservedVariables)')));

lik = .5*NumberOfObservedVariables*log(det(dsge_prior_weight*gend*GXX+mXX)) ...
      + .5*((dsge_prior_weight+1)*gend-k)*log(det((dsge_prior_weight+1)*gend*SIGMAu)) ...
      - .5*NumberOfObservedVariables*log(det(dsge_prior_weight*gend*GXX)) ...
      - .5*(dsge_prior_weight*gend-k)*log(det(dsge_prior_weight*gend*(GYY-GYX*inv(GXX)*GYX'))) ...
      + .5*NumberOfObservedVariables*gend*log(2*pi)  ...
      - .5*log(2)*NumberOfObservedVariables*((dsge_prior_weight+1)*gend-k) ...
      + .5*log(2)*NumberOfObservedVariables*(dsge_prior_weight*gend-k) ...
      - prodlng1 + prodlng2;

lnprior = priordens(xparam1,bayestopt_.pshape,bayestopt_.p1,bayestopt_.p2,bayestopt_.p3,bayestopt_.p4);
fval = (lik-lnprior);
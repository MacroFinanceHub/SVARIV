%% 1) Set number of VAR Lags, Newey West lags and confidence level.

p           = 24;     %Number of lags in the VAR model
 
confidence  = .68;    %Confidence Level for the standard and weak-IV robust confidence set

% Define the variables in the SVAR
columnnames = [{'Percent Change in Global Crude Oil Production'}, ...
               {'Index of real economic activity'}, ...
               {'Real Price of Oil'}];

time        = 'Month';  % Time unit for the dataset (e.g. year, month, etc).

NWlags      = 0;  % Newey-West lags(if it is neccessary to account for time series autocorrelation)
                  % (set it to 0 to compute heteroskedasticity robust std errors)

norm        = 1; % Variable used for normalization

scale       = 1; % Scale of the shock

horizons    = 20; %Number of horizons for the Impulse Response Functions(IRFs)
                 %(does not include the impact or horizon 0)
                 
NB          = 1000; % number of samples from the asymptotic distribution

%% 1) Load data (saved in structure "data")
%  These are the variables that were defined in line 14 above. 
%  The time units should be on a single.xls file called Time.xls
%  All the VAR variables should be on a single .xls file called Data.xls
%  The external instrument should be in a single .xls file called ExtIV.xls


direct = '/Users/luigicaloi/Documents/Pepe/SVARIV';

application = 'Oil';

cd(strcat(direct,'/Data/',application));

    ydata = xlsread('Data'); 
    %The frequency of this data is 1973:2 - 2007:12
    %The file data.txt was obtained directly from the AER website


    z    = xlsread('ExtIV');
    %The frequency of this data is 1973:2 - 2004:09
    %The .xls file was created by Jim Stock and Mark Watson and it 
    %contains a monthly measure of Kilian's [2008] instrument for the
    %oil supply shock. 
    
    years = xlsread('time');
    
dataset_name = 'OilData'; %The name of the dataset used for generating the figures (used in the output label)

cd(direct)


%% 2) Create an RForm (if necessary)

SVARinp.ydata = ydata;

SVARinp.Z = z;

SVARinp.n        = size(ydata,2); %number of columns(variables)

RForm.p          = p; %RForm_user.p is the number of lags in the model


%a) Estimation of (AL, Sigma) and the reduced-form innovations


% This essentially checks whether the user provided or not his RForm. If
% the user didn't, then we calculate it. If the user did, we skip this section and
% use his/her RForm.

addpath('functions/RForm');

[RForm.mu, ...
 RForm.AL, ...
 RForm.Sigma,...
 RForm.eta,...
 RForm.X,...
 RForm.Y]        = RForm_VAR(SVARinp.ydata, p);

%RForm.AL(:),RForm.V*RForm.Sigma(:),RForm.Gamma(:), RForm.WHatall

%b) Estimation of Gammahat (n times 1)

RForm.Gamma      = RForm.eta*SVARinp.Z(p+1:end,1)/(size(RForm.eta,2));   %sum(u*z)/T. Used for the computation of impulse response.
%(We need to take the instrument starting at period (p+1), because
%we there are no reduced-form errors for the first p entries of Y.)

%c) Add initial conditions and the external IV to the RForm structure

RForm.Y0         = SVARinp.ydata(1:p,:);

RForm.externalIV = SVARinp.Z(p+1:end,1);

RForm.n          = SVARinp.n;

%a) Covariance matrix for vec(A,Gammahat). Used
%to conduct frequentist inference about the IRFs. 
[RForm.WHatall,RForm.WHat,RForm.V] = ...
CovAhat_Sigmahat_Gamma(p,RForm.X,SVARinp.Z(p+1:end,1),RForm.eta,NWlags);     

%NOTES:
%The matrix RForm.WHatall is the covariance matrix of 
% vec(Ahat)',vech(Sigmahat)',Gamma')'
 
%The matrix RForm.WHat is the covariance matrix of only
% vec(Ahat)',Gamma')' 
 
% The latter is all we need to conduct inference about the IRFs,
% but the former is needed to conduct inference about FEVDs.

vechSigma = RForm.V * RForm.Sigma(:);

AL = RForm.AL(:);

Gamma = RForm.Gamma;

%% 3) Estimation of the asymptotic variance of A,Gamma

% Definitions

n            = RForm.n; % Number of endogenous variables

T            = (size(RForm.eta,2)); % Number of observations (time periods)

d            = ((n^2)*p)+(n);     %This is the size of (vec(A)',Gamma')'

%dall         = d+ (n*(n+1))/2;    %This is the size of (vec(A)',vec(Sigma), Gamma')'



%% 4) Make sure that Whatall is symmetric and positive semidefinite

%dall        = size(RForm.WHatall,1);  % this is the size 

WHat     = (RForm.WHat + RForm.WHat')/2;
    
[aux1,aux2] = eig(RForm.WHat);
    
WHat     = aux1*max(aux2,0)*aux1'; 

%% 5) Generate draws
% Centered at (vec(AL)', Gamma')'

gvar    = [mvnrnd(zeros(NB,d),(WHat)/T)',...
                     zeros(d,1)];
          %Added an extra column of zeros to access point estimators       

Draws   = bsxfun(@plus,gvar,...
          [AL;Gamma(:)]);

k       = size(Gamma,1)/n;      

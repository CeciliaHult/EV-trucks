clc;
clear;
close all;

%% Part 0: Set scope and variables

plotScope = 0; % 1 if all graphs are to be plotted and 0 if only selected result graphs
writeResults = 0; %1 is results should be saved to .mat files, tables and figures

currentYear=2023; %year for plotting data etc. Available: 2001-2023
VehicleAgeSpan=30;% number of model years to include in model.

StartYearFleet = 2001; %>=2001 (data available from 2001)
EndYearFleet = 2060;
ForecastMethod = 2; % 1= Constant fleet growth rate derived from data, 2= new vehicles supplied by delta in transport demand

StartYearEmissions = 2020; %must be more than 2019, no data for vehicle cycle pre-2019
EndYearEmissions =2060;

techScenario ="Main"; % Main = BEV&FC, noZEV= only ICE, noFC = only BEVs as ZEVs
fuelScenario = "Main"; %Main = 100% renewable in 2050, Stated = Swedish stated policy, SwedishClimate = 100% renewable in 2045
trafficScenario = "Main"; % Main = Transport Administration base case, Low = lower traffic demand scenario

%Weilbull Survival function parameters
lambda=12.9077; %scale parameter
kappa =3.3215;  %shape parameter

%% Part 1a: Transport and traffic initialisation

% Define truck weight classes and groups
%TransportWeightClasses.xlsx contain data for 2022 and Swedish freight trucks.
TransportWeightClasses=readcell('TransportWeightClasses.xlsx','Sheet','Matlab','Range','A1:I10');
TransportWeightClassesKM(:,1) = cell2mat(TransportWeightClasses(2:9,2));
TransportWeightClassesKMShares(:,1) = cell2mat(TransportWeightClasses(2:9,3));
TransportWeightClassesTKM(:,1) = cell2mat(TransportWeightClasses(2:9,4));
TransportWeightClassesTKMShares(:,1) = cell2mat(TransportWeightClasses(2:9,5));
TransportWeightClassesNShares(:,1) = cell2mat(TransportWeightClasses(2:9,7));
TransportWeightClassesFreightShares(:,1) = cell2mat(TransportWeightClasses(2:9,9));
nTransportWeightClasses = length(TransportWeightClassesKMShares);

%add groups for non-freight trucks and foriegn trucks
TransportTruckGroupsTKM = [...
    0; %swedish non-freight trucks
    sum(TransportWeightClassesTKM(1:3)/1000); %3.5-29.9t
    sum(TransportWeightClassesTKM(4:6)/1000); %30-59.9t;
    sum(TransportWeightClassesTKM(7:8)/1000); %>=60t
    readvars('TransportDemand.xlsx','Sheet','Matlab','Range','G24:G24')]; %foreign trucks
TransportTruckGroupsKM = [...
    readvars('TransportDemand.xlsx','Sheet','Matlab','Range','F24:F24'); %swedish non-freight trucks
    sum(TransportWeightClassesKM(1:3)/1000); %3.5-29.9t
    sum(TransportWeightClassesKM(4:6)/1000); %30-59.9t;
    sum(TransportWeightClassesKM(7:8)/1000); %>=60t
    readvars('TransportDemand.xlsx','Sheet','Matlab','Range','E24:E24')]; %foreign trucks
nGroupsTransport = length(TransportTruckGroupsTKM);
TransportTruckGroupDescription = {'Swedish non-freight trucks';'3.5-29.9t'; '30-59.9t';'>=60t';'Foreign trucks'};


%% Part 1b: Vehicle fleet initialisation

% Import the fleet age structure
FleetInitialAge=readcell('FleetAge.xlsx','Sheet','MatlabStock','Range','A1:X32'); %fleet by age 2001-2023
CurrentFleetAge= cell2mat(FleetInitialAge(2:VehicleAgeSpan+2,currentYear-1999));

% Import the mileage age structure from the last year
ImportRowsMileage= strcat('B',num2str(2),':B',num2str(VehicleAgeSpan+2));
AnnualMileage_Age=readvars('AnnualMileage.xlsx','Sheet','MatlabAge','Range',ImportRowsMileage);% Imports annual mileage by age

%Import annual average group mileage
AnnualMileage_Size=readvars('AnnualMileage.xlsx','Sheet','MatlabFleetGroups','Range','B2:B6');% Imports annual mileage per size group

%Calculate traffic
CurrentFleetKMage =CurrentFleetAge.*AnnualMileage_Age;

%initialise weight classes
FleetWeightClasses=readcell('FleetWeightClasses.xlsx','Sheet','Matlab','Range','A1:E13');
FleetWeightClassesN(:,1) = cell2mat(FleetWeightClasses(2:13,2));
FleetWeightClassesNShares(:,1) = cell2mat(FleetWeightClasses(2:13,3));
FleetWeightClassesTraffic(:,1) = cell2mat(FleetWeightClasses(2:13,4));
FleetWeightClassesTrafficShares(:,1) = cell2mat(FleetWeightClasses(2:13,5));
nFleetWeightClasses = length(FleetWeightClassesTrafficShares);

%merge weightclasses into groups and add foreign trucks
FleetGroupsN = [sum(FleetWeightClassesN(2:6)); %3.5-20t
    sum(FleetWeightClassesN(7:11)); %20-30t
    FleetWeightClassesN(11); %>30t
    FleetWeightClassesN(1); %Swedish tractors
    0]; %Foreign trucks
FleetGroupsTraffic = [sum(FleetWeightClassesTraffic(2:6)); %3.5-20t
    sum(FleetWeightClassesTraffic(7:11)); %20-30t
    FleetWeightClassesTraffic(11); %>30t
    FleetWeightClassesTraffic(1); %Swedish tractors
    TransportTruckGroupsKM(end)]; %Foreign trucks
nGroupsFleet = length(FleetGroupsTraffic);
FleetTruckGroupDescription = {'3.5-20t'; '20-30t';'>30t'; 'Swedish tractors';'Foreign trucks'};

%initialise powertrain composition
FleetPowertrains=readcell('FleetPowertrains.xlsx','Sheet','Matlab','Range','A1:C5');
FleetPowertrainsN(:,1) = cell2mat(FleetPowertrains(2:5,2));
FleetPowertrainsNShares(:,1) = cell2mat(FleetPowertrains(2:5,3));
nFleetPowertrains = length(FleetPowertrainsNShares);


%% PART 2: Forecast initialisation

% Set time horizon for forecast
FleetPeriod=StartYearFleet:EndYearFleet;

%Set fleet annual growth rate (method 1 only)
%FleetGrowthRate = 1.0057; %(average between 2001-2023);
%FleetGrowthRate = 1.0088; %(average between 2014-2023);
%FleetGrowthRate = 1.0128; %(annual increase in Transport Administration base case 2024);
FleetGrowthRate = 1.0085; %(Correlation between vehicle growth and traffic growth based on data (2001-2023) and annual traffic increase from Transport Administration base case 2024);

% Read electrification rates + set share of BEVs of ZEVs
electrificationData=readcell('ElectrificationFleetTruckGroup.xlsx','Sheet','ZEV_shares','Range','A1:F96');  %1971-2065
ZEVRates = cell2mat(electrificationData(2:end,2:6)); % share of new ZEVs per fleet group every year.
BEVdata = readcell('ElectrificationFleetTruckGroup.xlsx','Sheet','BEV_shares','Range','A1:F96'); %1971-2065
BEVshareZEVs = cell2mat(BEVdata(2:end,2:6)); % share of new ZEVs that are BEVs per fleet group every year.

if techScenario =="noZEV"
    ZEVRates = zeros(size(ZEVRates));
end

%Weibull survival function
%S = exp(-(x./lambda).^gamma);
% scrapping p(t+1) = S(t+1)/S(t)
x = 0:VehicleAgeSpan;
scrappingProbabilities=zeros(size(x));
for i=1:VehicleAgeSpan
    scrappingProbabilities(i) = 1-(exp(-(x(i+1)./lambda).^kappa))/(exp(-(x(i)./lambda).^kappa));
end
scrappingProbabilities(end)=1;

%% Part 2a: Transport demand forecasting

%Import forecast data from excel
ImportRowsTransport= strcat('B',num2str(StartYearFleet-2000+2),':B',num2str(2+EndYearFleet-2000));
ImportRowsTraffic= strcat('C',num2str(StartYearFleet-2000+2),':C',num2str(2+EndYearFleet-2000));
ImportRowsDomesticTraffic = strcat('D',num2str(StartYearFleet-2000+2),':D',num2str(2+EndYearFleet-2000));
%ImportRowsDomesticNonFreightTraffic = strcat('H',num2str(StartYearFleet-2000+2),':H',num2str(2+EndYearFleet-2000));
ImportRowsForeignTraffic = strcat('E',num2str(StartYearFleet-2000+2),':E',num2str(2+EndYearFleet-2000));

TransportDemand_Inputdata=readvars('TransportDemand.xlsx','Sheet','Matlab','Range',ImportRowsTransport);%Imports annual transport demand
TrafficDemand_Inputdata=readvars('TransportDemand.xlsx','Sheet','Matlab','Range',ImportRowsTraffic);%Imports annual travel demand
foreignTraffic = readvars('TransportDemand.xlsx','Sheet','Matlab','Range',ImportRowsForeignTraffic);
domesticTrafficDemand = readvars('TransportDemand.xlsx','Sheet','Matlab','Range',ImportRowsDomesticTraffic);

if trafficScenario=="Low"
    TrafficDemand_Inputdata=readvars('TransportDemand.xlsx','Sheet','Matlab-low','Range',ImportRowsTraffic);%Imports annual travel demand
    foreignTraffic = readvars('TransportDemand.xlsx','Sheet','Matlab-low','Range',ImportRowsForeignTraffic);
    domesticTrafficDemand = readvars('TransportDemand.xlsx','Sheet','Matlab-low','Range',ImportRowsDomesticTraffic);
end

SamgodsForecast = readcell('TransportDemand.xlsx','Sheet','Basprognos','Range','A1:M28');
samgodsTraffic =cell2mat(SamgodsForecast(2:28,3:6))/10^3; %Mfkm
samgodsTransport = cell2mat(SamgodsForecast(2:28,9:12))/10^6; %Gtkm

% Calculate total demand scenario
TransportDemand=zeros(nGroupsTransport,length(FleetPeriod));
TrafficDemand=zeros(nGroupsTransport,length(FleetPeriod));
for j = 1:nGroupsTransport
    for t=1:length(FleetPeriod) %Loop for creating a column for travel demand with the length of the set time horizon
        TransportDemand(j,t)=TransportDemand_Inputdata(t,1)*TransportTruckGroupsTKM(j)/sum(TransportTruckGroupsTKM);
        TrafficDemand(j,t)=TrafficDemand_Inputdata(t,1)*TransportTruckGroupsKM(j)/sum(TransportTruckGroupsKM);(j);
    end
end


%% MODULE NOT CURRENTLY USED. Part 2c Transport electric demand forecasting

% electrification rates for ZEV demand

%% Part 2c: Domestic fleet supply forecasting
% initialise stocks, scrapped, and newreg

%Powertrain:ICE
stockICE=zeros(VehicleAgeSpan+1,length(FleetPeriod),nGroupsFleet);% Matrix representing supply from current year for lorries with ICE configuration
InitialFleetAge= cell2mat(FleetInitialAge(2:VehicleAgeSpan+2,StartYearFleet-2001+2));
stockICE(:,1,:) = InitialFleetAge*FleetGroupsN'/sum(FleetGroupsN);

%Powertrain:Electric
stockZEV=zeros(size(stockICE));% Empty matrix representing supply from current year for lorries with electric drive
stockBEV=zeros(size(stockICE));
stockFC=zeros(size(stockICE));

totalFleetSize = zeros(1,length(FleetPeriod));
totalFleetSize(1) = sum(stockICE(:,1,:),"all") + sum(stockZEV(:,1,:),"all");

scrappedICE = zeros(size(stockICE));
scrappedZEV = zeros(size(stockICE));
scrappedBEV = zeros(size(stockICE));
scrappedFC = zeros(size(stockICE));
newICE = zeros(size(stockICE));
newZEV = zeros(size(stockICE));
newBEV = zeros(size(stockICE));
newFC = zeros(size(stockICE));

%run fleet turnover model
for t = 2:length(FleetPeriod)

    if ForecastMethod==1
        totalFleetSize(t)= totalFleetSize(t-1)*FleetGrowthRate;
    end

    tempStockICE = squeeze(stockICE(:,t-1,:));
    tempStockZEV = squeeze(stockZEV(:,t-1,:));

    % calculate fleet turnover for domestic trucks
    [stockICE(:,t,:), scrappedICE(:,t,:), newICE(:,t,:), stockZEV(:,t,:), scrappedZEV(:,t,:), newZEV(:,t,:)] = ...
        FleetTurnoverModel(ForecastMethod,tempStockICE, tempStockZEV, scrappingProbabilities, AnnualMileage_Age, totalFleetSize(t), ZEVRates(t+(StartYearFleet-1971),:),domesticTrafficDemand(t)*10^6);

    if ForecastMethod==2
        totalFleetSize(t) = sum(stockICE(:,t,:),"all") + sum(stockZEV(:,t,:),"all");
    end

    %allocate ZEV into BEV and FC
    if techScenario == "noFC"
        BEVshareZEVs(:,:) = 1;
    end
    newBEV(1,t,:) = squeeze(newZEV(1,t,:))'.*BEVshareZEVs(t+(StartYearFleet-1971),:);
    newFC(1,t,:) = newZEV(1,t,:) - newBEV(1,t,:);

    %divide ZEV stock into BEV and FC
    for j=1:nGroupsFleet
        stockBEV(:,t,j) = stockZEV(:,t,j).*flip(BEVshareZEVs(t+(StartYearFleet-1971)-VehicleAgeSpan:t+(StartYearFleet-1971),j));
        stockFC(:,t,j) = stockZEV(:,t,j) - stockBEV(:,t,j);
        scrappedBEV(:,t,j) = scrappedZEV(:,t,j).*flip(BEVshareZEVs(t+(StartYearFleet-1971)-VehicleAgeSpan:t+(StartYearFleet-1971),j));
        scrappedFC(:,t,j) = scrappedZEV(:,t,j) - scrappedBEV(:,t,j);
    end %j
end %loop fleet

nICE = sum(stockICE,[1,3]);
nZEV = sum(stockZEV,[1,3]);
nBEV = sum(stockBEV,[1,3]);
nFC = sum(stockFC,[1,3]);


%% Part 2c: Load historical data

FleetHistory=readcell('HistoricData.xlsx','Sheet','Matlab','Range','A1:F24');
totalFleetHistory= cell2mat(FleetHistory(2:24,1:2));
newHistory(:,1)= cell2mat(FleetHistory(2:24,1));
newHistory(:,2)= cell2mat(FleetHistory(2:24,3));
syntheticScrappedHistory(:,1) = cell2mat(FleetHistory(2:24,1));
syntheticScrappedHistory(:,2) = cell2mat(FleetHistory(2:24,6));

%% Part 2d: Supply transport demand by fleet traffic supply

transformationData = readcell('TransformationMatrix.xlsx','Sheet','Matlab','Range','A1:F6');%Imports transformation matrix
transformationTable = cell2mat(transformationData(2:6,2:6));

trafficICE_fleet = zeros(length(FleetPeriod),nGroupsFleet);
trafficBEV_fleet = zeros(size(trafficICE_fleet));
trafficFC_fleet = zeros(size(trafficICE_fleet));

%km per age only by mileage
trafficICE_age = zeros(VehicleAgeSpan+1,length(FleetPeriod),nGroupsFleet);
trafficBEV_age = zeros(size(trafficICE_age));
trafficFC_age = zeros(size(trafficICE_age));

%km by age scaled to fleet group annual averagae milage
trafficICE_age2 = zeros(size(trafficICE_age));
trafficBEV_age2 = zeros(size(trafficICE_age));
trafficFC_age2 = zeros(size(trafficICE_age));

%km by age scaled to meet total mileage (including foreign trucks)
trafficICE_age3 = zeros(size(trafficICE_age));
trafficBEV_age3 = zeros(size(trafficICE_age));
trafficFC_age3 = zeros(size(trafficICE_age));

trafficICE_transport = zeros(size(stockICE));
trafficBEV_transport = zeros(size(stockICE));
trafficFC_transport = zeros(size(stockICE));

trafficShareICE_group = zeros(length(FleetPeriod), nGroupsFleet);
trafficShareBEV_group = zeros(size(trafficShareICE_group));
trafficShareFC_group = zeros(size(trafficShareICE_group));

%calculating traffic for Swedish trucks in fleet
for t=1:length(FleetPeriod)
    for j =1:nGroupsFleet-1

        %calclate annual traffic per age
        trafficICE_age(:,t,j) = stockICE(:,t,j).*AnnualMileage_Age;
        trafficBEV_age(:,t,j)= stockBEV(:,t,j).*AnnualMileage_Age;
        trafficFC_age(:,t,j)= stockFC(:,t,j).*AnnualMileage_Age;

        %calclate traffic per fleet group (no age differentiated mileage)
        trafficICE_fleet(t,j) = sum(stockICE(:,t,j))*AnnualMileage_Size(j);
        trafficBEV_fleet(t,j) = sum(stockBEV(:,t,j))*AnnualMileage_Size(j);
        trafficFC_fleet(t,j) = sum(stockFC(:,t,j))*AnnualMileage_Size(j);

    end % group j

    %adjust traffic by age for different size groups
    for j =1:nGroupsFleet-1
        trafficICE_age2(:,t,j)= trafficICE_fleet(t,j)*trafficICE_age(:,t,j)/sum(trafficICE_age(:,t,j));
        if sum(trafficBEV_age(:,t,j))>0
            trafficBEV_age2(:,t,j)= trafficBEV_fleet(t,j)*trafficBEV_age(:,t,j)/sum(trafficBEV_age(:,t,j));
        end
        if sum(trafficFC_age(:,t,j))>0
            trafficFC_age2(:,t,j)= trafficFC_fleet(t,j)*trafficFC_age(:,t,j)/sum(trafficFC_age(:,t,j));
        end

        %adjust to meet total supply (this is needed because number of
        %trucks is calculated from the Annual mileage by age, but we now
        %wants to use an everage mileage by size
    end
    for j =1:nGroupsFleet-1
        %calculate traffic share per technology and group
        trafficShareICE_group(t,j) = sum(trafficICE_age2(:,t,j))/...
            (sum(trafficICE_age2(:,t,:),"all") + sum(trafficBEV_age2(:,t,:),"all") + sum(trafficFC_age2(:,t,:),"all"));
        trafficShareBEV_group(t,j) = sum(trafficBEV_age2(:,t,j))/(sum(trafficICE_age2(:,t,:),"all") + sum(trafficBEV_age2(:,t,:),"all") + sum(trafficFC_age2(:,t,:),"all"));
        trafficShareFC_group(t,j) = sum(trafficFC_age2(:,t,j))/(sum(trafficICE_age2(:,t,:),"all") + sum(trafficBEV_age2(:,t,:),"all") + sum(trafficFC_age2(:,t,:),"all"));

        % scale to meet total domestic supply
        trafficICE_age3(:,t,j) = domesticTrafficDemand(t)*10^6*trafficShareICE_group(t,j)*trafficICE_age2(:,t,j)/sum(trafficICE_age2(:,t,j));

        if sum(trafficBEV_age2(:,t,j))>0
            trafficBEV_age3(:,t,j) = domesticTrafficDemand(t)*10^6*trafficShareBEV_group(t,j)*trafficBEV_age2(:,t,j)/sum(trafficBEV_age2(:,t,j));
        end
        if sum(trafficFC_age2(:,t,j))>0
            trafficFC_age3(:,t,j) = domesticTrafficDemand(t)*10^6*trafficShareFC_group(t,j)*trafficFC_age2(:,t,j)/sum(trafficFC_age2(:,t,j));
        end
    end %for each group j except last (foreign trucks)


    %add foreign traffic (assume same age distribution as 30-60t)
    trafficICE_age3(:,t,end) =foreignTraffic(t)*sum(trafficShareICE_group(t,:))*...
        trafficICE_age3(:,t,4)/sum(trafficICE_age3(:,t,4))*10^6;
    trafficBEV_age3(:,t,end) =foreignTraffic(t)*sum(trafficShareBEV_group(t,:))*...
        trafficICE_age3(:,t,4)/sum(trafficICE_age3(:,t,4))*10^6;
    trafficFC_age3(:,t,end) =foreignTraffic(t)*sum(trafficShareFC_group(t,:))*...
        trafficICE_age3(:,t,4)/sum(trafficICE_age3(:,t,4))*10^6;
end %period t


%move traffic from fleet groups to transport groups
for t=1:length(FleetPeriod)
    trafficICE_transport(:,t,:) = squeeze(trafficICE_age3(:,t,:))*transformationTable';
    trafficBEV_transport(:,t,:) = squeeze(trafficBEV_age3(:,t,:))*transformationTable';
    trafficFC_transport(:,t,:) = squeeze(trafficFC_age3(:,t,:))*transformationTable';
end


%% Part 2e: Plot fleet and traffic
run("PlotFleet.m")


%% PART 3: Calculate emissions
%SP = Stated policy, SD = Sustainable development background systems
EmissionPeriod = StartYearEmissions:EndYearEmissions;

%Vehicle cycle = ton CO2e/vehicle
%load Production data
VehicleCycle_Inputdata_CtG_SP=readmatrix('VehicleCycle.xlsx','Sheet',"Matlab_Stated",'Range',...
    strcat('B',num2str(StartYearEmissions-2000+4),':M',num2str(EndYearEmissions-2000+4))); %2019-2060
VehicleCycle_Inputdata_CtG_SD=readmatrix('VehicleCycle.xlsx','Sheet',"Matlab_Sustainable",'Range',...
    strcat('B',num2str(StartYearEmissions-2000+4),':M',num2str(EndYearEmissions-2000+4))); %2019-2060

%load Maintenance data
VehicleCycle_Inputdata_GtEOL_SP=readmatrix('VehicleCycle.xlsx','Sheet',"Matlab_Stated",'Range',...
    strcat('P',num2str(StartYearEmissions-2000+4),':AA',num2str(EndYearEmissions-2000+4))); %2019-2060
VehicleCycle_Inputdata_GtEOL_SD=readmatrix('VehicleCycle.xlsx','Sheet',"Matlab_Sustainable",'Range',...
    strcat('P',num2str(StartYearEmissions-2000+4),':AA',num2str(EndYearEmissions-2000+4))); %2019-2060

%load EOL data
VehicleCycle_Inputdata_EOL_SP=readmatrix('VehicleCycle.xlsx','Sheet',"Matlab_Stated",'Range',...
    strcat('AD',num2str(StartYearEmissions-2000+4),':AO',num2str(EndYearEmissions-2000+4))); %2019-2060
VehicleCycle_Inputdata_EOL_SD=readmatrix('VehicleCycle.xlsx','Sheet',"Matlab_Sustainable",'Range',...
    strcat('AD',num2str(StartYearEmissions-2000+4),':AO',num2str(EndYearEmissions-2000+4))); %2019-2060

%energy consumption = kWh/km
Tailpipe_inputdata_Energy=readmatrix('Tailpipe.xlsx','Sheet','Matlab_EnergyUse','Range','C5:Q120'); %1950-2065, imports all years as historical years needed
%Tailpipe_inputdata_Energy=readmatrix('Tailpipe.xlsx','Sheet','Matlab_FuelConsumption','Range','C5:AF120'); %1950-2065, imports all years as historical years needed
Tailpipe_inputdata_CO2e=readvars('Tailpipe.xlsx','Sheet','Matlab_LCA','Range','B3:B6');

% load fuel data
if fuelScenario == "Main"
    Fuel_shares=readvars('FuelScenario.xlsx','Sheet','Matlab','Range',strcat('B',num2str(StartYearEmissions-2000+3),':B',num2str(EndYearEmissions-2000+3)));% %2000-2065
elseif fuelScenario == "Stated"
    Fuel_shares=readvars('FuelScenario.xlsx','Sheet','Matlab','Range',strcat('C',num2str(StartYearEmissions-2000+3),':C',num2str(EndYearEmissions-2000+3)));% %2000-2065
elseif fuelScenario == "SwedishClimate"
    Fuel_shares=readvars('FuelScenario.xlsx','Sheet','Matlab','Range',strcat('D',num2str(StartYearEmissions-2000+3),':D',num2str(EndYearEmissions-2000+3)));% %2000-2065
end
%load WTT data
WellToTank_Inputdata_LCA_SP=readmatrix('WellToTank.xlsx','Sheet','Matlab_Stated','Range',...
    strcat('B',num2str(StartYearEmissions-2000+4),':E',num2str(EndYearEmissions-2000+4)));% LCA data for diesel, biofuels and electricity (column order)
WellToTank_Inputdata_LCA_SD=readmatrix('WellToTank.xlsx','Sheet','Matlab_Sustainable','Range',...
    strcat('B',num2str(StartYearEmissions-2000+4),':E',num2str(EndYearEmissions-2000+4)));% LCA data for diesel, biofuels and electricity (column order)


%% Part 3a Production, maintenance and EOL

% Prod
GHG_production_ICE_SP = zeros(nGroupsFleet,length(EmissionPeriod));
GHG_production_BEV_SP = zeros(size(GHG_production_ICE_SP));
GHG_production_FC_SP = zeros(size(GHG_production_ICE_SP));
GHG_production_ICE_SD = zeros(size(GHG_production_ICE_SP));
GHG_production_BEV_SD = zeros(size(GHG_production_ICE_SP));
GHG_production_FC_SD = zeros(size(GHG_production_ICE_SP));

for i=1:length(EmissionPeriod)
    for j=1:nGroupsFleet-1
        GHG_production_ICE_SP(j,i)=newICE(1,StartYearEmissions-StartYearFleet+i,j)*VehicleCycle_Inputdata_CtG_SP(i,j);
        GHG_production_BEV_SP(j,i)=newBEV(1,StartYearEmissions-StartYearFleet+i,j)*VehicleCycle_Inputdata_CtG_SP(i,j+4);
        GHG_production_FC_SP(j,i)=newFC(1,StartYearEmissions-StartYearFleet+i,j)*VehicleCycle_Inputdata_CtG_SP(i,j+8);

        GHG_production_ICE_SD(j,i)=newICE(1,StartYearEmissions-StartYearFleet+i,j)*VehicleCycle_Inputdata_CtG_SD(i,j);
        GHG_production_BEV_SD(j,i)=newBEV(1,StartYearEmissions-StartYearFleet+i,j)*VehicleCycle_Inputdata_CtG_SD(i,j+4);
        GHG_production_FC_SD(j,i)=newFC(1,StartYearEmissions-StartYearFleet+i,j)*VehicleCycle_Inputdata_CtG_SD(i,j+8);
    end %j in nFleetgroups
end %i in Emissionpeiod

%Maintenance %däckbyte år 6, år 12, år 18 samt år 24
GHG_maintenance_ICE_SP = zeros(nGroupsFleet,length(EmissionPeriod));
GHG_maintenance_BEV_SP = zeros(size(GHG_maintenance_ICE_SP));
GHG_maintenance_FC_SP = zeros(size(GHG_maintenance_ICE_SP));
GHG_maintenance_ICE_SD = zeros(size(GHG_maintenance_ICE_SP));
GHG_maintenance_BEV_SD = zeros(size(GHG_maintenance_ICE_SP));
GHG_maintenance_FC_SD = zeros(size(GHG_maintenance_ICE_SP));

for i=1:length(EmissionPeriod)
    for j=1:nGroupsFleet-1
        GHG_maintenance_ICE_SP(j,i)=(stockICE(6,StartYearEmissions-StartYearFleet+i,j) + stockICE(12,StartYearEmissions-StartYearFleet+i,j) +...
            stockICE(18,StartYearEmissions-StartYearFleet+i,j) + stockICE(24,StartYearEmissions-StartYearFleet+i,j))*VehicleCycle_Inputdata_GtEOL_SP(i,j);
        GHG_maintenance_BEV_SP(j,i)=(stockBEV(6,StartYearEmissions-StartYearFleet+i,j) + stockBEV(12,StartYearEmissions-StartYearFleet+i,j) +...
            stockBEV(18,StartYearEmissions-StartYearFleet+i,j) + stockBEV(24,StartYearEmissions-StartYearFleet+i,j))*VehicleCycle_Inputdata_GtEOL_SP(i,j+1);
        GHG_maintenance_FC_SP(j,i)=(stockFC(6,StartYearEmissions-StartYearFleet+i,j) + stockFC(12,StartYearEmissions-StartYearFleet+i,j) +...
            stockFC(18,StartYearEmissions-StartYearFleet+i,j) + stockFC(24,StartYearEmissions-StartYearFleet+i,j))*VehicleCycle_Inputdata_GtEOL_SP(i,j+4);

        GHG_maintenance_ICE_SD(j,i)=(stockICE(6,StartYearEmissions-StartYearFleet+i,j) + stockICE(12,StartYearEmissions-StartYearFleet+i,j) +...
            stockICE(18,StartYearEmissions-StartYearFleet+i,j) + stockICE(24,StartYearEmissions-StartYearFleet+i,j))*VehicleCycle_Inputdata_GtEOL_SD(i,j);
        GHG_maintenance_BEV_SD(j,i)=(stockBEV(6,StartYearEmissions-StartYearFleet+i,j) + stockBEV(12,StartYearEmissions-StartYearFleet+i,j) +...
            stockBEV(18,StartYearEmissions-StartYearFleet+i,j) + stockBEV(24,StartYearEmissions-StartYearFleet+i,j))*VehicleCycle_Inputdata_GtEOL_SD(i,j+1);
        GHG_maintenance_FC_SD(j,i)=(stockFC(6,StartYearEmissions-StartYearFleet+i,j) + stockFC(12,StartYearEmissions-StartYearFleet+i,j) +...
            stockFC(18,StartYearEmissions-StartYearFleet+i,j) + stockFC(24,StartYearEmissions-StartYearFleet+i,j))*VehicleCycle_Inputdata_GtEOL_SD(i,j+4);
    end %j in nFleetGroups
end %i in Emission period

% EOL
GHG_EOL_ICE_SP = zeros(nGroupsFleet,length(EmissionPeriod));
GHG_EOL_BEV_SP = zeros(size(GHG_maintenance_ICE_SP));
GHG_EOL_FC_SP = zeros(size(GHG_maintenance_ICE_SP));
GHG_EOL_ICE_SD = zeros(size(GHG_maintenance_ICE_SP));
GHG_EOL_BEV_SD = zeros(size(GHG_maintenance_ICE_SP));
GHG_EOL_FC_SD = zeros(size(GHG_maintenance_ICE_SP));

for i= 1:length(EmissionPeriod)
    for j=1:nGroupsFleet-1
        GHG_EOL_ICE_SP(j,i)=sum(scrappedICE(:,StartYearEmissions-StartYearFleet+i,j))*VehicleCycle_Inputdata_EOL_SP(i,j);
        GHG_EOL_BEV_SP(j,i)=sum(scrappedBEV(:,StartYearEmissions-StartYearFleet+i,j))*VehicleCycle_Inputdata_EOL_SP(i,j+1);
        GHG_EOL_FC_SP(j,i)=sum(scrappedFC(:,StartYearEmissions-StartYearFleet+i,j))*VehicleCycle_Inputdata_EOL_SP(i,j+4);

        GHG_EOL_ICE_SD(j,i)=sum(scrappedICE(:,StartYearEmissions-StartYearFleet+i,j))*VehicleCycle_Inputdata_EOL_SD(i,j);
        GHG_EOL_BEV_SD(j,i)=sum(scrappedBEV(:,StartYearEmissions-StartYearFleet+i,j))*VehicleCycle_Inputdata_EOL_SD(i,j+1);
        GHG_EOL_FC_SD(j,i)=sum(scrappedFC(:,StartYearEmissions-StartYearFleet+i,j))*VehicleCycle_Inputdata_EOL_SD(i,j+4);

    end % j in nGroupsFleet
end % i in emission period


%% Part 3b Use phase - TTW

%%% ENERGY consumption
% Annual fuel consumption in kWh .
EnergyConsumptionTotal=zeros(3,length(EmissionPeriod)); % ROW 1:ICE, 2:Electric, 3:Hydrogen. Column: Year

% ICE
EnergyConsumption_ICE=zeros(VehicleAgeSpan,length(EmissionPeriod),nGroupsTransport); %Annual energy use
for year = EmissionPeriod
    for age=1:VehicleAgeSpan+1
        efficiencyYear=year-age-1948; %Index for manufacture year

        %calculate for each transport group
        EnergyConsumption_ICE(age,year-StartYearEmissions+1,1)=trafficICE_transport(age,year-StartYearFleet+1,1)*Tailpipe_inputdata_Energy(efficiencyYear,1); %Fuel consumption for each vehicle age, weight class and lorries running empty
        EnergyConsumption_ICE(age,year-StartYearEmissions+1,2)=trafficICE_transport(age,year-StartYearFleet+1,2)*Tailpipe_inputdata_Energy(efficiencyYear,2);
        EnergyConsumption_ICE(age,year-StartYearEmissions+1,3)=trafficICE_transport(age,year-StartYearFleet+1,3)*Tailpipe_inputdata_Energy(efficiencyYear,3);
        EnergyConsumption_ICE(age,year-StartYearEmissions+1,4)=trafficICE_transport(age,year-StartYearFleet+1,4)*Tailpipe_inputdata_Energy(efficiencyYear,4);
        EnergyConsumption_ICE(age,year-StartYearEmissions+1,5)=trafficICE_transport(age,year-StartYearFleet+1,5)*Tailpipe_inputdata_Energy(efficiencyYear,5);

    end %age
    EnergyConsumptionTotal(1,year-StartYearEmissions+1)=sum(EnergyConsumption_ICE(:,year-StartYearEmissions+1,:),"all"); % Sums up and saves total yearly fuel consumption for ICE
end %i

% BEV
EnergyConsumption_BEV=zeros(size(EnergyConsumption_ICE)); %Annual energy use
for year = EmissionPeriod
    for age=1:VehicleAgeSpan+1
        efficiencyYear=year-age-1948; %Index for manufacture year

        %calculate for each transport group
        EnergyConsumption_BEV(age,year-StartYearEmissions+1,1)=trafficBEV_transport(age,year-StartYearFleet+1,1)*Tailpipe_inputdata_Energy(efficiencyYear,6); %Fuel consumption for each vehicle age, weight class and lorries running empty
        EnergyConsumption_BEV(age,year-StartYearEmissions+1,2)=trafficBEV_transport(age,year-StartYearFleet+1,2)*Tailpipe_inputdata_Energy(efficiencyYear,7);
        EnergyConsumption_BEV(age,year-StartYearEmissions+1,3)=trafficBEV_transport(age,year-StartYearFleet+1,3)*Tailpipe_inputdata_Energy(efficiencyYear,8);
        EnergyConsumption_BEV(age,year-StartYearEmissions+1,4)=trafficBEV_transport(age,year-StartYearFleet+1,4)*Tailpipe_inputdata_Energy(efficiencyYear,9);
        EnergyConsumption_BEV(age,year-StartYearEmissions+1,5)=trafficBEV_transport(age,year-StartYearFleet+1,5)*Tailpipe_inputdata_Energy(efficiencyYear,10);

    end %age
    EnergyConsumptionTotal(2,year-StartYearEmissions+1)=sum(EnergyConsumption_BEV(:,year-StartYearEmissions+1,:),"all"); % Sums up and saves total yearly fuel consumption for BEVs
end %i

% FC
EnergyConsumption_FC=zeros(size(EnergyConsumption_ICE)); %Annual energy use
for year = EmissionPeriod
    for age=1:VehicleAgeSpan+1
        efficiencyYear=year-age-1948; %Index for manufacture year

        %calculate for each transport group
        EnergyConsumption_FC(age,year-StartYearEmissions+1,1)=trafficFC_transport(age,year-StartYearFleet+1,1)*Tailpipe_inputdata_Energy(efficiencyYear,11); %Fuel consumption for each vehicle age, weight class and lorries running empty
        EnergyConsumption_FC(age,year-StartYearEmissions+1,2)=trafficFC_transport(age,year-StartYearFleet+1,2)*Tailpipe_inputdata_Energy(efficiencyYear,12);
        EnergyConsumption_FC(age,year-StartYearEmissions+1,3)=trafficFC_transport(age,year-StartYearFleet+1,3)*Tailpipe_inputdata_Energy(efficiencyYear,13);
        EnergyConsumption_FC(age,year-StartYearEmissions+1,4)=trafficFC_transport(age,year-StartYearFleet+1,4)*Tailpipe_inputdata_Energy(efficiencyYear,14);
        EnergyConsumption_FC(age,year-StartYearEmissions+1,5)=trafficFC_transport(age,year-StartYearFleet+1,5)*Tailpipe_inputdata_Energy(efficiencyYear,15);

    end

    EnergyConsumptionTotal(3,year-StartYearEmissions+1)=sum(EnergyConsumption_FC(:,year-StartYearEmissions+1,:),"all"); % Sums up and saves total yearly fuel consumption for fuel cell

end


%Fossil vs non-fossil fuel consumption (in kWh)
Biofuel_FC=zeros(1,length(EmissionPeriod)); % To save biofuel consumption for plots in other m-files
FossilFuel_FC=zeros(1,length(EmissionPeriod));% To save fossil fuel consumption for plots in other m-files

for i=1:length(EmissionPeriod)
    Biofuel_FC(1,i)=EnergyConsumptionTotal(1,i)*Fuel_shares(i);
    FossilFuel_FC(1,i)=EnergyConsumptionTotal(1,i)*(1-Fuel_shares(i));
end

% GHG emissions in ton
Tailpipe_GHG=zeros(1,length(EmissionPeriod)); % Matrix for tailpipe GHG emission from diesel usage (and non-CO2 from biofuels)
for i=1:length(EmissionPeriod)
    Tailpipe_GHG(1,i)=FossilFuel_FC(1,i)*Tailpipe_inputdata_CO2e(1)/10^6 + Biofuel_FC(1,i)*Tailpipe_inputdata_CO2e(2)/10^6;
end


%% Part 3c Use phase - WTT

%in tonnes
WellToTank_GHG_SP=zeros(4,length(EmissionPeriod)); %Matrix for GHG emission from well to tank. Row 1: Diesel, 2: Biofuels, 3: Electricity, 4: Hydrogen
WellToTank_GHG_SD=zeros(4,length(EmissionPeriod)); %Matrix for GHG emission from well to tank. Row 1: Diesel, 2: Biofuels, 3: Electricity, 4: Hydrogen

for i=1:length(EmissionPeriod)
    WellToTank_GHG_SP(1,i)=FossilFuel_FC(1,i)*WellToTank_Inputdata_LCA_SP(i,1)/10^6; %diesel
    WellToTank_GHG_SP(2,i)=Biofuel_FC(1,i)*WellToTank_Inputdata_LCA_SP(i,2)/10^6; %biofuels
    WellToTank_GHG_SP(3,i)=EnergyConsumptionTotal(2,i)*WellToTank_Inputdata_LCA_SP(i,3)/10^6; %electricity
    WellToTank_GHG_SP(4,i)=EnergyConsumptionTotal(3,i)*WellToTank_Inputdata_LCA_SP(i,4)/10^6; %hydrogen

    WellToTank_GHG_SD(1,i)=FossilFuel_FC(1,i)*WellToTank_Inputdata_LCA_SD(i,1)/10^6; %diesel
    WellToTank_GHG_SD(2,i)=Biofuel_FC(1,i)*WellToTank_Inputdata_LCA_SD(i,2)/10^6; %biofuels
    WellToTank_GHG_SD(3,i)=EnergyConsumptionTotal(2,i)*WellToTank_Inputdata_LCA_SD(i,3)/10^6; %electricity
    WellToTank_GHG_SD(4,i)=EnergyConsumptionTotal(3,i)*WellToTank_Inputdata_LCA_SD(i,4)/10^6; %hydrogen
end


%% Part 4: Plot and save results


%subset results for plots, only every X years
yearDensity =5;
indexYearsFleet = (mod(FleetPeriod,yearDensity)== 0).*FleetPeriod>=StartYearEmissions;
indexYearsEmissions =mod(EmissionPeriod,yearDensity)== 0;
fuelCycle_GHG_SP = sum(WellToTank_GHG_SP,1);
fuelCycle_GHG_SD = sum(WellToTank_GHG_SD,1);

vehicle_GHG_SP_ICE = sum(GHG_production_ICE_SP,1) + sum(GHG_maintenance_ICE_SP,1) + sum(GHG_EOL_ICE_SP,1);
vehicle_GHG_SD_ICE = sum(GHG_production_ICE_SD,1) + sum(GHG_maintenance_ICE_SD,1) + sum(GHG_EOL_ICE_SD,1);
vehicle_GHG_SP_BEV = sum(GHG_production_BEV_SP,1) + sum(GHG_maintenance_BEV_SP,1) + sum(GHG_EOL_BEV_SP,1);
vehicle_GHG_SD_BEV = sum(GHG_production_BEV_SD,1) + sum(GHG_maintenance_BEV_SD,1) + sum(GHG_EOL_BEV_SD,1);
vehicle_GHG_SP_FC = sum(GHG_production_FC_SP,1) + sum(GHG_maintenance_FC_SP,1) + sum(GHG_EOL_FC_SP,1);
vehicle_GHG_SD_FC = sum(GHG_production_FC_SD,1) + sum(GHG_maintenance_FC_SD,1) + sum(GHG_EOL_FC_SD,1);
vehicle_GHG_SP =  vehicle_GHG_SP_ICE + vehicle_GHG_SP_BEV+ vehicle_GHG_SP_FC;
vehicle_GHG_SD =  vehicle_GHG_SD_ICE + vehicle_GHG_SD_BEV+ vehicle_GHG_SD_FC;

total_GHG_SP_ICE = Tailpipe_GHG + sum(WellToTank_GHG_SP(1:2,:),1) + vehicle_GHG_SP_ICE;
total_GHG_SD_ICE = Tailpipe_GHG + sum(WellToTank_GHG_SD(1:2,:),1) + vehicle_GHG_SD_ICE;
total_GHG_SP_BEV = sum(WellToTank_GHG_SP(3,:),1) + vehicle_GHG_SP_BEV;
total_GHG_SD_BEV = sum(WellToTank_GHG_SD(3,:),1) + vehicle_GHG_SD_BEV;
total_GHG_SP_FC = sum(WellToTank_GHG_SP(4,:),1) + vehicle_GHG_SP_FC;
total_GHG_SD_FC = sum(WellToTank_GHG_SD(4,:),1) + vehicle_GHG_SD_FC;
total_GHG_SP = Tailpipe_GHG + fuelCycle_GHG_SP + vehicle_GHG_SP;
total_GHG_SD = Tailpipe_GHG +  fuelCycle_GHG_SD + vehicle_GHG_SD;


% Save .mat file with variables
if writeResults==1
    folderPath = "C:\Users\cecilia0899\OneDrive - Chalmers\Cecilia PhD files\Paper 2 - EV trucks\Code\Results";

    saveName = strcat(folderPath,"\","Tech-"+techScenario+",Traffic-"+trafficScenario+",Fuel-"+fuelScenario+".mat");
    save(saveName, "EmissionPeriod", "FleetPeriod", "StartYearEmissions", "EndYearEmissions", "StartYearFleet", "EndYearFleet", "indexYearsFleet", "indexYearsEmissions",...
        "Biofuel_FC", "FossilFuel_FC", "EnergyConsumptionTotal", "Fuel_shares",...
        "BEVshareZEVs","nBEV","nFC", "nZEV", "nICE", "newBEV", "newFC", "newZEV", "newICE", "totalFleetSize",...
        "stockBEV","stockFC","stockICE",...
        "trafficICE_transport",...
        "fuelCycle_GHG_SP", "fuelCycle_GHG_SD", "Tailpipe_GHG", "total_GHG_SP", "total_GHG_SD", "vehicle_GHG_SP","vehicle_GHG_SD")


    %save xls-files with tables
    folderPath = "C:\Users\cecilia0899\OneDrive - Chalmers\Cecilia PhD files\Paper 2 - EV trucks\Code\Results";

    if techScenario=="Main" && trafficScenario=="Main" && fuelScenario=="Main"
        header=electrificationData(1,1:5);
        tableYears = cell2mat(electrificationData(2:end,1));
        indexTableYears = find(tableYears==2025 | tableYears==2030 | tableYears==2035 | tableYears==2040);
        tableYears = string(tableYears(indexTableYears));
        table = 1-BEVshareZEVs(indexTableYears,1:4);
        table = [tableYears,table];
        table = [header; table];
        writematrix(table, fullfile(folderPath,"table6.xls"));


        temp =["";TransportTruckGroupDescription(1:4)];
        table = [string(FleetTruckGroupDescription(1:4)');
            transformationTable(1:4,1:4)];
        table = [temp, table];
        writematrix(table, fullfile(folderPath,"tableSM4.xls"));

        header=electrificationData(1,1:5);
        tableYears = cell2mat(electrificationData(2:end,1));
        indexTableYears = find(tableYears==2023 | tableYears==2025 | tableYears==2030 | tableYears==2035 | tableYears==2040);
        tableYears = string(tableYears(indexTableYears));
        table = ZEVRates(indexTableYears,1:4);
        table = [tableYears,table];
        table = [header; table];
        writematrix(table, fullfile(folderPath,"tableSM6.xls"));
    end

    if techScenario=="Main" && fuelScenario=="Main"
        header=[FleetPeriod(indexYearsFleet)];
        tableYears = cell2mat(electrificationData(2:end,1));
        table = [plotNew(indexYearsFleet); nICE(indexYearsFleet) + nZEV(indexYearsFleet)];
        table = [header; table];
        tableName = strcat("tableSM9-",trafficScenario,".xls");
        writematrix(table, fullfile(folderPath,tableName));
    end
end

run("PlotResults.m")

%save figures
if writeResults==1

    if techScenario=="Main" && trafficScenario=="Main" && fuelScenario=="Main"
        folderPath = "C:\Users\cecilia0899\OneDrive - Chalmers\Cecilia PhD files\Paper 2 - EV trucks\Figures";
        %saveas(figureSM2,fullfile(folderPath,"FigureSM2"),"tiff")
        saveas(figureSM3,fullfile(folderPath,"FigureSM3"),"tiff")
        saveas(figureSM4,fullfile(folderPath,"FigureSM4"),"tiff")
        saveas(figure5,fullfile(folderPath,"Figure5"),"tiff")
        saveas(figure6,fullfile(folderPath,"Figure6"),"tiff")
        saveas(figure7,fullfile(folderPath,"Figure7"),"tiff")
        saveas(figure8,fullfile(folderPath,"Figure8"),"tiff")
    end

    %save xls-file with data used in paper
    folderPath = "C:\Users\cecilia0899\OneDrive - Chalmers\Cecilia PhD files\Paper 2 - EV trucks\Code\Results";
    table = ["Cum. CO2 total, SP ",EndYearEmissions, sum(cumEmissionsSP(:,end),1)/10^6,"Mton. ", "","";
        "Cum. CO2 total, SD ",EndYearEmissions, sum(cumEmissionsSD(:,end),1)/10^6,"Mton. ","","";
        "Cum. CO2 total, SP vs SD ",EndYearEmissions, ...
        (sum(cumEmissionsSP(:,end),1)-sum(cumEmissionsSD(:,end),1))/10^6,"Mton. ",(sum(cumEmissionsSP(:,end),1)-sum(cumEmissionsSD(:,end),1))/sum(cumEmissionsSP(:,end),1)*100,"%";
        "Cum. CO2 fuels, SP vs SD ",EndYearEmissions,(cumFuelSP(end)-cumFuelSD(end))/10^6,"Mton. ",(cumFuelSP(end)-cumFuelSD(end))/cumFuelSP(end)*100,"%";
        "Cum. CO2 vehicle, SP vs SD ",EndYearEmissions,(cumVehicleSP(end)-cumVehicleSD(end))/10^6,"Mton. ",(cumVehicleSP(end)-cumVehicleSD(end))/cumVehicleSP(end)*100,"%"];
    tableName = strcat("numbersToReport-","Tech-"+techScenario+",Traffic-"+trafficScenario+",Fuel-"+fuelScenario,".xls");
    writematrix(table, fullfile(folderPath,tableName));
end

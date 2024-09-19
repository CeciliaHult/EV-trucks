clc;
clear;
close all;
TODO list
% 1. säkerställ att fleetmodule fungerar korrekt, antalet ZEV trucks för de
% lätta viktklasserna minskar i slutet på prognosen

% Nu heter scenariot Biofuels, gör om till LowCarbonfuel eller liknande för
% att öppna för olika typer av fossilfria bränslen.

% Gör om Mileage input data så att tidsserien inkluderas + Gör om formatet
%ladda tidsserien även för freigth demand?

%% Part 0: Set scope and variables

plotScope = 0; % 1 if all graphs are to be plotted and 0 if only selected result graphs
currentYear=2022; %year for plotting data etc. Available: 2001-2023
VehicleAgeSpan=30;% number of model years to include in model.

StartYearFleet = 2001; %>=2001 (data tillgängligt från 2001)
EndYearFleet = 2060;
ForecastMethod = 2; % 1= Constant fleet growth rate derived from data, 2= new vehicles supplied by delta in transport demand

StartYearEmissions = 2020;
EndYearEmissions =2060;

techScenario ="Main"; % Main = BEV&FC, noZEV= only ICE, noFC = only BEVs as ZEVs
fuelScenario = "Main"; %Main = 100% renewable in 2050, Stated = Swedish staed policy, SwedishClimate = 100% renewable in 2045
trafficScenario = "Main"; % Main = TrV basprognos, Low = lower scenario 
lowTransportDemandGrowthRate = 0.8; %how much slower transport demand grows compared to main


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
TransportTruckGroupsTKM = [0; %swedish non-freight trucks
    sum(TransportWeightClassesTKM(1:3)/1000); %3.5-29.9t
    sum(TransportWeightClassesTKM(4:6)/1000); %30-59.9t;
    sum(TransportWeightClassesTKM(7:8)/1000); %>=60t
    readvars('TransportDemand.xlsx','Sheet','Matlab','Range','J12:J12')]; %foreign trucks
TransportTruckGroupsKM = [readvars('TransportDemand.xlsx','Sheet','Matlab','Range','G12:G12'); %swedish non-freight trucks
    sum(TransportWeightClassesKM(1:3)/1000); %3.5-29.9t
    sum(TransportWeightClassesKM(4:6)/1000); %30-59.9t;
    sum(TransportWeightClassesKM(7:8)/1000); %>=60t
    readvars('TransportDemand.xlsx','Sheet','Matlab','Range','H12:H12')]; %foreign trucks
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
%FleetGrowthRate = 1.0057; %(average between 2001-2023):
%FleetGrowthRate = 1.0088; %(average between 2014-2023):
%FleetGrowthRate = 1.0128; %(ökningstakt trafikarbete enligt basprognos 2024):
FleetGrowthRate = 1.0085; %(historisk korrelation TA-ökning och fordonsökning kombinerat med ökning av TA enligt baspronos):

% Read electrification rates + set share of BEVs of ZEVs
electrificationData=readcell('ElectrificationFleetTruckGroup.xlsx','Sheet','ZEV_shares','Range','A1:F96');  %1971-2065
ZEVRates = cell2mat(electrificationData(2:end,2:6)); % share of new ZEVs per fleet group every year.
BEVdata = readcell('ElectrificationFleetTruckGroup.xlsx','Sheet','BEV_shares','Range','A1:F96'); %1971-2065
BEVshareZEVs = cell2mat(BEVdata(2:end,2:6)); % share of new ZEVs that are BEVs per fleet group every year.

if techScenario =="noZEV"
    ZEVRates = zeros(size(ZEVRates));
end

%Cleaned Gauss from ScrappingCurveFitting
%General model Gauss1:
%gaussClean(x) =  a1*exp(-((x-b1)/c1)^2)
%Coefficients (with 95% confidence bounds):
a1 =      0.2341;  %(0.2206, 0.2475)
b1 =       17.77;  %(17.34, 18.21)
c1 =       9.252;  %(8.607, 9.897)
x = 0:VehicleAgeSpan;
scrappingProbabilities = a1*exp(-((x-b1)/c1).^2);


%% Part 2a: Transport demand forecasting

%Import forecast data from excel
ImportRowsTransport= strcat('B',num2str(StartYearFleet-2000+2),':B',num2str(2+EndYearFleet-2000));
ImportRowsTraffic= strcat('C',num2str(StartYearFleet-2000+2),':C',num2str(2+EndYearFleet-2000));
ImportRowsForeignTraffic = strcat('H',num2str(StartYearFleet-2000+2),':H',num2str(2+EndYearFleet-2000));

TransportDemand_Inputdata=readvars('TransportDemand.xlsx','Sheet','Matlab','Range',ImportRowsTransport);%Imports annual transport demand
TrafficDemand_Inputdata=readvars('TransportDemand.xlsx','Sheet','Matlab','Range',ImportRowsTraffic);%Imports annual travel demand
foreignTraffic = readvars('TransportDemand.xlsx','Sheet','Matlab','Range',ImportRowsForeignTraffic);
domesticTrafficDemand = TrafficDemand_Inputdata-foreignTraffic;

SamgodsForecast = readcell('TransportDemand.xlsx','Sheet','Basprognos','Range','A1:M28');
samgodsTraffic =cell2mat(SamgodsForecast(2:28,3:6))/10^3; %Mfkm
samgodsTransport = cell2mat(SamgodsForecast(2:28,9:12))/10^6; %Gtkm

% Calculate total demand scenario
TransportDemand=zeros(nGroupsTransport,length(FleetPeriod));
TrafficDemand=zeros(nGroupsTransport,length(FleetPeriod));
for j = 1:nGroupsTransport
    for i=1:length(FleetPeriod) %Loop for creating a column for travel demand with the length of the set time horizon
        TransportDemand(j,i)=TransportDemand_Inputdata(i,1)*TransportTruckGroupsTKM(j)/sum(TransportTruckGroupsTKM);
        TrafficDemand(j,i)=TrafficDemand_Inputdata(i,1)*TransportTruckGroupsKM(j)/sum(TransportTruckGroupsKM);(j);

        if (trafficScenario=="Low" && (i+StartYearFleet-currentYear)>0)
            TransportDemand(j,i)=TransportDemand(j,i-1)*((FleetGrowthRate-1)*lowTransportDemandGrowthRate+1)*TransportTruckGroupsTKM(j)/sum(TransportTruckGroupsTKM);
            TrafficDemand(j,i)=TrafficDemand(j,i-1)*((FleetGrowthRate-1)*lowTransportDemandGrowthRate+1)*TransportTruckGroupsKM(j)/sum(TransportTruckGroupsKM);(j);
        end %endif
    end
end



%% NOT CURRENTLY USED. Part 2c Transport electric demand forecasting

%ev. electrification rates för efterfrågan på ZEV transporter

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
for i = 2:length(FleetPeriod)

    if ForecastMethod==1
        totalFleetSize(i)= totalFleetSize(i-1)*FleetGrowthRate;
    end

    tempStockICE = squeeze(stockICE(:,i-1,:));
    tempStockZEV = squeeze(stockZEV(:,i-1,:));

    % calculate fleet turnover for domestic trucks
    [stockICE(:,i,:), scrappedICE(:,i,:), newICE(:,i,:), stockZEV(:,i,:), scrappedZEV(:,i,:), newZEV(:,i,:)] = ...
        FleetTurnoverModel(ForecastMethod,tempStockICE, tempStockZEV, scrappingProbabilities, AnnualMileage_Age, totalFleetSize(i), ZEVRates(i+(StartYearFleet-1971),:),domesticTrafficDemand(i)*10^6);

    if ForecastMethod==2
        totalFleetSize(i) = sum(stockICE(:,i,:),"all") + sum(stockZEV(:,i,:),"all");
    end

    %allocate ZEV into BEV and FC
    if techScenario == "noFC"
        BEVshareZEVs(:,:) = 1;
    end
    newBEV(1,i,:) = squeeze(newZEV(1,i,:))'.*BEVshareZEVs(i+(StartYearFleet-1971),:);
    newFC(1,i,:) = newZEV(1,i,:) - newBEV(1,i,:);

    %divide ZEV stock into BEV and FC
    for j=1:nGroupsFleet
        stockBEV(:,i,j) = stockZEV(:,i,j).*flip(BEVshareZEVs(i+(StartYearFleet-1971)-VehicleAgeSpan:i+(StartYearFleet-1971),j));
        stockFC(:,i,j) = stockZEV(:,i,j) - stockBEV(:,i,j);
        scrappedBEV(:,i,j) = scrappedZEV(:,i,j).*flip(BEVshareZEVs(i+(StartYearFleet-1971)-VehicleAgeSpan:i+(StartYearFleet-1971),j)); 
        scrappedFC(:,i,j) = scrappedZEV(:,i,j) - scrappedBEV(:,i,j);
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

%Plots are moved to PlotFleet.m

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

%calculating traffic for trucks in fleet
for j=1:length(FleetPeriod)
    for i =1:nGroupsFleet-1

        %calclate annual traffic per fleet group
        trafficICE_fleet(j,i) = sum(stockICE(:,j,i))*AnnualMileage_Size(i);
        trafficBEV_fleet(j,i) = sum(stockBEV(:,j,i))*AnnualMileage_Size(i);
        trafficFC_fleet(j,i) = sum(stockFC(:,j,i))*AnnualMileage_Size(i);

        %calclate annual traffic per age
        trafficICE_age(:,j,i) = stockICE(:,j,i).*AnnualMileage_Age;
        trafficBEV_age(:,j,i)= stockBEV(:,j,i).*AnnualMileage_Age;
        trafficFC_age(:,j,i)= stockFC(:,j,i).*AnnualMileage_Age;
    end %

    for i =1:nGroupsFleet-1
        %scale total traffic to fleet groups, not by Mileage by age
        trafficICE_age2(:,j,i) = trafficICE_fleet(j,i)*trafficICE_age(:,j,i)/sum(trafficICE_age(:,j,i));
        if sum(trafficBEV_age(:,j,i))>0
            trafficBEV_age2(:,j,i)= trafficBEV_fleet(j,i)*trafficBEV_age(:,j,i)/sum(trafficBEV_age(:,j,i));
        end
        if sum(trafficFC_age(:,j,i))>0
            trafficFC_age2(:,j,i)= trafficFC_fleet(j,i)*trafficFC_age(:,j,i)/sum(trafficFC_age(:,j,i));
        end
    end %group i

    for i =1:nGroupsFleet-1
    %calculate traffic share per technology and group
    trafficShareICE_group(j,i) = sum(trafficICE_age2(:,j,i))/...
        (sum(trafficICE_age2(:,j,:),"all") + sum(trafficBEV_age2(:,j,:),"all") + sum(trafficFC_age2(:,j,:),"all"));
    trafficShareBEV_group(j,i) = sum(trafficBEV_age2(:,j,i))/(sum(trafficICE_age2(:,j,:),"all") + sum(trafficBEV_age2(:,j,:),"all") + sum(trafficFC_age2(:,j,:),"all"));
    trafficShareFC_group(j,i) = sum(trafficFC_age2(:,j,i))/(sum(trafficICE_age2(:,j,:),"all") + sum(trafficBEV_age2(:,j,:),"all") + sum(trafficFC_age2(:,j,:),"all"));

       % scale to meet total domestic supply
        trafficICE_age3(:,j,i) = domesticTrafficDemand(j)*10^6*trafficShareICE_group(j,i)*trafficICE_age2(:,j,i)/sum(trafficICE_age2(:,j,i));

        if sum(trafficBEV_age2(:,j,i))>0
            trafficBEV_age3(:,j,i) = domesticTrafficDemand(j)*10^6*trafficShareBEV_group(j,i)*trafficBEV_age2(:,j,i)/sum(trafficBEV_age2(:,j,i));
        end
        if sum(trafficFC_age2(:,j,i))>0
            trafficFC_age3(:,j,i) = domesticTrafficDemand(j)*10^6*trafficShareFC_group(j,i)*trafficFC_age2(:,j,i)/sum(trafficFC_age2(:,j,i));
        end
    end %for each group except last (foreign trucks)


    %add foreign traffic (assume same age distribution as 30-60t)
    trafficICE_age3(:,j,end) =foreignTraffic(j)*sum(trafficShareICE_group(j,:))*...
        trafficICE_age3(:,j,4)/sum(trafficICE_age3(:,j,4))*10^6;
    trafficBEV_age3(:,j,end) =foreignTraffic(j)*sum(trafficShareBEV_group(j,:))*...
        trafficICE_age3(:,j,4)/sum(trafficICE_age3(:,j,4))*10^6;
    trafficFC_age3(:,j,end) =foreignTraffic(j)*sum(trafficShareFC_group(j,:))*...
        trafficICE_age3(:,j,4)/sum(trafficICE_age3(:,j,4))*10^6;
end %period i


%move traffic from fleet groups to transport groups
for j=1:length(FleetPeriod)
    trafficICE_transport(:,j,:) = squeeze(trafficICE_age3(:,j,:))*transformationTable';
    trafficBEV_transport(:,j,:) = squeeze(trafficBEV_age3(:,j,:))*transformationTable';
    trafficFC_transport(:,j,:) = squeeze(trafficFC_age3(:,j,:))*transformationTable';  
end
%% Part 2e: Plot fleet and traffic
run("PlotFleet.m")

%% PART 3: Calculate emissions
%SP = Stated policy, SD = Sustainable development background systems
EmissionPeriod = StartYearEmissions:EndYearEmissions;

%Vehicle cycle = ton CO2e/vehicle
%load Production data
VehicleCycle_Inputdata_CtG_SP=readmatrix('VehicleCycle.xlsx','Sheet',"Matlab_Stated",'Range',strcat('B',num2str(StartYearEmissions-2000+4),':M',num2str(EndYearEmissions-2000+4))); %2019-2060
VehicleCycle_Inputdata_CtG_SD=readmatrix('VehicleCycle.xlsx','Sheet',"Matlab_Sustainable",'Range',strcat('B',num2str(StartYearEmissions-2000+4),':M',num2str(EndYearEmissions-2000+4))); %2019-2060

%load Maintenance data
VehicleCycle_Inputdata_GtEOL_SP=readmatrix('VehicleCycle.xlsx','Sheet',"Matlab_Stated",'Range',strcat('P',num2str(StartYearEmissions-2000+4),':AA',num2str(EndYearEmissions-2000+4))); %2019-2060
VehicleCycle_Inputdata_GtEOL_SD=readmatrix('VehicleCycle.xlsx','Sheet',"Matlab_Sustainable",'Range',strcat('P',num2str(StartYearEmissions-2000+4),':AA',num2str(EndYearEmissions-2000+4))); %2019-2060

%load EOL data
VehicleCycle_Inputdata_EOL_SP=readmatrix('VehicleCycle.xlsx','Sheet',"Matlab_Stated",'Range',strcat('AD',num2str(StartYearEmissions-2000+4),':AO',num2str(EndYearEmissions-2000+4))); %2019-2060
VehicleCycle_Inputdata_EOL_SD=readmatrix('VehicleCycle.xlsx','Sheet',"Matlab_Sustainable",'Range',strcat('AD',num2str(StartYearEmissions-2000+4),':AO',num2str(EndYearEmissions-2000+4))); %2019-2060

%energy consumption = kWh/km
%load tailpipe data
Tailpipe_inputdata_Energy=readmatrix('Tailpipe.xlsx','Sheet','Matlab_FuelConsumption','Range','C5:AF120'); %Imports energy consumption data for ICE and Electric divided in weight classes and loaded/emtpy running. See excel file for more info
Tailpipe_inputdata_CO2e=readvars('Tailpipe.xlsx','Sheet','Matlab_LCA','Range','B3:B6');

% load fuel data
Fuel_shares=readvars('BiofuelScenario.xlsx','Sheet','Matlab','Range','B3:B68');% Column vector for shares of biofuels

%load WTT data
WellToTank_Inputdata_LCA_SP=readmatrix('WellToTank.xlsx','Sheet','Matlab_Stated','Range', strcat('B',num2str(StartYearEmissions-2000+4),':E',num2str(EndYearEmissions-2000+4)));% LCA data for diesel, biofuels and electricity (column order)
WellToTank_Inputdata_LCA_SD=readmatrix('WellToTank.xlsx','Sheet','Matlab_Sustainable','Range', strcat('B',num2str(StartYearEmissions-2000+4),':E',num2str(EndYearEmissions-2000+4)));% LCA data for diesel, biofuels and electricity (column order)

%% Part 3a Production, maintenance and EOL

% Prod
GHG_production_ICE_SP = zeros(nGroupsFleet,length(EmissionPeriod));
GHG_production_BEV_SP = zeros(size(GHG_production_ICE_SP));
GHG_production_FC_SP = zeros(size(GHG_production_ICE_SP));
GHG_production_ICE_SD = zeros(size(GHG_production_ICE_SP));
GHG_production_BEV_SD = zeros(size(GHG_production_ICE_SP));
GHG_production_FC_SD = zeros(size(GHG_production_ICE_SP));

for i=EmissionPeriod
    GHG_production_ICE_SP(1,i-StartYearEmissions+1)=newICE(1,i-StartYearFleet+1,1)*VehicleCycle_Inputdata_CtG_SP(i-StartYearEmissions+1,1);
    GHG_production_ICE_SP(2,i-StartYearEmissions+1)=newICE(1,i-StartYearFleet+1,2)*VehicleCycle_Inputdata_CtG_SP(i-StartYearEmissions+1,2);
    GHG_production_ICE_SP(3,i-StartYearEmissions+1)=newICE(1,i-StartYearFleet+1,3)*VehicleCycle_Inputdata_CtG_SP(i-StartYearEmissions+1,3);
    GHG_production_ICE_SP(4,i-StartYearEmissions+1)=newICE(1,i-StartYearFleet+1,4)*VehicleCycle_Inputdata_CtG_SP(i-StartYearEmissions+1,4);

    GHG_production_BEV_SP(1,i-StartYearEmissions+1)=newBEV(1,i-StartYearFleet+1,1)*VehicleCycle_Inputdata_CtG_SP(i-StartYearEmissions+1,5);
    GHG_production_BEV_SP(2,i-StartYearEmissions+1)=newBEV(1,i-StartYearFleet+1,2)*VehicleCycle_Inputdata_CtG_SP(i-StartYearEmissions+1,6);
    GHG_production_BEV_SP(3,i-StartYearEmissions+1)=newBEV(1,i-StartYearFleet+1,3)*VehicleCycle_Inputdata_CtG_SP(i-StartYearEmissions+1,7);
    GHG_production_BEV_SP(4,i-StartYearEmissions+1)=newBEV(1,i-StartYearFleet+1,4)*VehicleCycle_Inputdata_CtG_SP(i-StartYearEmissions+1,8);

    GHG_production_FC_SP(1,i-StartYearEmissions+1)=newFC(1,i-StartYearFleet+1,1)*VehicleCycle_Inputdata_CtG_SP(i-StartYearEmissions+1,9);
    GHG_production_FC_SP(2,i-StartYearEmissions+1)=newFC(1,i-StartYearFleet+1,2)*VehicleCycle_Inputdata_CtG_SP(i-StartYearEmissions+1,10);
    GHG_production_FC_SP(3,i-StartYearEmissions+1)=newFC(1,i-StartYearFleet+1,3)*VehicleCycle_Inputdata_CtG_SP(i-StartYearEmissions+1,11);
    GHG_production_FC_SP(4,i-StartYearEmissions+1)=newFC(1,i-StartYearFleet+1,4)*VehicleCycle_Inputdata_CtG_SP(i-StartYearEmissions+1,12);

    GHG_production_ICE_SD(1,i-StartYearEmissions+1)=newICE(1,i-StartYearFleet+1,1)*VehicleCycle_Inputdata_CtG_SD(i-StartYearEmissions+1,1);
    GHG_production_ICE_SD(2,i-StartYearEmissions+1)=newICE(1,i-StartYearFleet+1,2)*VehicleCycle_Inputdata_CtG_SD(i-StartYearEmissions+1,2);
    GHG_production_ICE_SD(3,i-StartYearEmissions+1)=newICE(1,i-StartYearFleet+1,3)*VehicleCycle_Inputdata_CtG_SD(i-StartYearEmissions+1,3);
    GHG_production_ICE_SD(4,i-StartYearEmissions+1)=newICE(1,i-StartYearFleet+1,4)*VehicleCycle_Inputdata_CtG_SD(i-StartYearEmissions+1,4);

    GHG_production_BEV_SD(1,i-StartYearEmissions+1)=newBEV(1,i-StartYearFleet+1,1)*VehicleCycle_Inputdata_CtG_SD(i-StartYearEmissions+1,5);
    GHG_production_BEV_SD(2,i-StartYearEmissions+1)=newBEV(1,i-StartYearFleet+1,2)*VehicleCycle_Inputdata_CtG_SD(i-StartYearEmissions+1,6);
    GHG_production_BEV_SD(3,i-StartYearEmissions+1)=newBEV(1,i-StartYearFleet+1,3)*VehicleCycle_Inputdata_CtG_SD(i-StartYearEmissions+1,7);
    GHG_production_BEV_SD(4,i-StartYearEmissions+1)=newBEV(1,i-StartYearFleet+1,4)*VehicleCycle_Inputdata_CtG_SD(i-StartYearEmissions+1,8);

    GHG_production_FC_SD(1,i-StartYearEmissions+1)=newFC(1,i-StartYearFleet+1,1)*VehicleCycle_Inputdata_CtG_SD(i-StartYearEmissions+1,9);
    GHG_production_FC_SD(2,i-StartYearEmissions+1)=newFC(1,i-StartYearFleet+1,2)*VehicleCycle_Inputdata_CtG_SD(i-StartYearEmissions+1,10);
    GHG_production_FC_SD(3,i-StartYearEmissions+1)=newFC(1,i-StartYearFleet+1,3)*VehicleCycle_Inputdata_CtG_SD(i-StartYearEmissions+1,11);
    GHG_production_FC_SD(4,i-StartYearEmissions+1)=newFC(1,i-StartYearFleet+1,4)*VehicleCycle_Inputdata_CtG_SD(i-StartYearEmissions+1,12);
end%i

%Maintenance %däckbyte år 6, år 12, år 18 samt år 24
GHG_maintenance_ICE_SP = zeros(nGroupsFleet,length(EmissionPeriod));
GHG_maintenance_BEV_SP = zeros(size(GHG_maintenance_ICE_SP));
GHG_maintenance_FC_SP = zeros(size(GHG_maintenance_ICE_SP));
GHG_maintenance_ICE_SD = zeros(size(GHG_maintenance_ICE_SP));
GHG_maintenance_BEV_SD = zeros(size(GHG_maintenance_ICE_SP));
GHG_maintenance_FC_SD = zeros(size(GHG_maintenance_ICE_SP));

for i=EmissionPeriod
    GHG_maintenance_ICE_SP(1,i-StartYearEmissions+1)=(stockICE(6,i-StartYearFleet+1,1) + stockICE(12,i-StartYearFleet+1,1) + stockICE(18,i-StartYearFleet+1,1) + stockICE(24,i-StartYearFleet+1,1))*...
        VehicleCycle_Inputdata_GtEOL_SP(i-StartYearEmissions+1,1);
    GHG_maintenance_ICE_SP(2,i-StartYearEmissions+1)=(stockICE(6,i-StartYearFleet+1,2) + stockICE(12,i-StartYearFleet+1,2) + stockICE(18,i-StartYearFleet+1,2) + stockICE(24,i-StartYearFleet+1,2))*...
        VehicleCycle_Inputdata_GtEOL_SP(i-StartYearEmissions+1,2);
    GHG_maintenance_ICE_SP(3,i-StartYearEmissions+1)=(stockICE(6,i-StartYearFleet+1,3) + stockICE(12,i-StartYearFleet+1,3) + stockICE(18,i-StartYearFleet+1,3) + stockICE(24,i-StartYearFleet+1,3))*...
        VehicleCycle_Inputdata_GtEOL_SP(i-StartYearEmissions+1,3);
    GHG_maintenance_ICE_SP(4,i-StartYearEmissions+1)=(stockICE(6,i-StartYearFleet+1,4) + stockICE(12,i-StartYearFleet+1,4) + stockICE(18,i-StartYearFleet+1,4) + stockICE(24,i-StartYearFleet+1,4))*...
        VehicleCycle_Inputdata_GtEOL_SP(i-StartYearEmissions+1,4);

    GHG_maintenance_BEV_SP(1,i-StartYearEmissions+1)=(stockBEV(6,i-StartYearFleet+1,1) + stockBEV(12,i-StartYearFleet+1,1) + stockBEV(18,i-StartYearFleet+1,1) + stockBEV(24,i-StartYearFleet+1,1))*...
        VehicleCycle_Inputdata_GtEOL_SP(i-StartYearEmissions+1,5);
    GHG_maintenance_BEV_SP(2,i-StartYearEmissions+1)=(stockBEV(6,i-StartYearFleet+1,2) + stockBEV(12,i-StartYearFleet+1,2) + stockBEV(18,i-StartYearFleet+1,2) + stockBEV(24,i-StartYearFleet+1,2))*...
        VehicleCycle_Inputdata_GtEOL_SP(i-StartYearEmissions+1,6);
    GHG_maintenance_BEV_SP(3,i-StartYearEmissions+1)=(stockBEV(6,i-StartYearFleet+1,3) + stockBEV(12,i-StartYearFleet+1,3) + stockBEV(18,i-StartYearFleet+1,3) + stockBEV(24,i-StartYearFleet+1,3))*...
        VehicleCycle_Inputdata_GtEOL_SP(i-StartYearEmissions+1,7);
    GHG_maintenance_BEV_SP(4,i-StartYearEmissions+1)=(stockBEV(6,i-StartYearFleet+1,4) + stockBEV(12,i-StartYearFleet+1,4) + stockBEV(18,i-StartYearFleet+1,4) + stockBEV(24,i-StartYearFleet+1,4))*...
        VehicleCycle_Inputdata_GtEOL_SP(i-StartYearEmissions+1,8);

    GHG_maintenance_FC_SP(1,i-StartYearEmissions+1)=(stockFC(6,i-StartYearFleet+1,1) + stockFC(12,i-StartYearFleet+1,1) + stockFC(18,i-StartYearFleet+1,1) + stockFC(24,i-StartYearFleet+1,1))*...
        VehicleCycle_Inputdata_GtEOL_SP(i-StartYearEmissions+1,5);
    GHG_maintenance_FC_SP(2,i-StartYearEmissions+1)=(stockFC(6,i-StartYearFleet+1,2) + stockFC(12,i-StartYearFleet+1,2) + stockFC(18,i-StartYearFleet+1,2) + stockFC(24,i-StartYearFleet+1,2))*...
        VehicleCycle_Inputdata_GtEOL_SP(i-StartYearEmissions+1,6);
    GHG_maintenance_FC_SP(3,i-StartYearEmissions+1)=(stockFC(6,i-StartYearFleet+1,3) + stockFC(12,i-StartYearFleet+1,3) + stockFC(18,i-StartYearFleet+1,3) + stockFC(24,i-StartYearFleet+1,3))*...
        VehicleCycle_Inputdata_GtEOL_SP(i-StartYearEmissions+1,7);
    GHG_maintenance_FC_SP(4,i-StartYearEmissions+1)=(stockFC(6,i-StartYearFleet+1,4) + stockFC(12,i-StartYearFleet+1,4) + stockFC(18,i-StartYearFleet+1,4) + stockFC(24,i-StartYearFleet+1,4))*...
        VehicleCycle_Inputdata_GtEOL_SP(i-StartYearEmissions+1,8);

    GHG_maintenance_ICE_SD(1,i-StartYearEmissions+1)=(stockICE(6,i-StartYearFleet+1,1) + stockICE(12,i-StartYearFleet+1,1) + stockICE(18,i-StartYearFleet+1,1) + stockICE(24,i-StartYearFleet+1,1))*...
        VehicleCycle_Inputdata_GtEOL_SD(i-StartYearEmissions+1,1);
    GHG_maintenance_ICE_SD(2,i-StartYearEmissions+1)=(stockICE(6,i-StartYearFleet+1,2) + stockICE(12,i-StartYearFleet+1,2) + stockICE(18,i-StartYearFleet+1,2) + stockICE(24,i-StartYearFleet+1,2))*...
        VehicleCycle_Inputdata_GtEOL_SD(i-StartYearEmissions+1,2);
    GHG_maintenance_ICE_SD(3,i-StartYearEmissions+1)=(stockICE(6,i-StartYearFleet+1,3) + stockICE(12,i-StartYearFleet+1,3) + stockICE(18,i-StartYearFleet+1,3) + stockICE(24,i-StartYearFleet+1,3))*...
        VehicleCycle_Inputdata_GtEOL_SD(i-StartYearEmissions+1,3);
    GHG_maintenance_ICE_SD(4,i-StartYearEmissions+1)=(stockICE(6,i-StartYearFleet+1,4) + stockICE(12,i-StartYearFleet+1,4) + stockICE(18,i-StartYearFleet+1,4) + stockICE(24,i-StartYearFleet+1,4))*...
        VehicleCycle_Inputdata_GtEOL_SD(i-StartYearEmissions+1,4);

    GHG_maintenance_BEV_SD(1,i-StartYearEmissions+1)=(stockBEV(6,i-StartYearFleet+1,1) + stockBEV(12,i-StartYearFleet+1,1) + stockBEV(18,i-StartYearFleet+1,1) + stockBEV(24,i-StartYearFleet+1,1))*...
        VehicleCycle_Inputdata_GtEOL_SD(i-StartYearEmissions+1,5);
    GHG_maintenance_BEV_SD(2,i-StartYearEmissions+1)=(stockBEV(6,i-StartYearFleet+1,2) + stockBEV(12,i-StartYearFleet+1,2) + stockBEV(18,i-StartYearFleet+1,2) + stockBEV(24,i-StartYearFleet+1,2))*...
        VehicleCycle_Inputdata_GtEOL_SD(i-StartYearEmissions+1,6);
    GHG_maintenance_BEV_SD(3,i-StartYearEmissions+1)=(stockBEV(6,i-StartYearFleet+1,3) + stockBEV(12,i-StartYearFleet+1,3) + stockBEV(18,i-StartYearFleet+1,3) + stockBEV(24,i-StartYearFleet+1,3))*...
        VehicleCycle_Inputdata_GtEOL_SD(i-StartYearEmissions+1,7);
    GHG_maintenance_BEV_SD(4,i-StartYearEmissions+1)=(stockBEV(6,i-StartYearFleet+1,4) + stockBEV(12,i-StartYearFleet+1,4) + stockBEV(18,i-StartYearFleet+1,4) + stockBEV(24,i-StartYearFleet+1,4))*...
        VehicleCycle_Inputdata_GtEOL_SD(i-StartYearEmissions+1,8);

    GHG_maintenance_FC_SD(1,i-StartYearEmissions+1)=(stockFC(6,i-StartYearFleet+1,1) + stockFC(12,i-StartYearFleet+1,1) + stockFC(18,i-StartYearFleet+1,1) + stockFC(24,i-StartYearFleet+1,1))*...
        VehicleCycle_Inputdata_GtEOL_SD(i-StartYearEmissions+1,5);
    GHG_maintenance_FC_SD(2,i-StartYearEmissions+1)=(stockFC(6,i-StartYearFleet+1,2) + stockFC(12,i-StartYearFleet+1,2) + stockFC(18,i-StartYearFleet+1,2) + stockFC(24,i-StartYearFleet+1,2))*...
        VehicleCycle_Inputdata_GtEOL_SD(i-StartYearEmissions+1,6);
    GHG_maintenance_FC_SD(3,i-StartYearEmissions+1)=(stockFC(6,i-StartYearFleet+1,3) + stockFC(12,i-StartYearFleet+1,3) + stockFC(18,i-StartYearFleet+1,3) + stockFC(24,i-StartYearFleet+1,3))*...
        VehicleCycle_Inputdata_GtEOL_SD(i-StartYearEmissions+1,7);
    GHG_maintenance_FC_SD(4,i-StartYearEmissions+1)=(stockFC(6,i-StartYearFleet+1,4) + stockFC(12,i-StartYearFleet+1,4) + stockFC(18,i-StartYearFleet+1,4) + stockFC(24,i-StartYearFleet+1,4))*...
        VehicleCycle_Inputdata_GtEOL_SD(i-StartYearEmissions+1,8);
end%i

% EOL
GHG_EOL_ICE_SP = zeros(nGroupsFleet,length(EmissionPeriod));
GHG_EOL_BEV_SP = zeros(size(GHG_maintenance_ICE_SP));
GHG_EOL_FC_SP = zeros(size(GHG_maintenance_ICE_SP));
GHG_EOL_ICE_SD = zeros(size(GHG_maintenance_ICE_SP));
GHG_EOL_BEV_SD = zeros(size(GHG_maintenance_ICE_SP));
GHG_EOL_FC_SD = zeros(size(GHG_maintenance_ICE_SP));

for i=EmissionPeriod
    GHG_EOL_ICE_SP(1,i-StartYearEmissions+1)=sum(scrappedICE(:,i-StartYearFleet+1,1))*VehicleCycle_Inputdata_EOL_SP(i-StartYearEmissions+1,1);
    GHG_EOL_ICE_SP(2,i-StartYearEmissions+1)=sum(scrappedICE(:,i-StartYearFleet+1,2))*VehicleCycle_Inputdata_EOL_SP(i-StartYearEmissions+1,2);
    GHG_EOL_ICE_SP(3,i-StartYearEmissions+1)=sum(scrappedICE(:,i-StartYearFleet+1,3))*VehicleCycle_Inputdata_EOL_SP(i-StartYearEmissions+1,3);
    GHG_EOL_ICE_SP(4,i-StartYearEmissions+1)=sum(scrappedICE(:,i-StartYearFleet+1,4))*VehicleCycle_Inputdata_EOL_SP(i-StartYearEmissions+1,4);

    GHG_EOL_BEV_SP(1,i-StartYearEmissions+1)=sum(scrappedBEV(:,i-StartYearFleet+1,1))*VehicleCycle_Inputdata_EOL_SP(i-StartYearEmissions+1,5);
    GHG_EOL_BEV_SP(2,i-StartYearEmissions+1)=sum(scrappedBEV(:,i-StartYearFleet+1,2))*VehicleCycle_Inputdata_EOL_SP(i-StartYearEmissions+1,6);
    GHG_EOL_BEV_SP(3,i-StartYearEmissions+1)=sum(scrappedBEV(:,i-StartYearFleet+1,3))*VehicleCycle_Inputdata_EOL_SP(i-StartYearEmissions+1,7);
    GHG_EOL_BEV_SP(4,i-StartYearEmissions+1)=sum(scrappedBEV(:,i-StartYearFleet+1,4))*VehicleCycle_Inputdata_EOL_SP(i-StartYearEmissions+1,8);

    GHG_EOL_FC_SP(1,i-StartYearEmissions+1)=sum(scrappedFC(:,i-StartYearFleet+1,1))*VehicleCycle_Inputdata_EOL_SP(i-StartYearEmissions+1,9);
    GHG_EOL_FC_SP(2,i-StartYearEmissions+1)=sum(scrappedFC(:,i-StartYearFleet+1,2))*VehicleCycle_Inputdata_EOL_SP(i-StartYearEmissions+1,10);
    GHG_EOL_FC_SP(3,i-StartYearEmissions+1)=sum(scrappedFC(:,i-StartYearFleet+1,3))*VehicleCycle_Inputdata_EOL_SP(i-StartYearEmissions+1,11);
    GHG_EOL_FC_SP(4,i-StartYearEmissions+1)=sum(scrappedFC(:,i-StartYearFleet+1,4))*VehicleCycle_Inputdata_EOL_SP(i-StartYearEmissions+1,12);

    GHG_EOL_ICE_SD(1,i-StartYearEmissions+1)=sum(scrappedICE(:,i-StartYearFleet+1,1))*VehicleCycle_Inputdata_EOL_SD(i-StartYearEmissions+1,1);
    GHG_EOL_ICE_SD(2,i-StartYearEmissions+1)=sum(scrappedICE(:,i-StartYearFleet+1,2))*VehicleCycle_Inputdata_EOL_SD(i-StartYearEmissions+1,2);
    GHG_EOL_ICE_SD(3,i-StartYearEmissions+1)=sum(scrappedICE(:,i-StartYearFleet+1,3))*VehicleCycle_Inputdata_EOL_SD(i-StartYearEmissions+1,3);
    GHG_EOL_ICE_SD(4,i-StartYearEmissions+1)=sum(scrappedICE(:,i-StartYearFleet+1,4))*VehicleCycle_Inputdata_EOL_SD(i-StartYearEmissions+1,4);

    GHG_EOL_BEV_SD(1,i-StartYearEmissions+1)=sum(scrappedBEV(:,i-StartYearFleet+1,1))*VehicleCycle_Inputdata_EOL_SD(i-StartYearEmissions+1,5);
    GHG_EOL_BEV_SD(2,i-StartYearEmissions+1)=sum(scrappedBEV(:,i-StartYearFleet+1,2))*VehicleCycle_Inputdata_EOL_SD(i-StartYearEmissions+1,6);
    GHG_EOL_BEV_SD(3,i-StartYearEmissions+1)=sum(scrappedBEV(:,i-StartYearFleet+1,3))*VehicleCycle_Inputdata_EOL_SD(i-StartYearEmissions+1,7);
    GHG_EOL_BEV_SD(4,i-StartYearEmissions+1)=sum(scrappedBEV(:,i-StartYearFleet+1,4))*VehicleCycle_Inputdata_EOL_SD(i-StartYearEmissions+1,8);

    GHG_EOL_FC_SD(1,i-StartYearEmissions+1)=sum(scrappedFC(:,i-StartYearFleet+1,1))*VehicleCycle_Inputdata_EOL_SD(i-StartYearEmissions+1,9);
    GHG_EOL_FC_SD(2,i-StartYearEmissions+1)=sum(scrappedFC(:,i-StartYearFleet+1,2))*VehicleCycle_Inputdata_EOL_SD(i-StartYearEmissions+1,10);
    GHG_EOL_FC_SD(3,i-StartYearEmissions+1)=sum(scrappedFC(:,i-StartYearFleet+1,3))*VehicleCycle_Inputdata_EOL_SD(i-StartYearEmissions+1,11);
    GHG_EOL_FC_SD(4,i-StartYearEmissions+1)=sum(scrappedFC(:,i-StartYearFleet+1,4))*VehicleCycle_Inputdata_EOL_SD(i-StartYearEmissions+1,12);
end %i

%% Part 3b Use phase - TTW

%%% ENERGY consumption
% Annual fuel consumption in kWh .
EnergyConsumptionTotal=zeros(3,length(EmissionPeriod)); % ROW 1:ICE, 2:Electric, 3:Hydrogen. Column: Year
Empty=0.2; %Set share for distance with no load
Loaded=1-Empty;

% ICE
EnergyConsumption_ICE=zeros(VehicleAgeSpan,length(EmissionPeriod),nGroupsTransport); %Annual energy use
for year = EmissionPeriod
    for age=1:VehicleAgeSpan+1
        efficiencyYear=year-age-1948; %Index for manufacture year

        %empty driving
        a=trafficICE_transport(age,year-StartYearFleet+1,1)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,1); %Fuel consumption for each vehicle age, weight class and lorries running empty
        b=trafficICE_transport(age,year-StartYearFleet+1,2)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,3);
        c=trafficICE_transport(age,year-StartYearFleet+1,3)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,5);
        d=trafficICE_transport(age,year-StartYearFleet+1,4)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,7);
        e=trafficICE_transport(age,year-StartYearFleet+1,5)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,9);

        %loaded driving
        aa=trafficICE_transport(age,year-StartYearFleet+1,1)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,2); %Fuel consumption for each vehicle age, weight class and lorries running empty
        bb=trafficICE_transport(age,year-StartYearFleet+1,2)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,4);
        cc=trafficICE_transport(age,year-StartYearFleet+1,3)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,6);
        dd=trafficICE_transport(age,year-StartYearFleet+1,4)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,8);
        ee=trafficICE_transport(age,year-StartYearFleet+1,5)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,10);

        EnergyConsumption_ICE(age,year-StartYearEmissions+1,1)=a+aa; % Saves the total fuel consumption for each vehicle group
        EnergyConsumption_ICE(age,year-StartYearEmissions+1,2)=b+bb;
        EnergyConsumption_ICE(age,year-StartYearEmissions+1,3)=c+cc;
        EnergyConsumption_ICE(age,year-StartYearEmissions+1,4)=d+dd;
        EnergyConsumption_ICE(age,year-StartYearEmissions+1,5)=e+ee;
    end %age
    EnergyConsumptionTotal(1,year-StartYearEmissions+1)=sum(EnergyConsumption_ICE(:,year-StartYearEmissions+1,:),"all"); % Sums up and saves total yearly fuel consumption for ICE
end %i

% BEV
EnergyConsumption_BEV=zeros(size(EnergyConsumption_ICE)); %Annual energy use
for year = EmissionPeriod
    for age=1:VehicleAgeSpan+1
        efficiencyYear=year-age-1948; %Index for manufacture year

        %empty driving
        a=trafficBEV_transport(age,year-StartYearFleet+1,1)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,11); %Fuel consumption for each vehicle age, weight class and lorries running empty
        b=trafficBEV_transport(age,year-StartYearFleet+1,2)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,13);
        c=trafficBEV_transport(age,year-StartYearFleet+1,3)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,15);
        d=trafficBEV_transport(age,year-StartYearFleet+1,4)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,17);
        e=trafficBEV_transport(age,year-StartYearFleet+1,5)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,19);

        %loaded driving
        aa=trafficBEV_transport(age,year-StartYearFleet+1,1)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,12); %Fuel consumption for each vehicle age, weight class and lorries running empty
        bb=trafficBEV_transport(age,year-StartYearFleet+1,2)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,14);
        cc=trafficBEV_transport(age,year-StartYearFleet+1,3)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,16);
        dd=trafficBEV_transport(age,year-StartYearFleet+1,4)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,18);
        ee=trafficBEV_transport(age,year-StartYearFleet+1,5)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,20);

        EnergyConsumption_BEV(age,year-StartYearEmissions+1,1) = a+aa; % Saves the total fuel consumption for each vehicle group
        EnergyConsumption_BEV(age,year-StartYearEmissions+1,2) = b+bb;
        EnergyConsumption_BEV(age,year-StartYearEmissions+1,3) = c+cc;
        EnergyConsumption_BEV(age,year-StartYearEmissions+1,4) = d+dd;
        EnergyConsumption_BEV(age,year-StartYearEmissions+1,5) = e+ee;
    end %age
    EnergyConsumptionTotal(2,year-StartYearEmissions+1)=sum(EnergyConsumption_BEV(:,year-StartYearEmissions+1,:),"all"); % Sums up and saves total yearly fuel consumption for BEVs
end %i

% FC
EnergyConsumption_FC=zeros(size(EnergyConsumption_ICE)); %Annual energy use
for year = EmissionPeriod
    for age=1:VehicleAgeSpan+1
        efficiencyYear=year-age-1948; %Index for manufacture year
        %empty driving
        a=trafficFC_transport(age,year-StartYearFleet+1,1)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,21); %Fuel consumption for each vehicle age, weight class and lorries running empty
        b=trafficFC_transport(age,year-StartYearFleet+1,2)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,23);
        c=trafficFC_transport(age,year-StartYearFleet+1,3)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,25);
        d=trafficFC_transport(age,year-StartYearFleet+1,4)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,27);
        e=trafficFC_transport(age,year-StartYearFleet+1,5)*Empty*Tailpipe_inputdata_Energy(efficiencyYear,29);

        %loaded driving
        aa=trafficFC_transport(age,year-StartYearFleet+1,1)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,22); %Fuel consumption for each vehicle age, weight class and lorries running empty
        bb=trafficFC_transport(age,year-StartYearFleet+1,2)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,24);
        cc=trafficFC_transport(age,year-StartYearFleet+1,3)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,26);
        dd=trafficFC_transport(age,year-StartYearFleet+1,4)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,28);
        ee=trafficFC_transport(age,year-StartYearFleet+1,5)*Loaded*Tailpipe_inputdata_Energy(efficiencyYear,30);

        EnergyConsumption_FC(age,year-StartYearEmissions+1,1)=a+aa; % Saves the total fuel consumption for each vehicle group
        EnergyConsumption_FC(age,year-StartYearEmissions+1,2)=b+bb;
        EnergyConsumption_FC(age,year-StartYearEmissions+1,3)=c+cc;
        EnergyConsumption_FC(age,year-StartYearEmissions+1,4)=d+dd;
        EnergyConsumption_FC(age,year-StartYearEmissions+1,5)=e+ee;
    end

    EnergyConsumptionTotal(3,year-StartYearEmissions+1)=sum(EnergyConsumption_FC(:,year-StartYearEmissions+1,:),"all"); % Sums up and saves total yearly fuel consumption for fuel cell

end


%Fossil vs non-fossil fuel consumption (in kWh)
Biofuel_FC=zeros(1,length(EmissionPeriod)); % To save biofuel consumption for plots in other m-files
FossilFuel_FC=zeros(1,length(EmissionPeriod));% To save fossil fuel consumption for plots in other m-files

for i=1:length(EmissionPeriod)
    Biofuel_FC(1,i)=EnergyConsumptionTotal(1,i)*Fuel_shares(StartYearEmissions-2000+i);
    FossilFuel_FC(1,i)=EnergyConsumptionTotal(1,i)*(1-Fuel_shares(StartYearEmissions-2000+i));
end

% GHG emissions in ton
Tailpipe_GHG=zeros(1,length(EmissionPeriod)); % Matrix for tailpipe GHG emission from diesel usage
for i=1:length(EmissionPeriod)
    Tailpipe_GHG(1,i)=FossilFuel_FC(1,i)*Tailpipe_inputdata_CO2e(1)/10^6 + Biofuel_FC(1,i)*Tailpipe_inputdata_CO2e(2)/10^6;
end


%% Part 3c Use phase - WTT

%in tonnes
WellToTank_GHG_SP=zeros(4,length(EmissionPeriod)); %Matrix for GHG emission from well to tank. Row 1: Diesel, ROW 2: Biofuels, ROW 3: Electricity, ROW 4: Hydrogen
WellToTank_GHG_SD=zeros(4,length(EmissionPeriod)); %Matrix for GHG emission from well to tank. Row 1: Diesel, ROW 2: Biofuels, ROW 3: Electricity, ROW 4: Hydrogen

for i=1:length(EmissionPeriod)
    WellToTank_GHG_SP(1,i)=FossilFuel_FC(1,i)*WellToTank_Inputdata_LCA_SP(i,1)/10^6;
    WellToTank_GHG_SP(2,i)=Biofuel_FC(1,i)*WellToTank_Inputdata_LCA_SP(i,2)/10^6;
    WellToTank_GHG_SP(3,i)=EnergyConsumptionTotal(2,i)*WellToTank_Inputdata_LCA_SP(i,3)/10^6; %electricity
    WellToTank_GHG_SP(4,i)=EnergyConsumptionTotal(3,i)*WellToTank_Inputdata_LCA_SP(i,4)/10^6; %hydrogen

    WellToTank_GHG_SD(1,i)=FossilFuel_FC(1,i)*WellToTank_Inputdata_LCA_SD(i,1)/10^6;
    WellToTank_GHG_SD(2,i)=Biofuel_FC(1,i)*WellToTank_Inputdata_LCA_SD(i,2)/10^6;
    WellToTank_GHG_SD(3,i)=EnergyConsumptionTotal(2,i)*WellToTank_Inputdata_LCA_SD(i,3)/10^6; %electricity
    WellToTank_GHG_SD(4,i)=EnergyConsumptionTotal(3,i)*WellToTank_Inputdata_LCA_SD(i,4)/10^6; %hydrogen
end


%% Part 4: Plot and save results
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

total_GHG_SP = Tailpipe_GHG + fuelCycle_GHG_SP + vehicle_GHG_SP;
total_GHG_SD = Tailpipe_GHG +  fuelCycle_GHG_SD + vehicle_GHG_SD;   

total_GHG_SP_ICE = Tailpipe_GHG + sum(WellToTank_GHG_SP(1:2,:),1) + vehicle_GHG_SP_ICE;
total_GHG_SD_ICE = Tailpipe_GHG + sum(WellToTank_GHG_SD(1:2,:),1) + vehicle_GHG_SD_ICE;
total_GHG_SP_BEV = sum(WellToTank_GHG_SP(3,:),1) + vehicle_GHG_SP_BEV;
total_GHG_SD_BEV = sum(WellToTank_GHG_SD(3,:),1) + vehicle_GHG_SD_BEV;
total_GHG_SP_FC = sum(WellToTank_GHG_SP(4,:),1) + vehicle_GHG_SP_FC;
total_GHG_SD_FC = sum(WellToTank_GHG_SD(4,:),1) + vehicle_GHG_SD_FC;

saveName = "Tech-"+techScenario+",Traffic-"+trafficScenario+",Fuel-"+fuelScenario+".mat";
save(saveName, "EmissionPeriod", "FleetPeriod", "StartYearEmissions", "EndYearEmissions", "StartYearFleet", "EndYearFleet",...
    "Biofuel_FC", "FossilFuel_FC", "EnergyConsumptionTotal", "Fuel_shares",...
     "BEVshareZEVs","nBEV","nFC", "nZEV", "nICE", "newBEV", "newFC", "newZEV", "newICE", "totalFleetSize",...
     "stockBEV","stockFC","stockICE",...
     "fuelCycle_GHG_SP", "fuelCycle_GHG_SD", "Tailpipe_GHG", "total_GHG_SP", "total_GHG_SD", "vehicle_GHG_SP","vehicle_GHG_SD")

run("PlotResults.m")



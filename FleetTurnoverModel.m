function [Stock_ICE_2, scrappedICE, newICE, Stock_ZEV_2, scrappedZEV, newZEV] = ...
    FleetTurnoverModel(ForecastMethod, Stock_ICE_1, Stock_ZEV_1, scrappingProbabilities, mileage, totalFleetSize2, ZEVRates2, TrafficDemand2)

%initialize variables
VehicleAges=size(Stock_ICE_1,1); %age 0-30, ie length=31
nFleetGroups = size(Stock_ICE_1,2);%4
groupShares = (sum(Stock_ICE_1,1) + sum(Stock_ZEV_1,1))/(sum(Stock_ICE_1,"all") + sum(Stock_ZEV_1,"all")); %1x4, average share in stock in previous year
Stock_ICE_2 = zeros(VehicleAges,nFleetGroups);
Stock_ZEV_2 = zeros(VehicleAges,nFleetGroups);
fkmSupply_ICE = zeros(VehicleAges,nFleetGroups);
fkmSupply_ZEV = zeros(VehicleAges,nFleetGroups);
scrappedICE=zeros(VehicleAges,nFleetGroups);
scrappedZEV=zeros(VehicleAges,nFleetGroups);
newICE = zeros(VehicleAges,nFleetGroups);
newZEV = zeros(VehicleAges,nFleetGroups);

%age vehicles
for i=2:VehicleAges-1
    Stock_ICE_2(i,:)= Stock_ICE_1(i-1,:);
    Stock_ZEV_2(i,:)= Stock_ZEV_1(i-1,:);
end %aging


% Scrapping of vehicles age 30
Stock_ICE_2(VehicleAges,:)= Stock_ICE_1(VehicleAges-1,:);
Stock_ZEV_2(VehicleAges,:)= Stock_ZEV_1(VehicleAges-1,:);

%scrap vehicles & calculate vehkm supply (used in method 2)
for i = 1:nFleetGroups
    scrappedICE(:,i)= Stock_ICE_2(:,i).*scrappingProbabilities';
    scrappedZEV(:,i)= Stock_ZEV_2(:,i).*scrappingProbabilities';

    fkmSupply_ICE(:,i) = (Stock_ICE_2(:,i)-scrappedICE(:,i)).*mileage;
    fkmSupply_ZEV(:,i) = (Stock_ZEV_2(:,i)-scrappedZEV(:,i)).*mileage;
end

%calculate new vehicles
if ForecastMethod==1
    newTotal = totalFleetSize2 - (sum(Stock_ICE_2,"all") + sum(Stock_ZEV_2,"all") - sum(scrappedICE,"all") -sum(scrappedZEV,"all"));
end %method 1

if ForecastMethod==2
    fkmSupplyTot = sum(fkmSupply_ZEV,"all")+ sum(fkmSupply_ICE,"all");
    newTotal = (TrafficDemand2 - fkmSupplyTot)/mileage(1);
end %method 2

% ignore negative newTotal (resultat of historic decrease in traffic demand)
if newTotal<0
    newTotal=0;
end

newICE(1,:) = newTotal.*groupShares.*(1-ZEVRates2);
newZEV(1,:) = newTotal.*groupShares.*ZEVRates2;

%calculate new stocks
Stock_ICE_2 = Stock_ICE_2 - scrappedICE + newICE;
Stock_ZEV_2 = Stock_ZEV_2 - scrappedZEV + newZEV;

end %function
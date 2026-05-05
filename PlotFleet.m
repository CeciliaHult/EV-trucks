%% Current traffic and transport
if plotScope ==1
    % Plot initial state of trucks
    %x = ['km','tonkm','transports','tonnes']; works from Matlab 2023b
    x1 = categorical({'km','tonkm','transports','tonnes'});
    x1 = reordercats(x1, {'km','tonkm','transports','tonnes'});
    plotTransportWeigthClasses=[TransportWeightClassesKMShares'; TransportWeightClassesTKMShares'; TransportWeightClassesNShares'; TransportWeightClassesFreightShares']*100;

    figure("Name","Transport statistics",'NumberTitle', 'off')
    tiledlayout(2,1)
    nexttile(1)
    bar(x1,plotTransportWeigthClasses, 'stacked');
    title('Shares of traffic, transport, numbers of transports, and freight for Swedish freight trucks')
    set(gca,'YLim',[0,100]);
    ytickformat('%.0f%%')
    legend(TransportWeightClasses(2:9,1))

    nexttile(2)
    x2 = categorical({'km','tonkm',});
    x2 = reordercats(x2, {'km','tonkm'});
    plotTransportTruckGroups=[TransportTruckGroupsKM'./sum(TransportTruckGroupsKM); TransportTruckGroupsTKM'./sum(TransportTruckGroupsTKM)]*100;
    bar(x2,plotTransportTruckGroups, 'stacked');
    title('Shares of traffic and transport from trucks driven in Sweden')
    set(gca,'YLim',[0,100]);
    ytickformat('%.0f%%')
    legend(TransportTruckGroupDescription)
end %plot if

%% Current fleet
%Plots trucks of current year
if plotScope==1
    figure("Name","Truck statistics",'NumberTitle', 'off')
    tiledlayout(2,2)
    nexttile(1)
    bar(0:VehicleAgeSpan,[CurrentFleetAge'/sum(CurrentFleetAge);CurrentFleetKMage'/sum(CurrentFleetKMage)]);
    title(strcat('Share of Swedish trucks and traffic per age ',num2str(currentYear)))
    legend("Trucks", "Traffic")

    nexttile(2)
    x3 = categorical({'Trucks','km',});
    x3 = reordercats(x3, {'Trucks','km'});
    plotWeigthClassesFleet=[FleetWeightClassesNShares'; FleetWeightClassesTrafficShares']*100;
    bar(x3,plotWeigthClassesFleet, 'stacked');
    title(strcat("Shares of trucks and km driven transport from Swedish trucks ",num2str(currentYear)))
    set(gca,'YLim',[0,100]);
    ytickformat('%.0f%%')
    legend(FleetWeightClasses(2:13,1))

    nexttile(3)
    bar(categorical({'Trucks'}),FleetPowertrainsNShares'*100, 'stacked');
    title('Shares of Swedish trucks per fuel')
    set(gca,'YLim',[0,100]);
    ytickformat('%.0f%%')
    legend(FleetPowertrains(2:5,1))

    nexttile(4)
    plotTruckGroupsFleet=[FleetGroupsN'/sum(FleetGroupsN); FleetGroupsTraffic'/sum(FleetGroupsTraffic)]*100;
    bar(x3,plotTruckGroupsFleet, 'stacked');
    title(strcat("Shares of trucks and km for trucks driven in Sweden ",num2str(currentYear)))
    set(gca,'YLim',[0,100]);
    ytickformat('%.0f%%')
    legend(FleetTruckGroupDescription)
end %plot if

%% Compare fleet groups and transport groups
if plotScope ==1
    figure("Name","Transport and truck comparision",'NumberTitle', 'off')
    tiledlayout(1,2)
    nexttile()
    fleetBar = bar(categorical({'km'}),FleetGroupsTraffic'/sum(FleetGroupsTraffic)*100, 'stacked', FaceColor='flat');
    title({'Shares of traffic for', 'registred trucks driven in Sweden ',num2str(currentYear)})
    set(gca,'YLim',[0,100]);
    ytickformat('%.0f%%')
    legend(FleetTruckGroupDescription)
    %set colors
    fleetBar(1).CData = [226 225 229]/255;
    fleetBar(2).CData = [88 186 193]/255;
    fleetBar(3).CData = [0 166 189]/255;
    fleetBar(4).CData = [0 132 135]/255;
    fleetBar(5).CData = [79 79 76]/255;

    nexttile()
    transportBar = bar(categorical({'km'}),TransportTruckGroupsKM'./sum(TransportTruckGroupsKM)*100, 'stacked', FaceColor='flat');
    title({'Shares of traffic from','truck transports in Sweden ',num2str(currentYear)})
    set(gca,'YLim',[0,100]);
    ytickformat('%.0f%%')
    legend(TransportTruckGroupDescription)
    %set colors
    transportBar(1).CData = [254 239 229]/255;
    transportBar(2).CData = [242 137 105]/255;
    transportBar(3).CData = [234 85 80]/255;
    transportBar(4).CData = [199 113 83]/255;
    transportBar(5).CData = [79 79 76]/255;
end %plot if
%% Fleet forecasting data
if plotScope==1
    % plot fleet forecasting indata
    figure("Name","Forecast parameters",'NumberTitle', 'off')
    tiledlayout(3,1)
    nexttile(1)
    title('Scrapping probabilities and survival rate for trucks')
    hold on
    plot(x, scrappingProbabilities*100)

    survival=ones(VehicleAgeSpan+1,1); %Matrix for probability of survival
    for j=2:length(survival) %Creates column for probability of survival
        survival(j)=exp(-(j./lambda).^kappa);
    end
    plot(x, survival*100)
    legend("Scrapping probability", "Lifetime survival")
    set(gca,'YLim',[0,100]);
    ytickformat('%.0f%%')

    nexttile(2)
    plot(FleetPeriod,ZEVRates(StartYearFleet-1971+1:EndYearFleet-1971+1,1:4)*100)
    title('ZEV rates new trucks')
    legend(electrificationData{1,2:5})
    set(gca,'YLim',[0,100]);
    ytickformat('%.0f%%')

    nexttile(3)
    plot(FleetPeriod,BEVshareZEVs(StartYearFleet-1971+1:EndYearFleet-1971+1,1:4)*100)
    title('BET share of new ZEVs')
    legend(BEVdata{1,2:5})
    set(gca,'YLim',[0,100]);
    ytickformat('%.0f%%')
end %ifplot


%% Transport demand forecast
if plotScope ==1
    %Plot total transport demand scenarios
    figure("Name","Transport forecast", 'NumberTitle', 'off')
    tiledlayout(1,2)
    nexttile(1)
    plot(FleetPeriod,TransportDemand_Inputdata)
    title("Transport demand")
    ylabel("Gtkm")
    set(gca,'YLim',[0,100]);

    nexttile(2)
    plot(FleetPeriod,TrafficDemand_Inputdata)
    title("Traffic demand")
    ylabel("Mkm")
    set(gca,'YLim',[0,8000]);


    %Compare with Samgods forcast
    % %Plot transport demand scenario, by fleet group
    figure("Name","Transport forecast", 'NumberTitle', 'off')
    tiledlayout(2,2)
    nexttile(1)
    plot(FleetPeriod,TransportDemand)
    title("Transport demand by group")
    ylabel("Gtkm")
    legend(TransportTruckGroupDescription)

    nexttile(2)
    plot(FleetPeriod,TrafficDemand)
    title("Traffic demand by group")
    ylabel("Mkm")
    legend(TransportTruckGroupDescription)

    nexttile(3)
    hold on
    plot(2019:2045,samgodsTransport(:,1))
    plot(2019:2045,samgodsTransport(:,2))
    plot(2019:2045,samgodsTransport(:,3))
    plot(2019:2045,samgodsTransport(:,4))
    title("Samgods Transport demand by group")
    ylabel("Gtkm")
    legend(SamgodsForecast(1,9:12))

    nexttile(4)
    hold on
    plot(2019:2045,samgodsTraffic(:,1))
    plot(2019:2045,samgodsTraffic(:,2))
    plot(2019:2045,samgodsTraffic(:,3))
    plot(2019:2045,samgodsTraffic(:,4))
    title("Samgods Traffic demand")
    ylabel("Mkm")
    legend(SamgodsForecast(1,3:6))
end

%% Compare model with real data
figureSM3 = figure("Name","History vs forecast",'NumberTitle', 'off');
tiledlayout(3,1)
nexttile(1)
hold on
plot(totalFleetHistory(:,1),totalFleetHistory(:,2)/1000)
plot(FleetPeriod,totalFleetSize/1000)
title("Total fleet")
set(gca,'YLim',[0,max(totalFleetSize/1000)*1.1]);
ylabel("thousand trucks")
legend("Data","Model")

nexttile(2)
hold on
plotNew= sum(newICE,[1,3])+sum(newZEV,[1,3]);
plot(newHistory(:,1),newHistory(:,2)/1000)
plot(FleetPeriod(2:end),plotNew(2:end)/1000)
title("New trucks")
set(gca,'YLim',[0,max(plotNew)*1.1/1000]);
ylabel("thousand trucks")
legend("Data","Model")

nexttile(3)
hold on
plotScrapped= sum(scrappedICE,[1,3])+sum(scrappedZEV,[1,3]);
plot(syntheticScrappedHistory(:,1),syntheticScrappedHistory(:,2)/1000)
plot(FleetPeriod(2:end),plotScrapped(2:end)/1000)
title("Scrapped trucks")
set(gca,'YLim',[0,max(plotScrapped)*1.1/1000]);
xlabel("Year")
ylabel("thousand trucks")
legend("Data","Model")


figureSM4=figure("Name","Model vs current fleet",'NumberTitle', 'off');
tiledlayout(2,1)
nexttile(1)
hold on
bar(0:VehicleAgeSpan,[CurrentFleetAge'; (sum(stockICE(:,currentYear-StartYearFleet+1,:),3) +sum(stockZEV(currentYear-StartYearFleet+1),3))']);
title({'Number of trucks by age in ',num2str(currentYear)})
ylabel('trucks')
legend("Data", "Model")

nexttile(2)
title({'Traffic by truck age ',num2str(currentYear)})
hold on
bar(0:VehicleAgeSpan,...
    [CurrentFleetKMage'; (sum(trafficICE_transport(:,currentYear-StartYearFleet+1,:),3) +sum(trafficBEV_transport(currentYear-StartYearFleet+1),3))']); %no FCET in 2022
xlabel("Age")
ylabel('km')
legend("Data", "Model")


%% Fleet forecast

figure("Name","Future fleet",'NumberTitle', 'off')
tiledlayout(4,5)
nexttile(1)
plot(FleetPeriod,(nICE+nZEV)/1000)
title("Total fleet size")
set(gca,'YLim',[0,max((nICE+nZEV)/1000*1.1)]);
ylabel("thousand trucks")
ytickformat('%d')

nexttile(2)
plot(FleetPeriod,nICE./totalFleetSize*100)
title("Share of ICE trucks")
set(gca,'YLim',[0,100]);
ytickformat('%.0f%%')

nexttile(3)
hold on
plot(FleetPeriod,nZEV./totalFleetSize*100)
title("Share of ZEV trucks")
set(gca,'YLim',[0,100]);
ytickformat('%.0f%%')

nexttile(4)
hold on
plot(FleetPeriod,nBEV./totalFleetSize*100)
title("Share of BET trucks")
set(gca,'YLim',[0,100]);
ytickformat('%.0f%%')

nexttile(5)
hold on
plot(FleetPeriod,nFC./totalFleetSize*100)
title("Share of FCET trucks")
set(gca,'YLim',[0,100]);
ytickformat('%.0f%%')

for i =1:nGroupsFleet-1
    nexttile(6)
    hold on
    plot(FleetPeriod,sum(stockICE(:,:,i),1)+ sum(stockZEV(:,:,i),1))
    nexttile(7)
    hold on
    plot(FleetPeriod,sum(stockICE(:,:,i),1))
    nexttile(8)
    hold on
    plot(FleetPeriod,sum(stockZEV(:,:,i),1))
    nexttile(9)
    hold on
    plot(FleetPeriod,sum(stockBEV(:,:,i),1))
    nexttile(10)
    hold on
    plot(FleetPeriod,sum(stockFC(:,:,i),1))
end

nexttile(6)
title("Number of trucks")
legend(FleetTruckGroupDescription(1:4))
nexttile(7)
title("Number of ICE trucks")
legend(FleetTruckGroupDescription(1:4))
nexttile(8)
title("Number of ZEV trucks")
legend(FleetTruckGroupDescription(1:4))
nexttile(9)
title("Number of BET trucks")
legend(FleetTruckGroupDescription(1:4))
nexttile(10)
title("Number of FCET trucks")
legend(FleetTruckGroupDescription(1:4))

nexttile(11)
plot(FleetPeriod(2:end),sum(scrappedICE(:,2:end,:),[1,3]) + sum(scrappedZEV(:,2:end,:),[1,3]))
title("Number of scrapped trucks")
%set(gca,'XLim',[StartYearForcast+1,EndYearForecast]);
set(gca,'YLim',[0,10000]);
nexttile(12)
plot(FleetPeriod(2:end),sum(scrappedICE(:,2:end,:),[1,3]))
title("Number of scrapped ICE trucks")
%set(gca,'XLim',[StartYearForcast+1,EndYearForecast]);
set(gca,'YLim',[0,10000]);
nexttile(13)
plot(FleetPeriod(2:end),sum(scrappedZEV(:,2:end,:),[1,3]))
title("Number of scrapped ZEV trucks")
%set(gca,'XLim',[StartYearForcast+1,EndYearForecast]);
set(gca,'YLim',[0,10000]);
nexttile(14)
plot(FleetPeriod(2:end),sum(scrappedBEV(:,2:end,:),[1,3]))
title("Number of scrapped BET trucks")
%set(gca,'XLim',[StartYearForcast+1,EndYearForecast]);
set(gca,'YLim',[0,10000]);
nexttile(15)
plot(FleetPeriod(2:end),sum(scrappedFC(:,2:end,:),[1,3]))
title("Number of scrapped FCET trucks")
%set(gca,'XLim',[StartYearForcast+1,EndYearForecast]);
set(gca,'YLim',[0,10000]);

nexttile(16)
plot(FleetPeriod(2:end),sum(newICE(:,2:end,:),[1,3])+sum(newZEV(:,2:end,:),[1,3]))
title("Number of new trucks")
%set(gca,'XLim',[StartYearForcast+1,EndYearForecast]);
%set(gca,'YLim',[0,10000]);
nexttile(17)
plot(FleetPeriod(2:end),sum(newICE(:,2:end,:),[1,3]))
title("Number of new ICE trucks")
%set(gca,'XLim',[StartYearForcast+1,EndYearForecast]);
%set(gca,'YLim',[0,10000]);
nexttile(18)
plot(FleetPeriod(2:end),sum(newZEV(:,2:end,:),[1,3]))
title("Number of new ZEV trucks")
%set(gca,'XLim',[StartYearForcast+1,EndYearForecast]);
%set(gca,'YLim',[0,10000]);
nexttile(19)
plot(FleetPeriod(2:end),sum(newBEV(:,2:end,:),[1,3]))
title("Number of new BET trucks")
%set(gca,'XLim',[StartYearForcast+1,EndYearForecast]);
%set(gca,'YLim',[0,10000]);
nexttile(20)
plot(FleetPeriod(2:end),sum(newFC(:,2:end,:),[1,3]))
title("Number of new FCET trucks")
%set(gca,'XLim',[StartYearForcast+1,EndYearForecast]);
%set(gca,'YLim',[0,10000]);


%% Traffic plots
if plotScope ==1
    figure("Name","Check: traffic age for ICE",'NumberTitle', 'off')
    title("ICE Traffic check")
    hold on
    plot(FleetPeriod, sum(trafficICE_age,[1,3]))
    plot(FleetPeriod, sum(trafficICE_age2,[1,3]))
    plot(FleetPeriod, sum(trafficICE_age3,[1,3]))
    plot(FleetPeriod, sum(TrafficDemand,1)*10^6,'--')
    legend("age1","age2","age3","Total traffic demand")

    figure("Name","Check: Transformation from GVW to GCVW",'NumberTitle', 'off')
    hold on
    title("Compare traffic before and after transformation")
    plot(FleetPeriod,sum(trafficICE_transport,[1,3]) + sum(trafficBEV_transport,[1,3]) + sum(trafficFC_transport,[1,3]))
    plot(FleetPeriod,sum(trafficICE_age3,[1,3]) + sum(trafficBEV_age3,[1,3]) + sum(trafficFC_age3,[1,3]),'--')
    ylabel('km')
    legend("transport traffic","fleet traffic")

    figure("Name","Check traffic age",'NumberTitle', 'off')
    tiledlayout(2,1)
    nexttile()
    title("Annual milage per technology")
    hold on
    plot(FleetPeriod,sum(trafficICE_transport,[1,3])./sum(stockICE,[1,3]))
    plot(FleetPeriod,sum(trafficBEV_transport,[1,3])./sum(stockBEV,[1,3]))
    plot(FleetPeriod,sum(trafficFC_transport,[1,3])./sum(stockFC,[1,3]))
    ylabel('km')
    legend("ICE","BET","FCET")
    set(gca,'YLim',[0,max(sum(trafficFC_transport,[1,3])./sum(stockFC,[1,3])*1.1)]);

    nexttile()
    title("Annual milage per truck group")
    hold on
    plot(FleetPeriod,sum(trafficICE_age3(:,:,1),1)./sum(stockICE(:,:,1),1))
    plot(FleetPeriod,sum(trafficICE_age3(:,:,2),1)./sum(stockICE(:,:,2),1))
    plot(FleetPeriod,sum(trafficICE_age3(:,:,3),1)./sum(stockICE(:,:,3),1))
    plot(FleetPeriod,sum(trafficICE_age3(:,:,4),1)./sum(stockICE(:,:,4),1))
    legend(FleetTruckGroupDescription(1:4))
    set(gca,'YLim',[0,max(sum(trafficICE_age3(:,:,4),1)./sum(stockICE(:,:,4),1)*1.1)]);
end

%% total traffic
figure("Name","Traffic per technology (variables used as input to emission calculations)",'NumberTitle', 'off')
hold on
title("Traffic per technology")
plot(FleetPeriod,sum(trafficICE_transport,[1,3]),Color="#4e4f4c")
plot(FleetPeriod,sum(trafficBEV_transport,[1,3]),Color="#f18968")
plot(FleetPeriod,sum(trafficFC_transport,[1,3]),Color="#00a5bc")
plot(FleetPeriod,sum(trafficICE_transport,[1,3]) + sum(trafficBEV_transport,[1,3]) + sum(trafficFC_transport,[1,3]),"black",LineStyle="--")
legend('ICE','BET','FCET', 'Total')
ylabel('km')

%% Annual mileage by age

i = currentYear-StartYearFleet;
mileageTruckWeightGroup = trafficICE_age3(:,i,:)./stockICE(:,i,:);

figureSM2 =figure("Name","Annual mileage in in 2022 as a function of age",'NumberTitle', 'off');
hold on
title("Annual mileage by age")
plot(0:VehicleAgeSpan,AnnualMileage_Age)
for i =1:size(mileageTruckWeightGroup,3)-1
    plot(0:VehicleAgeSpan,mileageTruckWeightGroup(:,1,i))
end
xlabel("Truck age")
ylabel('km/vehicle and year')
lgd = legend (["All trucks";FleetTruckGroupDescription(1:4)]);


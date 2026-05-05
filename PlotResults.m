%% Fleet composition

figure5 = figure("Name","Figure 5: Fleet and traffic composition",'NumberTitle', 'off');
tiledlayout(3,1)

nexttile(1)
title("New trucks per technology")
hold on
mainNewBar = bar(FleetPeriod(indexYearsFleet),[sum(newICE(:,indexYearsFleet,:),[1,3]); sum(newBEV(:,indexYearsFleet,:),[1,3]); sum(newFC(:,indexYearsFleet,:),[1,3])]','stacked');
mainNewBar(1).FaceColor = "#4e4f4c"; %ICE
mainNewBar(2).FaceColor = "#f18968"; %BET
mainNewBar(3).FaceColor = "#00a5bc"; %FCET
yMax = max(sum(newICE(:,indexYearsFleet,:),[1,3]) + sum(newBEV(:,indexYearsFleet,:),[1,3]) + sum(newFC(:,indexYearsFleet,:),[1,3]))*1.1;
set(gca,'YLim',[0 yMax]);
xlabel("(a)")
ylabel ("Number of trucks")
ytickformat("%,.0f")
lgd=legend("ICE", "BET","FCET");
lgd.Location = "northwest";

nexttile(2)
title("Trucks in fleet per technology")
hold on
mainFleetBar = bar(FleetPeriod(indexYearsFleet), [sum(stockICE(:,indexYearsFleet,:),[1,3]); sum(stockBEV(:,indexYearsFleet,:),[1,3]); sum(stockFC(:,indexYearsFleet,:),[1,3])], 'stacked');
mainFleetBar(1).FaceColor = "#4e4f4c"; %ICE
mainFleetBar(2).FaceColor = "#f18968"; %BET
mainFleetBar(3).FaceColor = "#00a5bc"; %FCET
yMax = max(sum(stockICE(:,indexYearsFleet,:),[1,3]) + sum(stockBEV(:,indexYearsFleet,:),[1,3]) + sum(stockFC(:,indexYearsFleet,:),[1,3]))*1.1;
set(gca,'YLim',[0 yMax]);
ax=gca;
ax.YAxis.Exponent = 0;
xlabel("(b)")
ylabel ("Number of trucks")
ytickformat("%,.0f")
lgd=legend("ICE", "BET","FCET");
lgd.Location = "northwest";

nexttile(3)
title("Traffic per technology")
hold on
plot(FleetPeriod,sum(trafficICE_transport,[1,3]),Color="#4e4f4c", LineWidth=1)
plot(FleetPeriod,sum(trafficBEV_transport,[1,3]),Color="#f18968", LineWidth=1)
plot(FleetPeriod,sum(trafficFC_transport,[1,3]),Color="#00a5bc", LineWidth=1)
plot(FleetPeriod,sum(trafficICE_transport,[1,3]) + sum(trafficBEV_transport,[1,3]) + sum(trafficFC_transport,[1,3]),"black",LineStyle="--", LineWidth=1)
xlabel("(c)")
ylabel('Gkm')
lgd = legend('ICE','BET','FCET', 'Total');
lgd.Location = "southwest";
%lgd.Direction = "reverse"; Matlab 2023b

figure5.Position =[50 250 750 800];


%% CO2 emissions bar chart, with cumulative emission lines
figure6 = figure("Name","Figure 6: GHG emissions - annual and cumulative",'NumberTitle', 'off');
tiledlayout(1,2)

barEmissionsSP = [Tailpipe_GHG(1:5:end);  fuelCycle_GHG_SP(1:5:end); vehicle_GHG_SP(1:5:end)];
barEmissionsSD = [Tailpipe_GHG(1:5:end);  fuelCycle_GHG_SD(1:5:end); vehicle_GHG_SD(1:5:end)];

cumEmissionsSP = zeros(3,length(Tailpipe_GHG));
cumEmissionsSD = zeros(size(cumEmissionsSP));
cumEmissionsSP(:,1) =  [Tailpipe_GHG(1);  fuelCycle_GHG_SP(1); vehicle_GHG_SP(1)];
cumEmissionsSD(:,1) = [Tailpipe_GHG(1);  fuelCycle_GHG_SD(1); vehicle_GHG_SD(1)];
cumFuelSP(:,1) =  fuelCycle_GHG_SP(1);
cumFuelSD(:,1) = fuelCycle_GHG_SD(1);
cumVehicleSP(:,1) =  vehicle_GHG_SP(1);
cumVehicleSD(:,1) = vehicle_GHG_SD(1);

for j=2:length(Tailpipe_GHG)
    cumEmissionsSP(:,j) = cumEmissionsSP(:,j-1) + [Tailpipe_GHG(j);  fuelCycle_GHG_SP(j); vehicle_GHG_SP(j)];
    cumEmissionsSD(:,j) = cumEmissionsSD(:,j-1)+ [Tailpipe_GHG(j);  fuelCycle_GHG_SD(j); vehicle_GHG_SD(j)];
    cumFuelSP(:,j) = cumFuelSP(:,j-1) + fuelCycle_GHG_SP(j);
    cumFuelSD(:,j) = cumFuelSD(:,j-1)+ fuelCycle_GHG_SD(j);
    cumVehicleSP(:,j) = cumVehicleSP(:,j-1) + vehicle_GHG_SP(j);
    cumVehicleSD(:,j) = cumVehicleSD(:,j-1)+ vehicle_GHG_SD(j);
end

plotResultYears=EmissionPeriod(1:5:end);

maxYlimit = max(total_GHG_SP/10^6)*1.1;

nexttile(1)
title("Stated Policy")
hold on
mainStatedBar = bar(plotResultYears, barEmissionsSP/10^6,"stacked");
mainStatedBar(1).FaceColor = "#4e4f4c"; %Tailpipe
mainStatedBar(2).FaceColor = "#006C6F"; %fuelcycle
mainStatedBar(3).FaceColor = "#f18968"; %vehicle cycle
set(gca,'XLim',[StartYearEmissions-5,EndYearEmissions+5]);
set(gca,'YLim',[0,maxYlimit]);
ylabel (["Annual emissions",'Mton CO{_2}e'])

nexttile(2)
title("Sustainable Development")
hold on
mainSustainableBar = bar(plotResultYears, barEmissionsSD/10^6,"stacked");
mainSustainableBar(1).FaceColor = "#4e4f4c"; %Tailpipe
mainSustainableBar(2).FaceColor = "#006C6F"; %fuelcycle
mainSustainableBar(3).FaceColor = 	"#f18968"; %vehicle cycle
set(gca,'XLim',[StartYearEmissions-5,EndYearEmissions+5]);
set(gca,'YLim',[0,maxYlimit]);

maxYlimit = max(sum(cumEmissionsSP,1)/10^6)*1.1;

nexttile(1)
hold on
yyaxis right
plot(plotResultYears,cumEmissionsSP(1,1:5:end)/10^6,Color="black", LineStyle="-", LineWidth=1)
plot(plotResultYears,sum(cumEmissionsSP(:,1:5:end),1)/10^6,Color="#e95450",LineStyle="-", LineWidth=1)
set(gca,'YLim',[0,maxYlimit]);
xlabel("(a)")

nexttile(2)
hold on
yyaxis right
plot(plotResultYears,cumEmissionsSD(1,1:5:end)/10^6,Color="black",LineStyle="-", LineWidth=1)
plot(plotResultYears,sum(cumEmissionsSD(:,1:5:end),1)/10^6,Color="#e95450",LineStyle="-", LineWidth=1)
set(gca,'YLim',[0,maxYlimit]);
xlabel("(b)")
ylabel (["Cumulative emissions",'Mton CO{_2}e'])

lgd=legend("Tailpipe","Fuel cycle","Vehicle cycle", "Cum. tailpipe", "Cum total");
%lgd.Location ="eastoutside";
lgd.Layout.Tile = "south";
lgd.Orientation ="horizontal";

figure6.Position = [50 100 1100 600];


%% energy demand in TWh (1 chart only)

figure7 = figure("Name","Figure 7: Energy use (main barhcart)",'NumberTitle', 'off');
title("Energy use per technology")
hold on
mainEnergyBar = bar(EmissionPeriod(indexYearsEmissions), [FossilFuel_FC(indexYearsEmissions)', Biofuel_FC(indexYearsEmissions)', EnergyConsumptionTotal(2,indexYearsEmissions)', EnergyConsumptionTotal(3,indexYearsEmissions)']/10^9,'stacked');
mainEnergyBar(1).FaceColor = "#4e4f4c"; %Fossil
mainEnergyBar(2).FaceColor = "#006C6F"; %biofuels
mainEnergyBar(3).FaceColor = "#f18968"; %electricity
mainEnergyBar(4).FaceColor = "#00a5bc"; %hydrogen
%set(gca,'XLim',[StartYearEmissions-5,EndYearEmissions+5]);
ax = gca;
ax.XAxis.TickValues = StartYearEmissions:10:EndYearEmissions;
ylabel('TWh')
lgd=legend("Fossil",'Biofuel',"Electricity","Hydrogen");
lgd.Location = "southoutside"; 
lgd.Orientation ="horizontal";
%lgd.Direction = "reverse"; Matlab 2023b

figure7.Position =[50 450 800 500];


%% CO2 emissions per technology bar chart
figure8 = figure("Name","Figure 8: GHG emissions per technology bar chart",'NumberTitle', 'off');
tiledlayout(3,2)

plotResultYears=EmissionPeriod(1:5:end);

barEmissionsSP = [Tailpipe_GHG(1:5:end);  WellToTank_GHG_SP(1,1:5:end) + WellToTank_GHG_SP(2,1:5:end); vehicle_GHG_SP_ICE(1:5:end)];
barEmissionsSD = [Tailpipe_GHG(1:5:end);  WellToTank_GHG_SD(1,1:5:end) + WellToTank_GHG_SD(2,1:5:end); vehicle_GHG_SD_ICE(1:5:end)];
maxYlimit = max(max(barEmissionsSP/10^6))*1.4;

nexttile(1)
title("Stated Policy")
hold on
mainStatedBar = bar(plotResultYears, barEmissionsSP/10^6,"stacked");
mainStatedBar(1).FaceColor = "#4e4f4c"; %Tailpipe
mainStatedBar(2).FaceColor = "#006C6F"; %fuelcycle
mainStatedBar(3).FaceColor = "#f18968"; %vehicle cycle
set(gca,'XLim',[StartYearEmissions-5,EndYearEmissions+5]);
set(gca,'YLim',[0,maxYlimit]);
xlabel("(a)")
ylabel (["ICE",'Mton CO{_2}e'])


nexttile(2)
title("Sustainable Development")
hold on
mainSustainableBar = bar(plotResultYears, barEmissionsSD/10^6,"stacked");
mainSustainableBar(1).FaceColor = "#4e4f4c"; %Tailpipe
mainSustainableBar(2).FaceColor = "#006C6F"; %fuelcycle
mainSustainableBar(3).FaceColor = 	"#f18968"; %vehicle cycle
xlabel("(b)")
ylabel ('Mton CO{_2}e')
set(gca,'XLim',[StartYearEmissions-5,EndYearEmissions+5]);
set(gca,'YLim',[0,maxYlimit]);


barEmissionsSP = [zeros(size(Tailpipe_GHG(1:5:end)));  WellToTank_GHG_SP(3,1:5:end); vehicle_GHG_SP_BEV(1:5:end)];
barEmissionsSD = [zeros(size(Tailpipe_GHG(1:5:end)));  WellToTank_GHG_SD(3,1:5:end); vehicle_GHG_SD_BEV(1:5:end)];
maxYlimit = max(max(barEmissionsSP/10^6))*1.4;

if (techScenario=="Main" || techScenario=="noFC")

    nexttile(3)
    hold on
    mainStatedBar = bar(plotResultYears, barEmissionsSP/10^6,"stacked");
    mainStatedBar(1).FaceColor = "#4e4f4c"; %Tailpipe
    mainStatedBar(2).FaceColor = "#006C6F"; %fuelcycle
    mainStatedBar(3).FaceColor = "#f18968"; %vehicle cycle
    xlabel("(c)")
    ylabel (["BET",'Mton CO{_2}e'])
    set(gca,'XLim',[StartYearEmissions-5,EndYearEmissions+5]);
    set(gca,'YLim',[0,maxYlimit]);

    nexttile(4)
    hold on
    mainSustainableBar = bar(plotResultYears, barEmissionsSD/10^6,"stacked");
    mainSustainableBar(1).FaceColor = "#4e4f4c"; %Tailpipe
    mainSustainableBar(2).FaceColor = "#006C6F"; %fuelcycle
    mainSustainableBar(3).FaceColor = 	"#f18968"; %vehicle cycle
    xlabel("(d)")
    ylabel ('Mton CO{_2}e')
    set(gca,'XLim',[StartYearEmissions-5,EndYearEmissions+5]);
    set(gca,'YLim',[0,maxYlimit]);

end %plot BET

barEmissionsSP = [zeros(size(Tailpipe_GHG(1:5:end)));  WellToTank_GHG_SP(4,1:5:end); vehicle_GHG_SP_FC(1:5:end)];
barEmissionsSD = [zeros(size(Tailpipe_GHG(1:5:end)));  WellToTank_GHG_SD(4,1:5:end); vehicle_GHG_SD_FC(1:5:end)];
maxYlimit = max(max(barEmissionsSP/10^6))*1.4;

if techScenario=="Main"

    nexttile(5)
    hold on
    mainStatedBar = bar(plotResultYears, barEmissionsSP/10^6,"stacked");
    mainStatedBar(1).FaceColor = "#4e4f4c"; %Tailpipe
    mainStatedBar(2).FaceColor = "#006C6F"; %fuelcycle
    mainStatedBar(3).FaceColor = "#f18968"; %vehicle cycle
    xlabel("(e)")
    ylabel (["FCET",'Mton CO{_2}e'])
    set(gca,'XLim',[StartYearEmissions-5,EndYearEmissions+5]);
    set(gca,'YLim',[0,maxYlimit]);

    nexttile(6)
    hold on
    mainSustainableBar = bar(plotResultYears, barEmissionsSD/10^6,"stacked");
    mainSustainableBar(1).FaceColor = "#4e4f4c"; %Tailpipe
    mainSustainableBar(2).FaceColor = "#006C6F"; %fuelcycle
    mainSustainableBar(3).FaceColor = 	"#f18968"; %vehicle cycle
    xlabel("(f)")
    ylabel ('Mton CO{_2}e')
    set(gca,'XLim',[StartYearEmissions-5,EndYearEmissions+5]);
    set(gca,'YLim',[0,maxYlimit]);

end %plot FCET

lgd = legend ("Tailpipe","Fuel cycle","Vehicle cycle");
lgd.Layout.Tile = "south";
lgd.Orientation ="horizontal";

figure8.Position =[50 100 850 700];

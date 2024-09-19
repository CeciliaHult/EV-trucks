%Fleet composition
figure("Name","New vehicle and composition",'NumberTitle', 'off')
tiledlayout(2,2)
nexttile()
area(FleetPeriod(StartYearEmissions-StartYearFleet:end),...
    [sum(newICE(:,(StartYearEmissions-StartYearFleet:end),:),[1,3]); sum(newBEV(:,(StartYearEmissions-StartYearFleet:end),:),[1,3]);...
    sum(newFC(:,(StartYearEmissions-StartYearFleet:end),:),[1,3]) ]')


%energy demand in TWh (ska total vara ca 16 TWh 2020)
figure("Name","Energy use",'NumberTitle', 'off')
tiledlayout(2,1)
nexttile()
title("Energy use per technology")
hold on
%plot(EmissionPeriod,sum(EnergyConsumptionTotal,1)/10^9,"black") %Total
%plot(EmissionPeriod,EnergyConsumptionTotal(1,:)/10^9); %ICE
%plot(EmissionPeriod,EnergyConsumptionTotal(2,:)/10^9); %BEV
%plot(EmissionPeriod,EnergyConsumptionTotal(3,:)/10^9); %FC
area(EmissionPeriod, EnergyConsumptionTotal'/10^9)
ylabel('TWh')
set(gca,'XLim',[StartYearEmissions,EndYearEmissions]);
%legend("Total",'ICE',"BET","FCET")
legend('ICE',"BET","FCET")

nexttile()
hold on
title("Energy use per energy carrier")
%plot(EmissionPeriod,FossilFuel_FC/10^9,"black")
%plot(EmissionPeriod,Biofuel_FC/10^9,"green");
%plot(EmissionPeriod,EnergyConsumptionTotal(2,:)/10^9); %BEV
%plot(EmissionPeriod,EnergyConsumptionTotal(3,:)/10^9); %FC
area(EmissionPeriod, [FossilFuel_FC', Biofuel_FC', EnergyConsumptionTotal(2,:)', EnergyConsumptionTotal(3,:)']/10^9)
ylabel('TWh')
legend("Fossil",'Biofuels',"Electricity","Hydrogen")


%total GHG. Tailpipe borde vara ca 3.0 Mton 2020
figure("Name","GHG emissions - tailpipe and upstream",'NumberTitle', 'off')
tiledlayout(4,1)
nexttile(1)
title('Total emissions')
hold on
plot(EmissionPeriod, total_GHG_SP/10^6,'blue')
plot(EmissionPeriod, total_GHG_SD/10^6,'--blue')
legend('Stated policy','Sustainable development')
ylabel ('Mton CO2e')
set(gca,'XLim',[StartYearEmissions,EndYearEmissions]);
set(gca,'YLim',[0,max(total_GHG_SP/10^6)*1.1]);

nexttile(2)
title('Tailpipe emissions')
hold on
plot(EmissionPeriod, Tailpipe_GHG/10^6)
ylabel ('Mton CO2e')
set(gca,'XLim',[StartYearEmissions,EndYearEmissions]);
set(gca,'YLim',[0,max(Tailpipe_GHG/10^6)*1.1]);

nexttile(3)
title('Fuel cycle emissions')
hold on
plot(EmissionPeriod, sum(WellToTank_GHG_SP,1)/10^6,"blue")
plot(EmissionPeriod, sum(WellToTank_GHG_SD,1)/10^6,"--blue")
legend('Stated policy','Sustainable development')
ylabel ('Mton CO2e')
set(gca,'XLim',[StartYearEmissions,EndYearEmissions]);
set(gca,'YLim',[0,max(total_GHG_SP-Tailpipe_GHG)/10^6*1.1]);

nexttile(4)
title('Vehicle cycle emissions')
hold on
plot(EmissionPeriod, vehicle_GHG_SP/10^6,"blue")
plot(EmissionPeriod, vehicle_GHG_SD/10^6,"--blue")
legend('Stated policy','Sustainable development')
ylabel ('Mton CO2e')
set(gca,'XLim',[StartYearEmissions,EndYearEmissions]);
set(gca,'YLim',[0,max(total_GHG_SP-Tailpipe_GHG)/10^6*1.1]);


%plot per technology
figure("Name","GHG per technology",'NumberTitle', 'off')
tiledlayout(3,1)
nexttile(1)
hold on
title('ICE')
plot(EmissionPeriod, total_GHG_SP_ICE/10^6,'blue')
plot(EmissionPeriod, total_GHG_SD_ICE/10^6,'--blue')
legend('Stated policy','Sustainable development')
ylabel ('Mton CO2e')
set(gca,'XLim',[StartYearEmissions,EndYearEmissions]);
set(gca,'YLim',[0,max(total_GHG_SP_ICE/10^6)*1.1]);

if techScenario~="noZEV"
    nexttile(2)
    hold on
    title('BET')
        plot(EmissionPeriod, total_GHG_SP_BEV/10^6,'blue')
    plot(EmissionPeriod, total_GHG_SD_BEV/10^6,'--blue')
    legend('Stated policy','Sustainable development')
    ylabel ('Mton CO2e')
    set(gca,'XLim',[StartYearEmissions,EndYearEmissions]);
    set(gca,'YLim',[0,max(total_GHG_SP_BEV/10^6)*1.1]);

    if techScenario ~= "noFC"
    nexttile(3)
    hold on
    title('FCET')
    plot(EmissionPeriod, total_GHG_SP_FC/10^6,'blue')
    plot(EmissionPeriod, total_GHG_SD_FC/10^6,'--blue')
    legend('Stated policy','Sustainable development')
    ylabel ('Mton CO2e')
    set(gca,'XLim',[StartYearEmissions,EndYearEmissions]);
    set(gca,'YLim',[0,max(total_GHG_SP_FC/10^6)*1.1]);
    end
end

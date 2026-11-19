% For debugging various tools in this software suite
airfoilConfigName = "e193r3";
motorConfigName = "Cobra_C3510_16";
propellerConfigName = "APC_8x6E";
ESCConfigName = "Aerostar_RVS_G2_30A";

airfoil = Airfoil(airfoilConfigName);
motorPropAssy = MotorPropAssy(motorConfigName, propellerConfigName);
esc = ESC(ESCConfigName);


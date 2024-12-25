import assert from "assert";

import { ethers } from "ethers";
import { type DeployFunction } from "hardhat-deploy/types";

import {
  checkAddressValid,
  GAS,
  getTokenAddressFromConfig,
  getWalletAddressFromConfig,
  isAddressValid,
} from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "sPRL2";

const deploy: DeployFunction = async (hre) => {
  const { getNamedAccounts, deployments } = hre;

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  assert(deployer, "Missing deployer account");

  console.log(`Network: ${hre.network.name}`);
  console.log(`Deployer: ${deployer}`);

  const config: ConfigData = JSON.parse(readFileSync(`./deploy/config/${hre.network.name}/config.json`).toString());
  const accessManager = config.accessManager;
  if (!isAddressValid(accessManager)) throw new Error("Invalid access manager address");

  const sprl2Data = config.sprl2;
  const prlToken = getTokenAddressFromConfig("prl", config);
  const wethToken = getTokenAddressFromConfig("weth", config);

  const auraBPT = checkAddressValid(sprl2Data.auraBPT, "Aura BPT");
  const auraBoosterLite = checkAddressValid(sprl2Data.auraBoosterLite, "Aura Booster Lite");
  const auraVault = checkAddressValid(sprl2Data.auraVault, "Aura Vault");
  const balancerBPT = checkAddressValid(sprl2Data.balancerBPT, "Balancer BPT");

  const feeReceiver = getWalletAddressFromConfig(sprl2Data.feeReceiver, config);

  const contract = await deploy(contractName, {
    from: deployer,
    args: [
      auraBPT,
      feeReceiver,
      accessManager,
      sprl2Data.startPenaltyPercentage,
      sprl2Data.timeLockDuration,
      balancerBPT,
      auraBoosterLite,
      auraVault,
      prlToken,
      wethToken,
    ],
    log: true,
    skipIfAlreadyDeployed: false,
    ...GAS,
  });

  console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${contract.address}`);
};

deploy.tags = [contractName];
export default deploy;

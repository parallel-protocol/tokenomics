import assert from "assert";

import { ethers } from "ethers";
import { type DeployFunction } from "hardhat-deploy/types";

import { GAS, getTokenAddressFromConfig, getWalletAddressFromConfig, isAddressValid } from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "sPRL1";

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

  const sprl1Data = config.sprl1;
  const underlying = getTokenAddressFromConfig(sprl1Data.underlying, config);
  const feeReceiver = getWalletAddressFromConfig(sprl1Data.feeReceiver, config);

  const contract = await deploy(contractName, {
    from: deployer,
    args: [underlying, feeReceiver, accessManager, sprl1Data.startPenaltyPercentage, sprl1Data.timeLockDuration],
    log: true,
    skipIfAlreadyDeployed: false,
    ...GAS,
  });

  console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${contract.address}`);
};

deploy.tags = [contractName];
export default deploy;

import assert from "assert";

import { ethers } from "ethers";
import { type DeployFunction } from "hardhat-deploy/types";

import { checkAddressValid, GAS, getTokenAddressFromConfig, isAddressValid } from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "MainFeeDistributor";

const deploy: DeployFunction = async (hre) => {
  const { getNamedAccounts, deployments } = hre;

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  assert(deployer, "Missing deployer account");

  console.log(`Network: ${hre.network.name}`);
  console.log(`Deployer: ${deployer}`);
  const config: ConfigData = JSON.parse(readFileSync(`./deploy/config/${hre.network.name}/config.json`).toString());
  if (!config.isMainChainFeeDistributor) throw new Error("MainFeeDistributor must be deployed on main chain");

  const accessManager = checkAddressValid(config.accessManager, "access manager");

  const feeDistributorData = config.feeDistributor;
  const bridgeableToken = checkAddressValid(feeDistributorData.bridgeableToken, "bridgeable token");

  const feeToken = getTokenAddressFromConfig(feeDistributorData.feeToken, config);

  const contract = await deploy(contractName, {
    from: deployer,
    args: [accessManager, bridgeableToken, feeToken],
    log: true,
    skipIfAlreadyDeployed: false,
    ...GAS,
  });

  console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${contract.address}`);
};

deploy.tags = [contractName];
export default deploy;

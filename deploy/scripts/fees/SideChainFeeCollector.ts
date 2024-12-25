import assert from "assert";

import { ethers } from "ethers";
import { type DeployFunction } from "hardhat-deploy/types";

import { checkAddressValid, GAS, getLzEidReceiver, getTokenAddressFromConfig, isAddressValid } from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "SideChainFeeCollector";

const deploy: DeployFunction = async (hre) => {
  const { getNamedAccounts, deployments } = hre;

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  assert(deployer, "Missing deployer account");

  console.log(`Network: ${hre.network.name}`);
  console.log(`Deployer: ${deployer}`);
  const config: ConfigData = JSON.parse(readFileSync(`./deploy/config/${hre.network.name}/config.json`).toString());
  if (config.isMainChainFeeDistributor) throw new Error("SideChainFeeCollector must be deployed on side chain");

  const accessManager = checkAddressValid(config.accessManager, "access manager");

  const feeDistributorData = config.feeDistributor;
  const lzEidReceiver = getLzEidReceiver(feeDistributorData.mainChain);
  const destinationReceiver = checkAddressValid(feeDistributorData.destinationReceiver, "destination receiver");
  const bridgeableToken = checkAddressValid(feeDistributorData.bridgeableToken, "bridgeable token");

  const feeToken = getTokenAddressFromConfig(feeDistributorData.feeToken, config);

  const contract = await deploy(contractName, {
    from: deployer,
    args: [accessManager, lzEidReceiver, bridgeableToken, destinationReceiver, feeToken],
    log: true,
    skipIfAlreadyDeployed: false,
    ...GAS,
  });

  console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${contract.address}`);
};

deploy.tags = [contractName];
export default deploy;

import assert from "assert";

import { ethers } from "ethers";
import { type DeployFunction } from "hardhat-deploy/types";

import { checkAddressValid, GAS, getTokenAddressFromConfig } from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "Auctioneer";

const deploy: DeployFunction = async (hre) => {
  const { getNamedAccounts, deployments } = hre;

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  assert(deployer, "Missing deployer account");

  console.log(`Network: ${hre.network.name}`);
  console.log(`Deployer: ${deployer}`);
  const config: ConfigData = JSON.parse(readFileSync(`./deploy/config/${hre.network.name}/config.json`).toString());
  const accessManager = checkAddressValid(config.accessManager, "access manager");

  const auctioneerData = config.auctioneer;

  const paymentToken = getTokenAddressFromConfig(auctioneerData.paymentToken, config);

  const paymentReceiverContractName = config.isMainChainFeeDistributor ? "MainFeeDistributor" : "SideChainFeeCollector";

  const paymentReceiver = await hre.deployments.get(paymentReceiverContractName);
  if (!paymentReceiver) throw new Error("Payment receiver not deployed");

  const contract = await deploy(contractName, {
    from: deployer,
    args: [
      accessManager,
      paymentToken,
      paymentReceiver.address,
      auctioneerData.initStartTime,
      auctioneerData.epochDuration,
      auctioneerData.initPrice,
      auctioneerData.priceMultiplier,
      auctioneerData.minInitPrice,
    ],
    log: true,
    skipIfAlreadyDeployed: false,
    ...GAS,
  });

  console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${contract.address}`);
};

deploy.tags = [contractName];
export default deploy;

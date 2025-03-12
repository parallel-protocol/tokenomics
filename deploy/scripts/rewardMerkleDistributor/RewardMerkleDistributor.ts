import assert from "assert";

import { type DeployFunction } from "hardhat-deploy/types";

import { checkAddressValid, GAS, getTokenAddressFromConfig, getWalletAddressFromConfig } from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "RewardMerkleDistributor";

const deploy: DeployFunction = async (hre) => {
  const { getNamedAccounts, deployments } = hre;

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  assert(deployer, "Missing deployer account");

  console.log(`Network: ${hre.network.name}`);
  console.log(`Deployer: ${deployer}`);

  const config: ConfigData = JSON.parse(readFileSync(`./deploy/config/${hre.network.name}/config.json`).toString());

  const accessManager = checkAddressValid(config.accessManager, "access manager");

  const rewardMerkleDistributorData = config.rewardMerkleDistributor;

  const token = getTokenAddressFromConfig(rewardMerkleDistributorData.token, config);

  const expiredRewardsRecipient = getWalletAddressFromConfig(
    rewardMerkleDistributorData.expiredRewardsRecipient,
    config,
  );

  const contract = await deploy(contractName, {
    from: deployer,
    args: [accessManager, token, expiredRewardsRecipient],
    log: true,
    skipIfAlreadyDeployed: false,
    ...GAS,
  });

  console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${contract.address}`);
};

deploy.tags = [contractName];
export default deploy;

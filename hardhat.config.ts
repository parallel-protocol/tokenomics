import "dotenv/config";

import "hardhat-deploy";
import "@nomicfoundation/hardhat-toolbox-viem";

import { HardhatUserConfig, HttpNetworkAccountsUserConfig } from "hardhat/types";

import { getRpcURL } from "./utils/getRpcURL";
import { getVerifyConfig } from "./utils/getVerifyConfig";

const MNEMONIC = process.env.MNEMONIC;

// If you prefer to be authenticated using a private key, set a PRIVATE_KEY environment variable
const PRIVATE_KEY = process.env.PRIVATE_KEY;

const accounts: HttpNetworkAccountsUserConfig | undefined = MNEMONIC
  ? { mnemonic: MNEMONIC }
  : PRIVATE_KEY
    ? [PRIVATE_KEY]
    : undefined;

if (accounts == null) {
  console.warn(
    "Could not find MNEMONIC or PRIVATE_KEY environment variables. It will not be possible to execute transactions in your example.",
  );
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
        },
      },
    ],
  },
  networks: {
    mainnet: {
      url: getRpcURL("mainnet"),
      accounts,
      verify: getVerifyConfig("mainnet"),
    },
    sepolia: {
      url: getRpcURL("sepolia"),
      accounts,
      verify: getVerifyConfig("sepolia"),
    },
    polygon_amoy: {
      url: getRpcURL("polygon_amoy"),
      accounts,
      verify: getVerifyConfig("polygon_amoy"),
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
};

export default config;

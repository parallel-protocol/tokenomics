type VerifyConfig = {
  etherscan: {
    apiUrl: string;
    apiKey: string;
  };
};

export const getVerifyConfig = (network: string): VerifyConfig => {
  switch (network) {
    case "mainnet": {
      if (!process.env.API_KEY_ETHERSCAN) throw new Error("API_KEY_ETHERSCAN is not set");
      return {
        etherscan: {
          apiUrl: "	https://api.etherscan.io",
          apiKey: process.env.API_KEY_ETHERSCAN,
        },
      };
    }
    case "sepolia": {
      if (!process.env.API_KEY_ETHERSCAN) throw new Error("API_KEY_ETHERSCAN is not set");
      return {
        etherscan: {
          apiUrl: "https://api-sepolia.etherscan.io",
          apiKey: process.env.API_KEY_ETHERSCAN,
        },
      };
    }
    case "polygon_amoy": {
      if (!process.env.API_KEY_POLYGONSCAN) throw new Error("API_KEY_POLYGONSCAN is not set");
      return {
        etherscan: {
          apiUrl: "https://api-amoy.polygonscan.com",
          apiKey: process.env.API_KEY_POLYGONSCAN,
        },
      };
    }
    default: {
      throw new Error(`${network} Network Verify not configured`);
    }
  }
};

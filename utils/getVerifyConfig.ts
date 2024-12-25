type VerifyConfig = {
  etherscan: {
    apiUrl: string;
    apiKey: string;
  };
};

export const getVerifyConfig = (network: string): VerifyConfig => {
  switch (network) {
    case "mainnet": {
      if (!process.env.MAINNET_ETHERSCAN_API_KEY) throw new Error("MAINNET_ETHERSCAN_API_KEY is not set");
      return {
        etherscan: {
          apiUrl: "https://api.etherscan.io",
          apiKey: process.env.MAINNET_ETHERSCAN_API_KEY,
        },
      };
    }
    case "sepolia": {
      if (!process.env.MAINNET_ETHERSCAN_API_KEY) throw new Error("MAINNET_ETHERSCAN_API_KEY is not set");
      return {
        etherscan: {
          apiUrl: "https://api-sepolia.etherscan.io",
          apiKey: process.env.MAINNET_ETHERSCAN_API_KEY,
        },
      };
    }
    case "polygon": {
      if (!process.env.POLYGON_ETHERSCAN_API_KEY) throw new Error("POLYGON_ETHERSCAN_API_KEY is not set");
      return {
        etherscan: {
          apiUrl: "https://api.polygonscan.com",
          apiKey: process.env.POLYGON_ETHERSCAN_API_KEY,
        },
      };
    }
    case "amoy": {
      if (!process.env.POLYGON_ETHERSCAN_API_KEY) throw new Error("POLYGON_ETHERSCAN_API_KEY is not set");
      return {
        etherscan: {
          apiUrl: "https://api-amoy.polygonscan.com",
          apiKey: process.env.POLYGON_ETHERSCAN_API_KEY,
        },
      };
    }
    case "arbiSepolia": {
      if (!process.env.ARBITRUM_ETHERSCAN_API_KEY) throw new Error("ARBITRUM_ETHERSCAN_API_KEY is not set");
      return {
        etherscan: {
          apiUrl: "https://api-sepolia.arbiscan.io",
          apiKey: process.env.ARBITRUM_ETHERSCAN_API_KEY,
        },
      };
    }
    case "fantom": {
      if (!process.env.FANTOM_ETHERSCAN_API_KEY) throw new Error("FANTOM_ETHERSCAN_API_KEY is not set");
      return {
        etherscan: {
          apiUrl: "https://api.ftmscan.com",
          apiKey: process.env.FANTOM_ETHERSCAN_API_KEY,
        },
      };
    }
    default: {
      throw new Error(`${network} Network Verify not configured`);
    }
  }
};

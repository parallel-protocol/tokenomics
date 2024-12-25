export const getRpcURL = (network: string): string => {
  const apiKey = process.env.ALCHEMY_API_KEY;
  if (!apiKey) throw new Error("ALCHEMY_API_KEY is not set");
  switch (network) {
    case "mainnet": {
      return `https://eth-mainnet.g.alchemy.com/v2/${apiKey}`;
    }
    case "sepolia": {
      return `https://eth-sepolia.g.alchemy.com/v2/${apiKey}`;
    }
    case "polygon": {
      return `https://polygon-mainnet.g.alchemy.com/v2/${apiKey}`;
    }
    case "amoy": {
      return `https://polygon-amoy.g.alchemy.com/v2/${apiKey}`;
    }
    case "arbiSepolia": {
      return `https://arb-sepolia.g.alchemy.com/v2/${apiKey}`;
    }
    case "fantom": {
      return `https://fantom-mainnet.g.alchemy.com/v2/${apiKey}`;
    }
    default: {
      throw new Error(`${network} Network RPC not configured`);
    }
  }
};

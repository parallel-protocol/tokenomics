export const getRpcURL = (network: string): string => {
  const apiKey = process.env.API_KEY_ALCHEMY;
  if (!apiKey) throw new Error("API_KEY_ALCHEMY is not set");

  switch (network) {
    case "mainnet": {
      return `https://eth-mainnet.g.alchemy.com/v2/${apiKey}`;
    }
    case "sepolia": {
      return `https://eth-sepolia.g.alchemy.com/v2/${apiKey}`;
    }
    case "polygon_amoy": {
      return `https://polygon-amoy.g.alchemy.com/v2/${apiKey}`;
    }
    default: {
      throw new Error(`${network} Network RPC not configured`);
    }
  }
};

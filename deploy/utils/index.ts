import type { CallOptions } from "hardhat-deploy/types";
import { ethers } from "ethers";
import { Address, ConfigData } from "./types";
import { EndpointId } from "@layerzerolabs/lz-definitions";

export const GAS: CallOptions = {
  maxFeePerGas: "20000000000", // 20 gwei
  maxPriorityFeePerGas: "1000000000",
};

export const getLzEidReceiver = (mainchain: string) => {
  if (mainchain === "sepolia") return EndpointId.SEPOLIA_V2_TESTNET;
  if (mainchain === "arbiSepolia") return EndpointId.ARBSEP_V2_TESTNET;
  if (mainchain === "mainnet") return EndpointId.ETHEREUM_V2_MAINNET;
  if (mainchain === "fantom") return EndpointId.FANTOM_V2_MAINNET;
  if (mainchain === "polygon") return EndpointId.POLYGON_V2_MAINNET;
  throw new Error(`Unsupported lzEidReceiver: ${mainchain}`);
};

// return token address defined in config.tokens
export const getTokenAddressFromConfig = (token: string, config: ConfigData) => {
  if (!Object.keys(config.tokens).includes(token.toLowerCase())) throw new Error(`Token ${token} not found in config`);
  const tokenAddress = config.tokens[token.toLowerCase() as keyof typeof config.tokens];
  if (!isAddressValid(tokenAddress)) throw new Error(`Invalid ${token} address: ${tokenAddress}`);
  return tokenAddress;
};

export const getWalletAddressFromConfig = (wallet: string, config: ConfigData) => {
  if (!Object.keys(config.wallets).includes(wallet.toLowerCase()))
    throw new Error(`Wallet ${wallet} not found in config`);
  const walletAddress = config.wallets[wallet.toLowerCase() as keyof typeof config.wallets];
  if (!isAddressValid(walletAddress)) throw new Error(`Invalid ${wallet} address: ${walletAddress}`);
  return walletAddress;
};

export const checkAddressValid = (address: Address, label: string) => {
  if (!isAddressValid(address)) throw new Error(`Invalid ${label} address: ${address}`);
  return address;
};

export const isAddressValid = (address: string) => {
  return ethers.utils.isAddress(address) && ethers.constants.AddressZero !== address;
};

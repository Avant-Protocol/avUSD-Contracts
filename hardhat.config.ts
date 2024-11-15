import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";

import dotenv from 'dotenv'
import findConfig from 'find-config'
import { HttpNetworkAccountsUserConfig } from "hardhat/types";

const dotenvPath = findConfig('.env')
if (!dotenvPath) {
  throw new Error('No .env file found')
}
dotenv.config({ path: dotenvPath })

const PRIVATE_KEY = process.env.PRIVATE_KEY
const accounts: HttpNetworkAccountsUserConfig | undefined = PRIVATE_KEY ? [PRIVATE_KEY] : undefined
if (accounts == null) {
  console.warn('Could not find PRIVATE_KEY environment variable. It will not be possible to execute transactions in your example.')
}

const config: HardhatUserConfig = {
    solidity: "0.8.20",
    networks: {
        arbitrumSepolia: {
            chainId: 421_614,
            url: `https://sepolia-rollup.arbitrum.io/rpc`,
            accounts,
        },
        avalancheFuji: {
            chainId: 43_113,
            url: `https://api.avax-test.network/ext/bc/C/rpc`,
            accounts,
        },
        optimismSepolia: {
            chainId: 11_155_420,
            url: `https://sepolia.optimism.io`,
            accounts,
        },
    },
};

export default config;

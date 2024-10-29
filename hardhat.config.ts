import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";

const config: HardhatUserConfig = {
    solidity: "0.8.20",
    networks: {
        arbitrumSepolia: {
            chainId: 421_614,
            url: `https://sepolia-rollup.arbitrum.io/rpc`,
            accounts: [`${process.env.PRIVATE_KEY}`],
        },
        avalancheFuji: {
            chainId: 43_113,
            url: `https://api.avax-test.network/ext/bc/C/rpc`,
            accounts: [`${process.env.PRIVATE_KEY}`],
        },
        optimismSepolia: {
            chainId: 11_155_420,
            url: `https://sepolia.optimism.io`,
            accounts: [`${process.env.PRIVATE_KEY}`],
        },
    },
};

export default config;

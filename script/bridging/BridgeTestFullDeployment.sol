// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import "../DeploymentUtils.sol";
import "../../contracts/AvUSD.sol";
import "../../contracts/AvUSDMinting.sol";
import "../../contracts/AvUSDBridging.sol";
import "../../contracts/StakedAvUSDV3.sol";
import "../../contracts/interfaces/IAvUSD.sol";
import "../../contracts/interfaces/IAvUSDMinting.sol";
import "../../contracts/mock/MockToken.sol";

// This deployment uses CREATE2 to ensure that only the modified contracts are deployed
contract BridgeTestFullDeployment is Script, DeploymentUtils {
    struct Contracts {
        MockToken mockTokenA;
        AvUSD avUSDToken;
        StakedAvUSDV3 stakedAvUSD;
        AvUSDMinting avUSDMinting;
        AvUSDBridging avUSDBridging;
    }

    uint256 public constant MAX_AVUSD_MINT_PER_BLOCK = 100_000e18;
    uint256 public constant MAX_AVUSD_REDEEM_PER_BLOCK = 100_000e18;

    // address layerzeroEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f; // Avalanche Fuji
    address layerzeroEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f; // Arbitrum Sepolia
    // address layerzeroEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f; // Optimism Sepolia

    // address ccipRouter = 0xF694E193200268f9a4868e4Aa017A0118C9a8177; // Avalanche Fuji
    address ccipRouter = 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165; // Arbitrum Sepolia
    // address ccipRouter = 0x114A20A10b43D4115e5aeef7345a1A71d2a60C57; // Optimism Sepolia

    // address wrappedNative = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c; // WAVAX on Fuji Testnet
    // address wrappedNative = 0xE591bf0A0CF924A0674d7792db046B23CEbF5f34; // WETH on Arbitrum Sepolia
    // address wrappedNative = 0x4200000000000000000000000000000000000006; // WETH on Optimism Sepolia

    function run() public virtual {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployment(deployerPrivateKey);
    }

    function deployment(uint256 deployerPrivateKey) public {
        address deployerAddress = vm.addr(deployerPrivateKey);
        uint256 deployerBalance = deployerAddress.balance;
        console.log("Deployer -> %s", deployerAddress);
        console.log("Balance -> %s", deployerBalance);

        Contracts memory contracts;

        vm.startBroadcast(deployerPrivateKey);

        // console.log("Deploying AvUSD...");
        // contracts.avUSDToken = new AvUSD(deployerAddress);
        // console.log("Deployed AvUSD to %s", address(contracts.avUSDToken));
        contracts.avUSDToken = AvUSD(0x70Bd20Fd83e55720e31a15d7e00005335145Aa91);

        console.log("Deploying StakedAvUSD...");
        contracts.stakedAvUSD = new StakedAvUSDV3(
            contracts.avUSDToken,
            deployerAddress,
            deployerAddress
        );
        console.log(
            "Deployed StakedAvUSD to %s",
            address(contracts.stakedAvUSD)
        );

        // IAvUSD iAvUSD = IAvUSD(address(contracts.avUSDToken));

        // console.log("Deploying MockToken...");
        // contracts.mockTokenA = MockToken(0xDCA3173e80E983a8374E28583c6f39646DF9455d); // fake usdc on fuji
        // contracts.mockTokenA = new MockToken(
        //     "Mock Token A",
        //     "mockTokenA",
        //     18,
        //     deployerAddress
        // );
        // console.log("Deployed MockToken to %s", address(contracts.mockTokenA));

        // address[] memory assets = new address[](2);
        // assets[0] = address(contracts.mockTokenA);
        // assets[1] = 0xdEd959C5fB39bd5C6A48802EB9d70C5F96F45175;

        // address[] memory custodians = new address[](1);
        // custodians[0] = address(0xF21d5A3AE15Cb4fFd11fE0819650c100Ad6DD203); // fuji custodian

        // console.log("Deploying AvUSDMinting...");
        // contracts.avUSDMinting = new AvUSDMinting(
        //     iAvUSD,
        //     IWAVAX(address(wrappedNative)),
        //     assets,
        //     custodians,
        //     deployerAddress,
        //     MAX_AVUSD_MINT_PER_BLOCK,
        //     MAX_AVUSD_REDEEM_PER_BLOCK
        // );
        // console.log(
        //     "Deployed AvUSDMinting to %s",
        //     address(contracts.avUSDMinting)
        // );

        console.log("Deploying AvUSDBridging...");
        contracts.avUSDBridging = new AvUSDBridging(
            address(contracts.avUSDToken),
            address(contracts.stakedAvUSD),
            layerzeroEndpoint,
            ccipRouter,
            deployerAddress
        );
        console.log(
            "Deployed AvUSDBridging to %s",
            address(contracts.avUSDBridging)
        );

        // give minting & bridging contracts AvUSD minter role
        // contracts.avUSDToken.setMinter(address(contracts.avUSDMinting), true);
        contracts.avUSDToken.setMinter(address(contracts.avUSDBridging), true);

        bytes32 BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
        contracts.stakedAvUSD.grantRole(BRIDGE_ROLE, address(contracts.avUSDBridging));

        // contracts.avUSDToken.setMinter(
        //     0x19596e1D6cd97916514B5DBaA4730781eFE49975,
        //     true
        // );

        // bytes32 avUSDMintingMinterRole = keccak256("MINTER_ROLE");
        // contracts.avUSDMinting.grantRole(
        //     avUSDMintingMinterRole,
        //     0xE183B9cB073B83c74DDff041748E162cac1b8e1a // testnet autominter
        // );

        uint256 finalDeployerBalance = deployerAddress.balance;
        console.log("Cost -> %s", deployerBalance - finalDeployerBalance);
        console.log("Balance -> %s", finalDeployerBalance);

        vm.stopBroadcast();

        uint256 chainId;
        assembly {
            chainId := chainid()
        }
    }
}

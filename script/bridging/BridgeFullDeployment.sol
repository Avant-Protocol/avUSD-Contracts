// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import "../DeploymentUtils.sol";
import "../../contracts/AvUSD.sol";
import "../../contracts/AvUSDMinting.sol";
import "../../contracts/AvUSDBridging.sol";
import "../../contracts/StakedAvUSD.sol";
import "../../contracts/interfaces/IAvUSD.sol";
import "../../contracts/interfaces/IAvUSDMinting.sol";
import "../../contracts/mock/MockToken.sol";

// This deployment uses CREATE2 to ensure that only the modified contracts are deployed
contract BridgeFullDeployment is Script, DeploymentUtils {

  struct Configuration {
    // Roles
    bytes32 avusdMinterRole;
  }

  struct Contracts {
    MockToken mockTokenA;
    IWAVAX wavax;
    AvUSD avUSDToken;
    StakedAvUSD stakedAvUSD;
    AvUSDMinting avUSDMinting;
    AvUSDBridging avUSDBridging;
  }
  
  uint256 public constant MAX_AVUSD_MINT_PER_BLOCK = 100_000e18;
  uint256 public constant MAX_AVUSD_REDEEM_PER_BLOCK = 100_000e18;

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
    contracts.wavax = IWAVAX(address(0xd00ae08403B9bbb9124bB305C09058E32C39A48c)); // WAVAX on Fuji Testnet

    vm.startBroadcast(deployerPrivateKey);

    console.log("Deploying AvUSD...");
    contracts.avUSDToken = new AvUSD(deployerAddress);
    console.log("Deployed AvUSD to %s", address(contracts.avUSDToken));

    console.log("Deploying StakedAvUSD...");
    contracts.stakedAvUSD = new StakedAvUSD(contracts.avUSDToken, deployerAddress, deployerAddress);
    console.log("Deployed StakedAvUSD to %s", address(contracts.stakedAvUSD));

    IAvUSD iAvUSD = IAvUSD(address(contracts.avUSDToken));

    console.log("Deploying MockToken...");
    contracts.mockTokenA = new MockToken("Mock Token A", "mockTokenA", 18, deployerAddress);
    console.log("Deployed MockToken to %s", address(contracts.mockTokenA));

    address[] memory assets = new address[](1);
    assets[0] = address(contracts.mockTokenA);

    address[] memory custodians = new address[](1);
    custodians[0] = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);

    console.log("Deploying AvUSDMinting...");
    contracts.avUSDMinting = new AvUSDMinting(iAvUSD, contracts.wavax, assets, custodians, deployerAddress, MAX_AVUSD_MINT_PER_BLOCK, MAX_AVUSD_REDEEM_PER_BLOCK);
    console.log("Deployed AvUSDMinting to %s", address(contracts.avUSDMinting));

    // give minting contract AvUSD minter role
    contracts.avUSDToken.setMinter(address(contracts.avUSDMinting), true);

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

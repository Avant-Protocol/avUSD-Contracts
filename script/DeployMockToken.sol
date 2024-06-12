// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import "./DeploymentUtils.sol";
import "../contracts/AvUSD.sol";
import "../contracts/AvUSDMinting.sol";
import "../contracts/StakedAvUSD.sol";
import "../contracts/interfaces/IAvUSD.sol";
import "../contracts/interfaces/IAvUSDMinting.sol";
import "../contracts/mock/MockToken.sol";

contract DeployMockToken is Script, DeploymentUtils {

  function run() public virtual {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    deployment(deployerPrivateKey);
  }

  function deployment(uint256 deployerPrivateKey) public {
    address deployerAddress = vm.addr(deployerPrivateKey);
    uint256 deployerBalance = deployerAddress.balance;
    console.log("Deployer -> %s", deployerAddress);
    console.log("Balance -> %s", deployerBalance);

    vm.startBroadcast(deployerPrivateKey);

    MockToken mockToken = new MockToken("Mock Token B", "mockTokenB", 6, deployerAddress);
    console.log("Deployed MockToken to %s", address(mockToken));

    IAvUSDMinting minting = IAvUSDMinting(0xdD1389FED934314091A3d2DB479F6253de8a4b8f);
    minting.addSupportedAsset(address(mockToken));

    uint256 finalDeployerBalance = deployerAddress.balance;
    console.log("Cost -> %s", deployerBalance - finalDeployerBalance);
    console.log("Balance -> %s", finalDeployerBalance);

    vm.stopBroadcast();
  }
}

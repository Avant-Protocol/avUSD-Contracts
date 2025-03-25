// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import "./DeploymentUtils.sol";
import "../contracts/AvUSD.sol";
import "../contracts/AvUSDMintingV2.sol";
import "../contracts/StakedAvUSDV2.sol";
import "../contracts/interfaces/IAvUSD.sol";
import "../contracts/interfaces/IAvUSDMinting.sol";
import "../contracts/mock/MockToken.sol";

contract FullDeployment is Script, DeploymentUtils {
  struct Contracts {
    MockToken mockTokenA;
    AvUSD AvUSDToken;
    StakedAvUSDV2 stakedAvUSD;
    AvUSDMintingV2 avUSDMintingContract;
  }

  struct Configuration {
    // Roles
    bytes32 avusdMinterRole;
  }
  // bytes32 stakedAvUSDTokenMinterRole;
  // bytes32 stakingRewarderRole;

  address public constant ZERO_ADDRESS = address(0);
  uint256 public constant MAX_AVUSD_MINT_PER_BLOCK = 100_000e18;
  uint256 public constant MAX_AVUSD_REDEEM_PER_BLOCK = 100_000e18;

  function run() public virtual {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    deployment(deployerPrivateKey);
  }

  function deployment(uint256 deployerPrivateKey) public returns (Contracts memory) {
    address deployerAddress = vm.addr(deployerPrivateKey);
    uint256 deployerBalance = deployerAddress.balance;
    console.log("Deployer -> %s", deployerAddress);
    console.log("Balance -> %s", deployerBalance);

    Contracts memory contracts;

    vm.startBroadcast(deployerPrivateKey);

    console.log("Deploying AvUSD...");
    contracts.AvUSDToken = new AvUSD(deployerAddress);
    console.log("Deployed AvUSD to %s", address(contracts.AvUSDToken));

    // Checks the AvUSD owner
    _utilsIsOwner(deployerAddress, address(contracts.AvUSDToken));

    console.log("Deploying StakedAvUSD...");
    contracts.stakedAvUSD = new StakedAvUSDV2(contracts.AvUSDToken, deployerAddress, deployerAddress);
    console.log("Deployed StakedAvUSD to %s", address(contracts.stakedAvUSD));

    // Checks the staking owner and admin
    _utilsIsOwner(deployerAddress, address(contracts.stakedAvUSD));
    _utilsHasRole(contracts.stakedAvUSD.DEFAULT_ADMIN_ROLE(), deployerAddress, address(contracts.stakedAvUSD));

    IAvUSD iAvUSD = IAvUSD(address(contracts.AvUSDToken));

    console.log("Deploying MockToken...");
    contracts.mockTokenA = new MockToken("Mock Token A", "mockTokenA", 18, deployerAddress);
    console.log("Deployed MockToken to %s", address(contracts.mockTokenA));

    // AvUSD Minting
    address[] memory assets = new address[](1);
    assets[0] = address(contracts.mockTokenA);

    address[] memory custodians = new address[](1);
    custodians[0] = address(0x19596e1D6cd97916514B5DBaA4730781eFE49975);

    console.log("Deploying AvUSDMinting...");
    contracts.avUSDMintingContract = new AvUSDMintingV2(iAvUSD, assets, custodians, deployerAddress, MAX_AVUSD_MINT_PER_BLOCK, MAX_AVUSD_REDEEM_PER_BLOCK);
    console.log("Deployed AvUSDMinting to %s", address(contracts.avUSDMintingContract));

    // give minting contract AvUSD minter role
    contracts.AvUSDToken.setMinter(address(contracts.avUSDMintingContract));

    // Checks the minting owner and admin
    _utilsIsOwner(deployerAddress, address(contracts.avUSDMintingContract));

    _utilsHasRole(
      contracts.avUSDMintingContract.DEFAULT_ADMIN_ROLE(), deployerAddress, address(contracts.avUSDMintingContract)
    );

    uint256 finalDeployerBalance = deployerAddress.balance;
    console.log("Cost -> %s", deployerBalance - finalDeployerBalance);
    console.log("Balance -> %s", finalDeployerBalance);

    vm.stopBroadcast();

    uint256 chainId;
    assembly {
      chainId := chainid()
    }

    string memory blockExplorerUrl = "";
    if (chainId == 43113) {
      blockExplorerUrl = "https://subnets-test.avax.network";
    } else if (chainId == 43114) {
      blockExplorerUrl = "https://subnets.avax.network/";
    }

    // Logs
    console.log("=====> All AvUSD contracts deployed ....");
    console.log("AvUSD       : %s/address/%s", blockExplorerUrl, address(contracts.AvUSDToken));
    console.log("StakedAvUSD : %s/address/%s", blockExplorerUrl, address(contracts.stakedAvUSD));
    console.log("mockTokenA  : %s/address/%s", blockExplorerUrl, address(contracts.mockTokenA));
    console.log("AvUSDMinting: %s/address/%s", blockExplorerUrl, address(contracts.avUSDMintingContract));

    return contracts;
  }
}

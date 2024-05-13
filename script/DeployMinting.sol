// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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

contract DeployMinting is Script, DeploymentUtils {

  struct Configuration {
    // Roles
    bytes32 avusdMinterRole;
  }
  // bytes32 stakedAvUSDTokenMinterRole;
  // bytes32 stakingRewarderRole;

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

    vm.startBroadcast(deployerPrivateKey);

    IWAVAX wavax = IWAVAX(0xd00ae08403B9bbb9124bB305C09058E32C39A48c); // WAVAX on Fuji Testnet
    IAvUSD iAvUSD = IAvUSD(0x8c4774fC52477fE4bDB46a5189bFeccA64BAD5f2);
    
    address[] memory assets = new address[](1);
    assets[0] = 0xDCA3173e80E983a8374E28583c6f39646DF9455d;

    address[] memory custodians = new address[](1);
    custodians[0] = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);

    console.log("Deploying AvUSDMinting...");
    AvUSDMinting avUSDMintingContract = new AvUSDMinting(iAvUSD, wavax, assets, custodians, deployerAddress, MAX_AVUSD_MINT_PER_BLOCK, MAX_AVUSD_REDEEM_PER_BLOCK);
    console.log("Deployed AvUSDMinting to %s", address(avUSDMintingContract));

    // give minting contract AvUSD minter role
    iAvUSD.setMinter(address(avUSDMintingContract));

    // Checks the minting owner and admin
    _utilsIsOwner(deployerAddress, address(avUSDMintingContract));

    _utilsHasRole(
      avUSDMintingContract.DEFAULT_ADMIN_ROLE(), deployerAddress, address(avUSDMintingContract)
    );

    bytes32 avUSDMintingMinterRole = keccak256("MINTER_ROLE");

    // update array size and grantee addresses
    address[] memory grantees = new address[](1);
    grantees[0] = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    for (uint256 i = 0; i < grantees.length; ++i) {
      if (!avUSDMintingContract.hasRole(avUSDMintingMinterRole, grantees[i])) {
        avUSDMintingContract.grantRole(avUSDMintingMinterRole, grantees[i]);
      }
    }

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
    console.log("AvUSDMinting: %s/address/%s", blockExplorerUrl, address(avUSDMintingContract));
  }
}

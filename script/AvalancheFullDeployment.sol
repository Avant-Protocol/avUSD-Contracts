// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';
import {StdUtils} from 'forge-std/StdUtils.sol';

import './DeploymentUtils.sol';
import '../contracts/AvUSD.sol';
import '../contracts/AvUSDMinting.sol';
import '../contracts/StakedAvUSDV2.sol';
import '../contracts/interfaces/IAvUSD.sol';
import '../contracts/interfaces/IAvUSDMinting.sol';
import '../contracts/mock/MockToken.sol';

contract AvalancheFullDeployment is Script, DeploymentUtils {
  //
  // ┌─────────────────────────────────────────────────────────────┐
  // | Setup                                                       |
  // └─────────────────────────────────────────────────────────────┘

  uint256 public constant MAX_AVUSD_MINT_PER_BLOCK = 100_000e18;
  uint256 public constant MAX_AVUSD_REDEEM_PER_BLOCK = 100_000e18;
  address public constant USDC_ADDRESS = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
  address public constant WAVAX_ADDRESS = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
  address public constant FIREBLOCKS_CUSTODIAN_ADDRESS = 0x3BbCb84fCDE71063D8C396e6C54F5dC3D19EE0EC;
  address public constant AUTO_MINTER_ADDRESS = 0x7A8B07Ea80E613efa89e6473b54bA5a2778C5da8;
  address public constant REEDEMER_ADDRESS_1 = 0x1ccEeDcc3A80B19dD92C587aEAAdA7DACBEA270E; // S
  address public constant REEDEMER_ADDRESS_2 = 0x1d1CfD4FfB8cFD0A903A38c3B41D593369B46103; // L
  address public constant REEDEMER_ADDRESS_3 = 0x52ddA360595B4335872a3E47A9dE160Aa1acC979; // C
  
  function run() public virtual {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    address deployerAddress = vm.addr(deployerPrivateKey);
    uint256 deployerBalance = deployerAddress.balance;
    console.log('Deployer -> %s', deployerAddress);
    console.log('Balance -> %s', deployerBalance);

    vm.startBroadcast(deployerPrivateKey);

    console.log('Deploying AvUSD...');
    AvUSD avUSD = new AvUSD(deployerAddress);
    console.log('Deployed AvUSD to %s', address(avUSD));

    // Checks the AvUSD owner
    _utilsIsOwner(deployerAddress, address(avUSD));

    console.log('Deploying StakedAvUSDV2...');
    StakedAvUSDV2 stakedAvUSDV2 = new StakedAvUSDV2(
      avUSD, // vault asset
      deployerAddress, // initial rewarder
      deployerAddress // owner
    );
    console.log('Deployed StakedAvUSDV2 to %s', address(stakedAvUSDV2));

    // Checks the staking owner and admin
    _utilsIsOwner(deployerAddress, address(stakedAvUSDV2));
    _utilsHasRole(stakedAvUSDV2.DEFAULT_ADMIN_ROLE(), deployerAddress, address(stakedAvUSDV2));

    // AvUSD Minting
    address[] memory assets = new address[](1);
    assets[0] = address(USDC_ADDRESS);

    address[] memory custodians = new address[](1);
    custodians[0] = FIREBLOCKS_CUSTODIAN_ADDRESS;

    console.log('Deploying AvUSDMinting...');
    AvUSDMinting avUSDMinting = new AvUSDMinting(
      IAvUSD(address(avUSD)),
      IWAVAX(WAVAX_ADDRESS),
      assets,
      custodians,
      deployerAddress, // admin
      MAX_AVUSD_MINT_PER_BLOCK,
      MAX_AVUSD_REDEEM_PER_BLOCK
    );
    console.log('Deployed AvUSDMinting to %s', address(avUSDMinting));

    // give minting contract AvUSD minter role
    avUSD.setMinter(address(avUSDMinting), true);

    // Checks the minting owner and admin
    _utilsIsOwner(deployerAddress, address(avUSDMinting));
    _utilsHasRole(avUSDMinting.DEFAULT_ADMIN_ROLE(), deployerAddress, address(avUSDMinting));

    // grantees of the minter role
    bytes32 MINTER_ROLE = keccak256('MINTER_ROLE');
    avUSDMinting.grantRole(MINTER_ROLE, AUTO_MINTER_ADDRESS);

    // grantees of the redeemer role
    bytes32 REDEEMER_ROLE = keccak256('REDEEMER_ROLE');
    avUSDMinting.grantRole(REDEEMER_ROLE, REEDEMER_ADDRESS_1);
    avUSDMinting.grantRole(REDEEMER_ROLE, REEDEMER_ADDRESS_2);
    avUSDMinting.grantRole(REDEEMER_ROLE, REEDEMER_ADDRESS_3);

    uint256 finalDeployerBalance = deployerAddress.balance;
    console.log('Cost -> %s', deployerBalance - finalDeployerBalance);
    console.log('Balance -> %s', finalDeployerBalance);

    vm.stopBroadcast();
  }
}

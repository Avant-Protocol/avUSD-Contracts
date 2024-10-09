// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./DeploymentUtils.sol";
import "forge-std/Script.sol";
import "../contracts/AvUSD.sol";
import "../contracts/interfaces/IAvUSD.sol";
import "../contracts/interfaces/IAvUSDMinting.sol";
import "../contracts/AvUSDMinting.sol";

contract MainnetMintDeployment is Script, DeploymentUtils {
  struct Contracts {
    // E-tokens
    AvUSD AvUSDToken;
    // E-contracts
    AvUSDMinting avUSDMintingContract;
  }

  struct Configuration {
    // Roles
    bytes32 AvUSDMinterRole;
  }

  address public constant ZERO_ADDRESS = address(0);
  address public constant WAVAX_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  uint256 public constant MAX_AVUSD_MINT_PER_BLOCK = 100_000e18;
  uint256 public constant MAX_AVUSD_REDEEM_PER_BLOCK = 100_000e18;

  function run() public virtual {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    deployment(deployerPrivateKey);
  }

  function deployment(uint256 deployerPrivateKey) public returns (Contracts memory) {
    address deployerAddress = vm.addr(deployerPrivateKey);
    Contracts memory contracts;

    vm.startBroadcast(deployerPrivateKey);

    contracts.AvUSDToken = new AvUSD(deployerAddress);
    IAvUSD iAvUSD = IAvUSD(address(contracts.AvUSDToken));

    // AvUSD Minting
    address[] memory assets = new address[](6);
    assets[0] = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    assets[1] = address(0xae78736Cd615f374D3085123A210448E74Fc6393);
    assets[2] = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    assets[3] = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    assets[4] = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    assets[5] = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    address[] memory custodians = new address[](1);
    // copper address
    custodians[0] = address(0x6b95F243959329bb88F5D3Df9A7127Efba703fDA);

    contracts.avUSDMintingContract = new AvUSDMinting(
      iAvUSD,
      IWAVAX(WAVAX_ADDRESS),
      assets,
      custodians,
      deployerAddress,
      MAX_AVUSD_MINT_PER_BLOCK,
      MAX_AVUSD_REDEEM_PER_BLOCK
    );

    // Set minter role
    contracts.AvUSDToken.setMinter(address(contracts.avUSDMintingContract), true);

    console.log("AvUSD Deployed");
    vm.stopBroadcast();

    // Logs
    console.log("=====> Minting AvUSD contracts deployed ....");
    console.log("AvUSD                          : https://etherscan.io/address/%s", address(contracts.AvUSDToken));
    console.log(
      "AvUSD Minting                  : https://etherscan.io/address/%s", address(contracts.avUSDMintingContract)
    );
    return contracts;
  }
}

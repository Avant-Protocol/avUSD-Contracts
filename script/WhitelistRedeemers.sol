// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import "../contracts/AvUSD.sol";
import "../contracts/interfaces/IAvUSDMinting.sol";
import "../contracts/AvUSDMinting.sol";

contract WhitelistRedeemers is Script {
  address public avUSDMintingAddress;

  function run() public virtual {
    uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(ownerPrivateKey);
    // update to correct AvUSDMinting address
    avUSDMintingAddress = address(0xdD1389FED934314091A3d2DB479F6253de8a4b8f);
    AvUSDMinting avUSDMinting = AvUSDMinting(payable(avUSDMintingAddress));
    bytes32 role = keccak256("REDEEMER_ROLE");

    // update array size and grantee addresses
    address[] memory grantees = new address[](2);
    grantees[0] = address(0xA5Ab0683d4f4AD107766a9fc4dDd49B5a960e661); // Avalanche Deployer
    grantees[1] = address(0xd320652488AB35aad89fc8b2d9d1B3eb8516b1e9); // Cory

    for (uint256 i = 0; i < grantees.length; ++i) {
      if (!avUSDMinting.hasRole(role, grantees[i])) {
        avUSDMinting.grantRole(role, grantees[i]);
      }
    }
    vm.stopBroadcast();
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import "../contracts/AvUSD.sol";
import "../contracts/interfaces/IAvUSDMinting.sol";
import "../contracts/AvUSDMinting.sol";

contract WhitelistMinters is Script {
  address public avUSDMintingAddress;

  function run() public virtual {
    uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(ownerPrivateKey);
    // update to correct AvUSDMinting address
    avUSDMintingAddress = address(0x769eFeAfdE17Cf82722493881db107eF709A051a);
    AvUSDMinting avUSDMinting = AvUSDMinting(payable(avUSDMintingAddress));
    bytes32 avUSDMintingMinterRole = keccak256("MINTER_ROLE");

    // update array size and grantee addresses
    address[] memory grantees = new address[](1);
    grantees[0] = address(0xE183B9cB073B83c74DDff041748E162cac1b8e1a);

    for (uint256 i = 0; i < grantees.length; ++i) {
      if (!avUSDMinting.hasRole(avUSDMintingMinterRole, grantees[i])) {
        avUSDMinting.grantRole(avUSDMintingMinterRole, grantees[i]);
      }
    }
    vm.stopBroadcast();
  }
}

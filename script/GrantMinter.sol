// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import "../contracts/AvUSD.sol";
import "../contracts/interfaces/IAvUSDMinting.sol";
import "../contracts/AvUSDMinting.sol";
import "../contracts/AvUSD.sol";

contract GrantMinter is Script {
  address public avUSDMintingAddress;

  function run() public virtual {
    uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(ownerPrivateKey);
    // update to correct AvUSDMinting address
    avUSDMintingAddress = address(0xdD1389FED934314091A3d2DB479F6253de8a4b8f);
    AvUSD avusdToken = AvUSD(address(0x8c4774fC52477fE4bDB46a5189bFeccA64BAD5f2));

    // update array size and grantee addresses

    avusdToken.setMinter(avUSDMintingAddress);

    vm.stopBroadcast();
  }
}

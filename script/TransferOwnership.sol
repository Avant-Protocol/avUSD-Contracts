// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import "../contracts/AvUSD.sol";
import "../contracts/interfaces/IAvUSDMinting.sol";
import "../contracts/AvUSDMinting.sol";
import "../contracts/mock/MockToken.sol";

contract TransferOwnership is Script {
  // update accordingly
  address public avUSDMintingAddress = address(0x8543703e1e9d4bCe16ae1C6f73c43F7CEBF99808);
  address public avusdAddress = address(0x400835DB609170D1c268bF0d8039b3644Cf7793B);
  address public mockStethAddress = address(0xc1549616F39fCDE5400236bafF09bC66e590036A);
  address public realStethAddress = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
  address public newOwner = address(0x9a073D235A8D2C37854Da6f6A8F075C916debe06);

  function run() public virtual {
    uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(ownerPrivateKey);
    AvUSDMinting avUSDMinting = AvUSDMinting(payable(avUSDMintingAddress));
    AvUSD avusdToken = AvUSD(avusdAddress);
    MockToken stEthToken = MockToken(mockStethAddress);

    // mint some mock token to new owner for testing
    stEthToken.mint(100_000 ether, newOwner);

    // add real stETH as minting asset
    avUSDMinting.addSupportedAsset(realStethAddress);

    // give new owner default admin role
    avUSDMinting.grantRole(avUSDMinting.DEFAULT_ADMIN_ROLE(), newOwner);

    avusdToken.transferOwnership(newOwner);

    vm.stopBroadcast();
  }
}

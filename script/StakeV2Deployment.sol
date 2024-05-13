// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import 'forge-std/Script.sol';
import '../contracts/StakedAvUSDV2.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';

contract StakeV2Deployment is Script {
  // update accordingly
  address public avusdAddress = address(0x8c4774fC52477fE4bDB46a5189bFeccA64BAD5f2);
  address public rewarder = address(0xA5Ab0683d4f4AD107766a9fc4dDd49B5a960e661);
  address public owner = address(0xA5Ab0683d4f4AD107766a9fc4dDd49B5a960e661);

  function run() public virtual {
    uint256 ownerPrivateKey = uint256(vm.envBytes32('PRIVATE_KEY'));
    vm.startBroadcast(ownerPrivateKey);
    StakedAvUSDV2 stakedAvUSD = new StakedAvUSDV2(IERC20(avusdAddress), rewarder, owner);
    vm.stopBroadcast();

    console.log('=====> StakedAvUSDV2 deployed ....');
    console.log('StakedAvUSDV2: https://etherscan.io/address/%s', address(stakedAvUSD));
  }
}

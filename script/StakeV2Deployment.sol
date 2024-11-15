// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import 'forge-std/Script.sol';
import '../contracts/StakedAvUSDV2.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';

contract StakeV2Deployment is Script {
  // update accordingly
  address public avusdAddress = address(0xF1c0DB770e77a961efde9DD11216e3833ad5c588);
  address public rewarder = address(0x19596e1D6cd97916514B5DBaA4730781eFE49975);
  address public owner = address(0x19596e1D6cd97916514B5DBaA4730781eFE49975);

  function run() public virtual {
    uint256 ownerPrivateKey = uint256(vm.envBytes32('PRIVATE_KEY'));
    vm.startBroadcast(ownerPrivateKey);
    StakedAvUSDV2 stakedAvUSD = new StakedAvUSDV2(IERC20(avusdAddress), rewarder, owner);
    stakedAvUSD.setCooldownDuration(1 hours);
    vm.stopBroadcast();

    console.log('=====> StakedAvUSDV2 deployed ....');
    console.log('StakedAvUSDV2: %s', address(stakedAvUSD));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "./FullDeployment.sol";
import "forge-std/Vm.sol";

contract E2eTestingDeployment is Script, FullDeployment {
  address constant _DEFAULT_TEST_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  uint256 constant _DEFAULT_MOCK_TOKEN_PRICE = 1900e18;
  uint256 constant _DEFAULT_TEST_DEPOSIT_SIZE = 5;

  function run() public override {
    uint256 deployerPrivateKey = vm.envUint("TEST_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    // Take the passed test address or the default testing address
    address testerAddress = vm.envOr("TEST_ADDRESS", _DEFAULT_TEST_ADDRESS);
    Contracts memory deployedContracts = deployment(deployerPrivateKey);

    vm.startBroadcast(deployerPrivateKey);
    deployedContracts.AvUSDToken.setMinter(deployer, true);
    deployedContracts.AvUSDToken.mint(testerAddress, _DEFAULT_MOCK_TOKEN_PRICE * _DEFAULT_TEST_DEPOSIT_SIZE);
    deployedContracts.AvUSDToken.setMinter(deployer, false);
    deployedContracts.AvUSDToken.setMinter(address(deployedContracts.avUSDMintingContract), true);
    vm.stopBroadcast();
  }
}

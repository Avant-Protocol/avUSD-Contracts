// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/* solhint-disable var-name-mixedcase  */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/interfaces/IAvUSDSiloDefinitions.sol";

/**
 * @title AvUSDSilo
 * @notice The Silo allows to store avUSD during the stake cooldown process.
 */
contract AvUSDSilo is IAvUSDSiloDefinitions {
  address immutable _STAKING_VAULT;
  IERC20 immutable _AVUSD;

  constructor(address stakingVault, address avusd) {
    _STAKING_VAULT = stakingVault;
    _AVUSD = IERC20(avusd);
  }

  modifier onlyStakingVault() {
    if (msg.sender != _STAKING_VAULT) revert OnlyStakingVault();
    _;
  }

  function withdraw(address to, uint256 amount) external onlyStakingVault {
    _AVUSD.transfer(to, amount);
  }
}
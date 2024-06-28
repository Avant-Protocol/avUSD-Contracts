// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/* solhint-disable var-name-mixedcase  */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../contracts/interfaces/IAvUSDSiloDefinitions.sol";

/**
 * @title AvUSDSilo
 * @notice The Silo allows to store avUSD during the stake cooldown process.
 */
contract AvUSDSilo is IAvUSDSiloDefinitions {
  using SafeERC20 for IERC20;

  address immutable public _STAKING_VAULT;
  IERC20 immutable public _AVUSD;

  error ZeroAddressError();

  constructor(address stakingVault, address avusd) {
    if (stakingVault == address(0) || avusd == address(0)) {
      revert ZeroAddressError();
    }
    _STAKING_VAULT = stakingVault;
    _AVUSD = IERC20(avusd);
  }

  modifier onlyStakingVault() {
    if (msg.sender != _STAKING_VAULT) revert OnlyStakingVault();
    _;
  }

  function withdraw(address to, uint256 amount) external onlyStakingVault {
    _AVUSD.safeTransfer(to, amount);
  }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/* solhint-disable var-name-mixedcase  */

import "./IAvUSDMintingEvents.sol";

interface IAvUSDMinting is IAvUSDMintingEvents {

  enum OrderType {
    MINT,
    REDEEM
  }

  enum SignatureType {
    EIP712,
    EIP1271
  }

  enum DelegatedSignerStatus {
    REJECTED,
    PENDING, 
    ACCEPTED 
  }

  struct Signature {
    SignatureType signature_type;
    bytes signature_bytes;
  }

  struct Route {
    address[] addresses;
    uint256[] ratios;
  }

  struct Order {
    OrderType order_type;
    uint256 expiry;
    uint256 nonce;
    address benefactor;
    address beneficiary;
    address collateral_asset;
    uint256 collateral_amount;
    uint256 avusd_amount;
  }

  error InvalidAddress();
  error InvalidAvUSDAddress();
  error InvalidZeroAddress();
  error InvalidAssetAddress();
  error InvalidCustodianAddress();
  error InvalidOrder();
  error InvalidAmount();
  error InvalidRoute();
  error UnsupportedAsset();
  error NoAssetsProvided();
  error InvalidCollateralToStablecoinRatio();
  error InvalidSignature();
  error InvalidEIP712Signature();
  error InvalidEIP1271Signature();
  error InvalidNonce();
  error SignatureExpired();
  error TransferFailed();
  error MaxMintPerBlockExceeded();
  error MaxRedeemPerBlockExceeded();
  error DelegationNotInitiated();

  function addSupportedAsset(address asset) external;
  
  function hashOrder(Order calldata order) external view returns (bytes32);

  function verifyOrder(Order calldata order, Signature calldata signature) external view returns (bytes32);

  function verifyRoute(Route calldata route) external view returns (bool);

  function verifyNonce(address sender, uint256 nonce) external view returns (uint256, uint256, uint256);

  function mint(Order calldata order, Route calldata route, Signature calldata signature) external;

  function redeem(Order calldata order, Signature calldata signature) external;
}
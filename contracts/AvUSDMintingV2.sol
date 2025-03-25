// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable var-name-mixedcase */

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./SingleAdminAccessControl.sol";
import "./interfaces/IAvUSDMinting.sol";
import "./interfaces/IAvUSD.sol";

/**
 * @title AvUSD Minting
 * @notice This contract mints and redeems avUSD
 */
contract AvUSDMintingV2 is IAvUSDMinting, SingleAdminAccessControl, ReentrancyGuard {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  /* --------------- CONSTANTS --------------- */

  /// @notice EIP712 domain
  bytes32 private constant EIP712_DOMAIN =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

  /// @notice route type
  bytes32 private constant ROUTE_TYPE = keccak256("Route(address[] addresses,uint256[] ratios)");

  /// @notice order type
  bytes32 private constant ORDER_TYPE = keccak256(
    "Order(uint8 order_type,uint256 expiry,uint256 nonce,address benefactor,address beneficiary,address collateral_asset,uint256 collateral_amount,uint256 avusd_amount)"
  );

  /// @notice role enabling to invoke mint
  bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");

  /// @notice role enabling to invoke redeem
  bytes32 private constant REDEEMER_ROLE = keccak256("REDEEMER_ROLE");

  /// @notice role enabling to transfer collateral to custody wallets
  bytes32 private constant COLLATERAL_MANAGER_ROLE = keccak256("COLLATERAL_MANAGER_ROLE");

  /// @notice role enabling to disable mint and redeem and remove minters and redeemers in an emergency
  bytes32 private constant GATEKEEPER_ROLE = keccak256("GATEKEEPER_ROLE");

  /// @notice EIP712 domain hash
  bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(abi.encodePacked(EIP712_DOMAIN));

  /// @notice EIP 1271 magic value hash
  bytes4 private constant EIP1271_MAGICVALUE = bytes4(keccak256("isValidSignature(bytes32,bytes)"));

  /// @notice address denoting native ether
  address private constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /// @notice EIP712 name
  bytes32 private constant EIP_712_NAME = keccak256("AvUSDMinting");

  /// @notice holds EIP712 revision
  bytes32 private constant EIP712_REVISION = keccak256("1");

  /// @notice required ratio for route
  uint256 private constant ROUTE_REQUIRED_RATIO = 100_00; // 100%

  /// @notice stablecoin price ratio multiplier
  uint128 private constant STABLES_RATIO_MULTIPLIER = 100_00;

  /* --------------- STATE VARIABLES --------------- */

  /// @notice avusd stablecoin
  IAvUSD public immutable avusd;

  /// @notice Supported assets
  EnumerableSet.AddressSet internal _supportedAssets;

  // @notice custodian addresses
  EnumerableSet.AddressSet internal _custodianAddresses;

  /// @notice holds computable chain id
  uint256 private immutable _chainId;

  /// @notice holds computable domain separator
  bytes32 private immutable _domainSeparator;

  /// @notice user deduplication
  mapping(address => mapping(uint256 => uint256)) private _orderBitmaps;

  // @notice the allowed price delta in bps for stablecoin minting
  uint128 public stablesDeltaLimit;
  
  /// @notice avUSD minted per block
  mapping(uint256 => uint256) public mintedPerBlock;
  
  /// @notice avUSD redeemed per block
  mapping(uint256 => uint256) public redeemedPerBlock;

  /// @notice For smart contracts to delegate signing to EOA address
  mapping(address => mapping(address => DelegatedSignerStatus)) public delegatedSigner;

  /// @notice max minted avUSD allowed per block
  uint256 public maxMintPerBlock;
  
  /// @notice max redeemed avUSD allowed per block
  uint256 public maxRedeemPerBlock;

  /* --------------- MODIFIERS --------------- */

  /// @notice ensure that the already minted avUSD in the actual block plus the amount to be minted is below the maxMintPerBlock var
  /// @param mintAmount The avUSD amount to be minted
  modifier belowMaxMintPerBlock(uint256 mintAmount) {
    if (mintedPerBlock[block.number] + mintAmount > maxMintPerBlock) revert MaxMintPerBlockExceeded();
    // Add to the minted amount in this block
    mintedPerBlock[block.number] += mintAmount;
    _;
  }

  /// @notice ensure that the already redeemed avUSD in the actual block plus the amount to be redeemed is below the maxRedeemPerBlock var
  /// @param redeemAmount The avUSD amount to be redeemed
  modifier belowMaxRedeemPerBlock(uint256 redeemAmount) {
    if (redeemedPerBlock[block.number] + redeemAmount > maxRedeemPerBlock) revert MaxRedeemPerBlockExceeded();
    // Add to the redeemed amount in this block
    redeemedPerBlock[block.number] += redeemAmount;
    _;
  }

  /* --------------- CONSTRUCTOR --------------- */

  constructor(
    IAvUSD _avusd,
    address[] memory _assets,
    address[] memory _custodians,
    address _admin,
    uint256 _maxMintPerBlock,
    uint256 _maxRedeemPerBlock
  ) {
    if (address(_avusd) == address(0)) revert InvalidAvUSDAddress();
    if (_assets.length == 0) revert NoAssetsProvided();
    if (_admin == address(0)) revert InvalidZeroAddress();
    avusd = _avusd;

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

    for (uint256 i = 0; i < _assets.length;) {
      addSupportedAsset(_assets[i]);
      unchecked {
        ++i;
      }
    }

    for (uint256 j = 0; j < _custodians.length;) {
      addCustodianAddress(_custodians[j]);
      unchecked {
        ++j;
      }
    }

    // Set the max mint/redeem limits per block
    _setMaxMintPerBlock(_maxMintPerBlock);
    _setMaxRedeemPerBlock(_maxRedeemPerBlock);

    if (msg.sender != _admin) {
      _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    _chainId = block.chainid;
    _domainSeparator = _computeDomainSeparator();

    emit AvUSDSet(address(_avusd));
  }

  /* --------------- EXTERNAL --------------- */

  /**
   * @notice Fallback function to receive ether
   */
  receive() external payable {
    emit Received(msg.sender, msg.value);
  }

  /**
   * @notice Mint stablecoins from assets
   * @param order struct containing order details and confirmation from server
   * @param signature signature of the taker
   */
  function mint(Order calldata order, Route calldata route, Signature calldata signature)
    external
    override
    nonReentrant
    onlyRole(MINTER_ROLE)
    belowMaxMintPerBlock(order.avusd_amount)
  {
    if (order.order_type != OrderType.MINT) revert InvalidOrder();
    verifyOrder(order, signature);
    if (!verifyRoute(route)) revert InvalidRoute();

    _deduplicateOrder(order.benefactor, order.nonce);

    _transferCollateral(
      order.collateral_amount, order.collateral_asset, order.benefactor, route.addresses, route.ratios
    );

    avusd.mint(order.beneficiary, order.avusd_amount);
    emit Mint(
      msg.sender,
      order.benefactor,
      order.beneficiary,
      order.collateral_asset,
      order.collateral_amount,
      order.avusd_amount
    );
  }

  /**
   * @notice Redeem stablecoins for assets
   * @param order struct containing order details and confirmation from server
   * @param signature signature of the taker
   */
  function redeem(Order calldata order, Signature calldata signature)
    external
    override
    nonReentrant
    onlyRole(REDEEMER_ROLE)
    belowMaxRedeemPerBlock(order.avusd_amount)
  {
    if (order.order_type != OrderType.REDEEM) revert InvalidOrder();
    verifyOrder(order, signature);
    _deduplicateOrder(order.benefactor, order.nonce);
    avusd.burnFrom(order.benefactor, order.avusd_amount);
    _transferToBeneficiary(order.beneficiary, order.collateral_asset, order.collateral_amount);
    emit Redeem(
      msg.sender,
      order.benefactor,
      order.beneficiary,
      order.collateral_asset,
      order.collateral_amount,
      order.avusd_amount
    );
  }

  /// @notice Sets the max mintPerBlock limit
  function setMaxMintPerBlock(uint256 _maxMintPerBlock) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setMaxMintPerBlock(_maxMintPerBlock);
  }

  /// @notice Sets the max redeemPerBlock limit
  function setMaxRedeemPerBlock(uint256 _maxRedeemPerBlock) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setMaxRedeemPerBlock(_maxRedeemPerBlock);
  }

  /// @notice Disables the mint and redeem
  function disableMintRedeem() external onlyRole(GATEKEEPER_ROLE) {
    _setMaxMintPerBlock(0);
    _setMaxRedeemPerBlock(0);
  }

  /// @notice Enables smart contracts to delegate an address for signing
  function setDelegatedSigner(address _delegateTo) external {
    delegatedSigner[_delegateTo][msg.sender] = DelegatedSignerStatus.PENDING;
    emit DelegatedSignerInitiated(_delegateTo, msg.sender);
  }

  /// @notice The delegated address to confirm delegation
  function confirmDelegatedSigner(address _delegatedBy) external {
    mapping(address => DelegatedSignerStatus) storage delegatedStatus = delegatedSigner[msg.sender];
    if (delegatedStatus[_delegatedBy] != DelegatedSignerStatus.PENDING) {
      revert DelegationNotInitiated();
    }
    delegatedStatus[_delegatedBy] = DelegatedSignerStatus.ACCEPTED;
    emit DelegatedSignerAdded(msg.sender, _delegatedBy);
  }

  /// @notice Enables smart contracts to undelegate an address for signing
  function removeDelegatedSigner(address _removedSigner) external {
    delegatedSigner[_removedSigner][msg.sender] = DelegatedSignerStatus.REJECTED;
    emit DelegatedSignerRemoved(_removedSigner, msg.sender);
  }

  /// @notice transfers an asset to a custody wallet
  function transferToCustody(address wallet, address asset, uint256 amount)
    external
    nonReentrant
    onlyRole(COLLATERAL_MANAGER_ROLE)
  {
    if (wallet == address(0) || !_custodianAddresses.contains(wallet)) revert InvalidAddress();
    if (asset == NATIVE_TOKEN) {
      (bool success,) = wallet.call{value: amount}("");
      if (!success) revert TransferFailed();
    } else {
      IERC20(asset).safeTransfer(wallet, amount);
    }
    emit CustodyTransfer(wallet, asset, amount);
  }

  /// @notice Removes an asset from the supported assets list
  function removeSupportedAsset(address asset) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (!_supportedAssets.remove(asset)) revert InvalidAssetAddress();
    emit AssetRemoved(asset);
  }

  /// @notice Checks if an asset is supported.
  function isSupportedAsset(address asset) external view returns (bool) {
    return _supportedAssets.contains(asset);
  }

  /// @notice Removes an custodian from the custodian address list
  function removeCustodianAddress(address custodian) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (!_custodianAddresses.remove(custodian)) revert InvalidCustodianAddress();
    emit CustodianAddressRemoved(custodian);
  }

  /// @notice Removes the minter role from an account, this can ONLY be executed by the gatekeeper role
  /// @param minter The address to remove the minter role from
  function removeMinterRole(address minter) external onlyRole(GATEKEEPER_ROLE) {
    _revokeRole(MINTER_ROLE, minter);
  }

  /// @notice Removes the redeemer role from an account, this can ONLY be executed by the gatekeeper role
  /// @param redeemer The address to remove the redeemer role from
  function removeRedeemerRole(address redeemer) external onlyRole(GATEKEEPER_ROLE) {
    _revokeRole(REDEEMER_ROLE, redeemer);
  }

  /// @notice Removes the collateral manager role from an account, this can ONLY be executed by the gatekeeper role
  /// @param collateralManager The address to remove the collateralManager role from
  function removeCollateralManagerRole(address collateralManager) external onlyRole(GATEKEEPER_ROLE) {
    _revokeRole(COLLATERAL_MANAGER_ROLE, collateralManager);
  }

  /// @notice set the allowed price delta in bps for stablecoin minting
  function setStablesDeltaLimit(uint128 _stablesDeltaLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
    stablesDeltaLimit = _stablesDeltaLimit;
  }

  /* --------------- PUBLIC --------------- */

  /// @notice Adds an asset to the supported assets list.
  function addSupportedAsset(address asset) public onlyRole(DEFAULT_ADMIN_ROLE) {
    if (asset == address(0) || asset == address(avusd) || !_supportedAssets.add(asset)) {
      revert InvalidAssetAddress();
    }
    emit AssetAdded(asset);
  }

  /// @notice Adds an custodian to the supported custodians list.
  function addCustodianAddress(address custodian) public onlyRole(DEFAULT_ADMIN_ROLE) {
    if (custodian == address(0) || custodian == address(avusd) || !_custodianAddresses.add(custodian)) {
      revert InvalidCustodianAddress();
    }
    emit CustodianAddressAdded(custodian);
  }

  /// @notice Get the domain separator for the token
  /// @dev Return cached value if chainId matches cache, otherwise recomputes separator, to prevent replay attack across forks
  /// @return The domain separator of the token at current chain
  function getDomainSeparator() public view returns (bytes32) {
    if (block.chainid == _chainId) {
      return _domainSeparator;
    }
    return _computeDomainSeparator();
  }

  /// @notice hash an Order struct
  function hashOrder(Order calldata order) public view override returns (bytes32) {
    return MessageHashUtils.toTypedDataHash(getDomainSeparator(), keccak256(encodeOrder(order)));
  }

  function encodeOrder(Order calldata order) public pure returns (bytes memory) {
    return abi.encode(
      ORDER_TYPE,
      order.order_type,
      order.expiry,
      order.nonce,
      order.benefactor,
      order.beneficiary,
      order.collateral_asset,
      order.collateral_amount,
      order.avusd_amount
    );
  }

  /// @notice assert validity of signed order
  function verifyOrder(Order calldata order, Signature calldata signature)
    public
    view
    override
    returns (bytes32 taker_order_hash)
  {
    taker_order_hash = hashOrder(order);
    if (signature.signature_type == SignatureType.EIP712) {
      address signer = ECDSA.recover(taker_order_hash, signature.signature_bytes);
      if (signer != order.benefactor && delegatedSigner[signer][order.benefactor] != DelegatedSignerStatus.ACCEPTED) {
        revert InvalidEIP712Signature();
      }
    } else {
      // SignatureType == EIP1271
      if (
        IERC1271(order.benefactor).isValidSignature(taker_order_hash, signature.signature_bytes) != EIP1271_MAGICVALUE
      ) {
        revert InvalidEIP1271Signature();
      }
    }
    if (order.beneficiary == address(0)) revert InvalidAddress();
    if (order.collateral_amount == 0) revert InvalidAmount();
    if (order.avusd_amount == 0) revert InvalidAmount();
    if (block.timestamp > order.expiry) revert SignatureExpired();
    if (!_checkCollateralToStablecoinRatio(order.collateral_amount, order.avusd_amount, order.collateral_asset, order.order_type)) {
      revert InvalidCollateralToStablecoinRatio();
    }
  }


  /// @notice assert validity of route object per type
  function verifyRoute(Route calldata route) public view override returns (bool) {
    uint256 totalRatio = 0;
    if (route.addresses.length != route.ratios.length) {
      return false;
    }
    if (route.addresses.length == 0) {
      return false;
    }
    for (uint256 i = 0; i < route.addresses.length;) {
      if (!_custodianAddresses.contains(route.addresses[i]) || route.addresses[i] == address(0) || route.ratios[i] == 0)
      {
        return false;
      }
      totalRatio += route.ratios[i];
      unchecked {
        ++i;
      }
    }
    return totalRatio == ROUTE_REQUIRED_RATIO;
  }

  /// @notice verify validity of nonce by checking its presence
  function verifyNonce(address sender, uint256 nonce) public view override returns (uint256, uint256, uint256) {
    if (nonce == 0 || nonce > type(uint64).max) revert InvalidNonce();
    uint256 invalidatorSlot = uint64(nonce) >> 8;
    uint256 invalidatorBit = 1 << uint8(nonce);
    uint256 invalidator = _orderBitmaps[sender][invalidatorSlot];
    if (invalidator & invalidatorBit != 0) revert InvalidNonce();

    return (invalidatorSlot, invalidator, invalidatorBit);
  }

  /* --------------- PRIVATE --------------- */

  /// @notice deduplication of taker order
  function _deduplicateOrder(address sender, uint256 nonce) private {
    (uint256 invalidatorSlot, uint256 invalidator, uint256 invalidatorBit) = verifyNonce(sender, nonce);
    _orderBitmaps[sender][invalidatorSlot] = invalidator | invalidatorBit;
  }

  /* --------------- INTERNAL --------------- */

  function _checkCollateralToStablecoinRatio(
    uint256 collateralAmount,
    uint256 avusdAmount,
    address collateralAsset,
    OrderType orderType
  ) internal view returns (bool) {
    uint8 avusdDecimals = IERC20Metadata(address(avusd)).decimals();
    uint8 collateralDecimals = IERC20Metadata(address(collateralAsset)).decimals();

    uint256 scale;
    uint256 normalizedCollateralAmount;
    uint256 difference;

    unchecked {
      scale = avusdDecimals > collateralDecimals
          ? 10 ** (avusdDecimals - collateralDecimals)
          : 10 ** (collateralDecimals - avusdDecimals);
    }

    normalizedCollateralAmount = avusdDecimals > collateralDecimals ? collateralAmount * scale : collateralAmount / scale;

    unchecked {
      difference = normalizedCollateralAmount > avusdAmount
        ? normalizedCollateralAmount - avusdAmount
        : avusdAmount - normalizedCollateralAmount;
    }

    uint256 differenceInBps = (difference * STABLES_RATIO_MULTIPLIER) / avusdAmount;

    if (orderType == OrderType.MINT) {
      return avusdAmount > normalizedCollateralAmount ? differenceInBps <= stablesDeltaLimit : true;
    } else {
      return normalizedCollateralAmount > avusdAmount ? differenceInBps <= stablesDeltaLimit : true;
    }
  }

  /// @notice transfer supported asset to beneficiary address
  function _transferToBeneficiary(address beneficiary, address asset, uint256 amount) internal {
    if (asset == NATIVE_TOKEN) {
      if (address(this).balance < amount) revert InvalidAmount();
      (bool success,) = (beneficiary).call{value: amount}("");
      if (!success) revert TransferFailed();
    } else {
      if (!_supportedAssets.contains(asset)) revert UnsupportedAsset();
      IERC20(asset).safeTransfer(beneficiary, amount);
    }
  }

  /// @notice transfer supported asset to array of custody addresses per defined ratio
  function _transferCollateral(
    uint256 amount,
    address asset,
    address benefactor,
    address[] calldata addresses,
    uint256[] calldata ratios
  ) internal {
    // cannot mint using unsupported asset or native ETH even if it is supported for redemptions
    if (!_supportedAssets.contains(asset) || asset == NATIVE_TOKEN) revert UnsupportedAsset();
    IERC20 token = IERC20(asset);
    uint256 totalTransferred = 0;
    for (uint256 i = 0; i < addresses.length - 1;) {
      uint256 amountToTransfer = (amount * ratios[i]) / ROUTE_REQUIRED_RATIO;
      token.safeTransferFrom(benefactor, addresses[i], amountToTransfer);
      totalTransferred += amountToTransfer;
      unchecked {
        ++i;
      }
    }
    uint256 remainingBalance = amount - totalTransferred;
    token.safeTransferFrom(benefactor, addresses[addresses.length - 1], remainingBalance);
  }

  /// @notice Sets the max mintPerBlock limit
  function _setMaxMintPerBlock(uint256 _maxMintPerBlock) internal {
    uint256 oldMaxMintPerBlock = maxMintPerBlock;
    maxMintPerBlock = _maxMintPerBlock;
    emit MaxMintPerBlockChanged(oldMaxMintPerBlock, _maxMintPerBlock);
  }

  /// @notice Sets the max redeemPerBlock limit
  function _setMaxRedeemPerBlock(uint256 _maxRedeemPerBlock) internal {
    uint256 oldMaxRedeemPerBlock = maxRedeemPerBlock;
    maxRedeemPerBlock = _maxRedeemPerBlock;
    emit MaxRedeemPerBlockChanged(oldMaxRedeemPerBlock, _maxRedeemPerBlock);
  }

  /// @notice Compute the current domain separator
  /// @return The domain separator for the token
  function _computeDomainSeparator() internal view returns (bytes32) {
    return keccak256(abi.encode(EIP712_DOMAIN, EIP_712_NAME, EIP712_REVISION, block.chainid, address(this)));
  }
}
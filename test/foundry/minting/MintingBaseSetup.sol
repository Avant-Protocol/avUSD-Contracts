// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/* solhint-disable private-vars-leading-underscore  */
/* solhint-disable func-name-mixedcase  */
/* solhint-disable var-name-mixedcase  */

import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {SigUtils} from "forge-std/SigUtils.sol";
import {Vm} from "forge-std/Vm.sol";
import {Utils} from "../../utils/Utils.sol";

import "../../../contracts/mock/MockToken.sol";
import "../../../contracts/AvUSD.sol";
import "../../../contracts/interfaces/IAvUSDMinting.sol";
import "../../../contracts/interfaces/IAvUSDMintingEvents.sol";
import "../../../contracts/AvUSDMinting.sol";
import "../../../contracts/interfaces/ISingleAdminAccessControl.sol";
import "../../../contracts/interfaces/IAvUSDDefinitions.sol";

contract MintingBaseSetup is Test, IAvUSDMintingEvents, IAvUSDDefinitions {
  Utils internal utils;
  AvUSD internal avusdToken;
  MockToken internal stETHToken;
  MockToken internal cbETHToken;
  MockToken internal rETHToken;
  MockToken internal USDCToken;
  MockToken internal USDTToken;
  MockToken internal token;
  AvUSDMinting internal AvUSDMintingContract;
  SigUtils internal sigUtils;
  SigUtils internal sigUtilsAvUSD;

  uint256 internal ownerPrivateKey;
  uint256 internal newOwnerPrivateKey;
  uint256 internal minterPrivateKey;
  uint256 internal collManagerPrivateKey;
  uint256 internal redeemerPrivateKey;
  uint256 internal maker1PrivateKey;
  uint256 internal maker2PrivateKey;
  uint256 internal benefactorPrivateKey;
  uint256 internal beneficiaryPrivateKey;
  uint256 internal trader1PrivateKey;
  uint256 internal trader2PrivateKey;
  uint256 internal gatekeeperPrivateKey;
  uint256 internal bobPrivateKey;
  uint256 internal custodian1PrivateKey;
  uint256 internal custodian2PrivateKey;
  uint256 internal randomerPrivateKey;

  address internal owner;
  address internal newOwner;
  address internal minter;
  address internal collManager;
  address internal redeemer;
  address internal benefactor;
  address internal beneficiary;
  address internal maker1;
  address internal maker2;
  address internal trader1;
  address internal trader2;
  address internal gatekeeper;
  address internal bob;
  address internal custodian1;
  address internal custodian2;
  address internal randomer;

  address[] assets;
  address[] custodians;

  address internal NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  // Roles references
  bytes32 internal minterRole = keccak256("MINTER_ROLE");
  bytes32 internal collateralManagerRole = keccak256("COLLATERAL_MANAGER_ROLE");
  bytes32 internal gatekeeperRole = keccak256("GATEKEEPER_ROLE");
  bytes32 internal adminRole = 0x00;
  bytes32 internal redeemerRole = keccak256("REDEEMER_ROLE");

  // error encodings
  // bytes internal Duplicate = abi.encodeWithSelector(IAvUSDMinting.Duplicate.selector);
  bytes internal InvalidAddress = abi.encodeWithSelector(IAvUSDMinting.InvalidAddress.selector);
  bytes internal InvalidAvUSDAddress = abi.encodeWithSelector(IAvUSDMinting.InvalidAvUSDAddress.selector);
  bytes internal InvalidAssetAddress = abi.encodeWithSelector(IAvUSDMinting.InvalidAssetAddress.selector);
  bytes internal InvalidOrder = abi.encodeWithSelector(IAvUSDMinting.InvalidOrder.selector);
  // bytes internal InvalidAffirmedAmount = abi.encodeWithSelector(IAvUSDMinting.InvalidAffirmedAmount.selector);
  bytes internal InvalidAmount = abi.encodeWithSelector(IAvUSDMinting.InvalidAmount.selector);
  bytes internal InvalidRoute = abi.encodeWithSelector(IAvUSDMinting.InvalidRoute.selector);
  bytes internal InvalidAdminChange = abi.encodeWithSelector(ISingleAdminAccessControl.InvalidAdminChange.selector);
  bytes internal UnsupportedAsset = abi.encodeWithSelector(IAvUSDMinting.UnsupportedAsset.selector);
  bytes internal NoAssetsProvided = abi.encodeWithSelector(IAvUSDMinting.NoAssetsProvided.selector);
  bytes internal InvalidSignature = abi.encodeWithSelector(IAvUSDMinting.InvalidSignature.selector);
  bytes internal InvalidNonce = abi.encodeWithSelector(IAvUSDMinting.InvalidNonce.selector);
  bytes internal SignatureExpired = abi.encodeWithSelector(IAvUSDMinting.SignatureExpired.selector);
  bytes internal MaxMintPerBlockExceeded = abi.encodeWithSelector(IAvUSDMinting.MaxMintPerBlockExceeded.selector);
  bytes internal MaxRedeemPerBlockExceeded = abi.encodeWithSelector(IAvUSDMinting.MaxRedeemPerBlockExceeded.selector);
  // AvUSD error encodings
  bytes internal OnlyMinterErr = abi.encodeWithSelector(IAvUSDDefinitions.OnlyMinter.selector);
  bytes internal ZeroAddressExceptionErr = abi.encodeWithSelector(IAvUSDDefinitions.ZeroAddressException.selector);
  bytes internal CantRenounceOwnershipErr = abi.encodeWithSelector(IAvUSDDefinitions.CantRenounceOwnership.selector);

  bytes32 internal constant ROUTE_TYPE = keccak256("Route(address[] addresses,uint256[] ratios)");
  bytes32 internal constant ORDER_TYPE = keccak256(
    "Order(uint256 expiry,uint256 nonce,address benefactor,address beneficiary,address asset,uint256 base_amount,uint256 quote_amount)"
  );

  uint256 internal _slippageRange = 50000000000000000;
  uint256 internal _stETHToDeposit = 50 * 10 ** 18;
  uint256 internal _stETHToWithdraw = 30 * 10 ** 18;
  uint256 internal _avusdToMint = 8.75 * 10 ** 23;
  uint256 internal _maxMintPerBlock = 10e23;
  uint256 internal _maxRedeemPerBlock = _maxMintPerBlock;

  // Declared at contract level to avoid stack too deep
  SigUtils.Permit public permit;
  IAvUSDMinting.Order public mint;

  /// @notice packs r, s, v into signature bytes
  function _packRsv(bytes32 r, bytes32 s, uint8 v) internal pure returns (bytes memory) {
    bytes memory sig = new bytes(65);
    assembly {
      mstore(add(sig, 32), r)
      mstore(add(sig, 64), s)
      mstore8(add(sig, 96), v)
    }
    return sig;
  }

  function setUp() public virtual {
    utils = new Utils();

    avusdToken = new AvUSD(address(this));
    token = new MockToken('Wrapped ETH', 'wETH', 18, msg.sender);
    stETHToken = new MockToken('Staked ETH', 'sETH', 18, msg.sender);
    cbETHToken = new MockToken('Coinbase ETH', 'cbETH', 18, msg.sender);
    rETHToken = new MockToken('Rocket Pool ETH', 'rETH', 18, msg.sender);
    USDCToken = new MockToken('United States Dollar Coin', 'USDC', 6, msg.sender);
    USDTToken = new MockToken('United States Dollar Token', 'USDT', 18, msg.sender);

    sigUtils = new SigUtils(stETHToken.DOMAIN_SEPARATOR());
    sigUtilsAvUSD = new SigUtils(avusdToken.DOMAIN_SEPARATOR());

    assets = new address[](6);
    assets[0] = address(stETHToken);
    assets[1] = address(cbETHToken);
    assets[2] = address(rETHToken);
    assets[3] = address(USDCToken);
    assets[4] = address(USDTToken);
    assets[5] = NATIVE_TOKEN;

    ownerPrivateKey = 0xA11CE;
    newOwnerPrivateKey = 0xA14CE;
    minterPrivateKey = 0xB44DE;
    collManagerPrivateKey = 0xB46DE;
    redeemerPrivateKey = 0xB45DE;
    maker1PrivateKey = 0xA13CE;
    maker2PrivateKey = 0xA14CE;
    benefactorPrivateKey = 0x1DC;
    beneficiaryPrivateKey = 0x1DAC;
    trader1PrivateKey = 0x1DE;
    trader2PrivateKey = 0x1DEA;
    gatekeeperPrivateKey = 0x1DEA1;
    bobPrivateKey = 0x1DEA2;
    custodian1PrivateKey = 0x1DCDE;
    custodian2PrivateKey = 0x1DCCE;
    randomerPrivateKey = 0x1DECC;

    owner = vm.addr(ownerPrivateKey);
    newOwner = vm.addr(newOwnerPrivateKey);
    minter = vm.addr(minterPrivateKey);
    collManager = vm.addr(collManagerPrivateKey);
    redeemer = vm.addr(redeemerPrivateKey);
    maker1 = vm.addr(maker1PrivateKey);
    maker2 = vm.addr(maker2PrivateKey);
    benefactor = vm.addr(benefactorPrivateKey);
    beneficiary = vm.addr(beneficiaryPrivateKey);
    trader1 = vm.addr(trader1PrivateKey);
    trader2 = vm.addr(trader2PrivateKey);
    gatekeeper = vm.addr(gatekeeperPrivateKey);
    bob = vm.addr(bobPrivateKey);
    custodian1 = vm.addr(custodian1PrivateKey);
    custodian2 = vm.addr(custodian2PrivateKey);
    randomer = vm.addr(randomerPrivateKey);

    custodians = new address[](1);
    custodians[0] = custodian1;

    vm.label(minter, "minter");
    vm.label(collManager, "collateral manager");
    vm.label(redeemer, "redeemer");
    vm.label(owner, "owner");
    vm.label(maker1, "maker1");
    vm.label(maker2, "maker2");
    vm.label(benefactor, "benefactor");
    vm.label(beneficiary, "beneficiary");
    vm.label(trader1, "trader1");
    vm.label(trader2, "trader2");
    vm.label(gatekeeper, "gatekeeper");
    vm.label(bob, "bob");
    vm.label(custodian1, "custodian1");
    vm.label(custodian2, "custodian2");
    vm.label(randomer, "randomer");

    // Set the roles
    vm.startPrank(owner);
    AvUSDMintingContract = new AvUSDMinting(
      IAvUSD(address(avusdToken)),
      IWAVAX(address(token)),
      assets,
      custodians,
      owner,
      _maxMintPerBlock,
      _maxRedeemPerBlock
    );

    AvUSDMintingContract.grantRole(gatekeeperRole, gatekeeper);
    AvUSDMintingContract.grantRole(minterRole, minter);
    AvUSDMintingContract.grantRole(collateralManagerRole, collManager);
    AvUSDMintingContract.grantRole(redeemerRole, redeemer);

    // Set the max mint per block
    AvUSDMintingContract.setMaxMintPerBlock(_maxMintPerBlock);
    // Set the max redeem per block
    AvUSDMintingContract.setMaxRedeemPerBlock(_maxRedeemPerBlock);

    // Add self as approved custodian
    AvUSDMintingContract.addCustodianAddress(address(AvUSDMintingContract));

    // Mint stEth to the benefactor in order to test
    stETHToken.mint(_stETHToDeposit, benefactor);
    vm.stopPrank();

    avusdToken.setMinter(address(AvUSDMintingContract));
  }

  function _generateRouteTypeHash(IAvUSDMinting.Route memory route) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(ROUTE_TYPE, keccak256(abi.encodePacked(route.addresses)), keccak256(abi.encodePacked(route.ratios)))
    );
  }

  function signOrder(uint256 key, bytes32 digest, IAvUSDMinting.SignatureType sigType)
    public
    pure
    returns (IAvUSDMinting.Signature memory)
  {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
    bytes memory sigBytes = _packRsv(r, s, v);

    IAvUSDMinting.Signature memory signature =
      IAvUSDMinting.Signature({signature_type: sigType, signature_bytes: sigBytes});

    return signature;
  }

  // Generic mint setup reused in the tests to reduce lines of code
  function mint_setup(uint256 avusdAmount, uint256 collateralAmount, uint256 nonce, bool multipleMints)
    public
    returns (
      IAvUSDMinting.Order memory order,
      IAvUSDMinting.Signature memory takerSignature,
      IAvUSDMinting.Route memory route
    )
  {
    order = IAvUSDMinting.Order({
      order_type: IAvUSDMinting.OrderType.MINT,
      expiry: block.timestamp + 10 minutes,
      nonce: nonce,
      benefactor: benefactor,
      beneficiary: beneficiary,
      collateral_asset: address(stETHToken),
      avusd_amount: avusdAmount,
      collateral_amount: collateralAmount
    });

    address[] memory targets = new address[](1);
    targets[0] = address(AvUSDMintingContract);

    uint256[] memory ratios = new uint256[](1);
    ratios[0] = 10_000;

    route = IAvUSDMinting.Route({addresses: targets, ratios: ratios});

    vm.startPrank(benefactor);
    bytes32 digest1 = AvUSDMintingContract.hashOrder(order);
    takerSignature = signOrder(benefactorPrivateKey, digest1, IAvUSDMinting.SignatureType.EIP712);
    stETHToken.approve(address(AvUSDMintingContract), collateralAmount);
    vm.stopPrank();

    if (!multipleMints) {
      assertEq(avusdToken.balanceOf(beneficiary), 0, "Mismatch in AvUSD balance");
      assertEq(stETHToken.balanceOf(address(AvUSDMintingContract)), 0, "Mismatch in stETH balance");
      assertEq(stETHToken.balanceOf(benefactor), collateralAmount, "Mismatch in stETH balance");
    }
  }

  // Generic redeem setup reused in the tests to reduce lines of code
  function redeem_setup(uint256 avusdAmount, uint256 collateralAmount, uint256 nonce, bool multipleRedeem)
    public
    returns (IAvUSDMinting.Order memory redeemOrder, IAvUSDMinting.Signature memory takerSignature2)
  {
    (
      IAvUSDMinting.Order memory mintOrder,
      IAvUSDMinting.Signature memory takerSignature,
      IAvUSDMinting.Route memory route
    ) = mint_setup(avusdAmount, collateralAmount, nonce, false);

    vm.prank(minter);
    AvUSDMintingContract.mint(mintOrder, route, takerSignature);

    //redeem
    redeemOrder = IAvUSDMinting.Order({
      order_type: IAvUSDMinting.OrderType.REDEEM,
      expiry: block.timestamp + 10 minutes,
      nonce: nonce + 1,
      benefactor: beneficiary,
      beneficiary: beneficiary,
      collateral_asset: address(stETHToken),
      avusd_amount: avusdAmount,
      collateral_amount: collateralAmount
    });

    // taker
    vm.startPrank(beneficiary);
    avusdToken.approve(address(AvUSDMintingContract), avusdAmount);

    bytes32 digest3 = AvUSDMintingContract.hashOrder(redeemOrder);
    takerSignature2 = signOrder(beneficiaryPrivateKey, digest3, IAvUSDMinting.SignatureType.EIP712);
    vm.stopPrank();

    vm.startPrank(owner);
    AvUSDMintingContract.grantRole(redeemerRole, redeemer);
    vm.stopPrank();

    if (!multipleRedeem) {
      assertEq(stETHToken.balanceOf(address(AvUSDMintingContract)), collateralAmount, "Mismatch in stETH balance");
      assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in stETH balance");
      assertEq(avusdToken.balanceOf(beneficiary), avusdAmount, "Mismatch in AvUSD balance");
    }
  }
}

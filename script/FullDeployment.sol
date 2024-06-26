// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import "./DeploymentUtils.sol";
import "../contracts/AvUSD.sol";
import "../contracts/AvUSDMinting.sol";
import "../contracts/StakedAvUSD.sol";
import "../contracts/interfaces/IAvUSD.sol";
import "../contracts/interfaces/IAvUSDMinting.sol";
import "../contracts/mock/MockToken.sol";

// This deployment uses CREATE2 to ensure that only the modified contracts are deployed
contract FullDeployment is Script, DeploymentUtils {
  struct Contracts {
    // Mock tokens
    MockToken mockTokenA;
    // MockToken rETH;
    // MockToken cbETH;
    // MockToken usdc;
    // MockToken usdt;
    // MockToken wbETH;
    IWAVAX wavax;
    // tokens
    AvUSD AvUSDToken;
    StakedAvUSD stakedAvUSD;
    // contracts
    AvUSDMinting avUSDMintingContract;
  }

  struct Configuration {
    // Roles
    bytes32 avusdMinterRole;
  }
  // bytes32 stakedAvUSDTokenMinterRole;
  // bytes32 stakingRewarderRole;

  address public constant ZERO_ADDRESS = address(0);
  // versioning to enable forced redeploys
  bytes32 public constant SALT = bytes32("AvUSD0.0.1");
  uint256 public constant MAX_AVUSD_MINT_PER_BLOCK = 100_000e18;
  uint256 public constant MAX_AVUSD_REDEEM_PER_BLOCK = 100_000e18;

  function run() public virtual {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    deployment(deployerPrivateKey);
  }

  function deployment(uint256 deployerPrivateKey) public returns (Contracts memory) {
    address deployerAddress = vm.addr(deployerPrivateKey);
    uint256 deployerBalance = deployerAddress.balance;
    console.log("Deployer -> %s", deployerAddress);
    console.log("Balance -> %s", deployerBalance);

    Contracts memory contracts;

    // contracts.wavax = _create2Deploy(SALT, type(ETH9).creationCode, bytes(""));
    contracts.wavax = IWAVAX(address(0xd00ae08403B9bbb9124bB305C09058E32C39A48c)); // WAVAX on Fuji Testnet

    vm.startBroadcast(deployerPrivateKey);

    console.log("Deploying AvUSD...");
    //contracts.AvUSDToken = AvUSD(_create2Deploy(SALT, type(AvUSD).creationCode, abi.encode(deployerAddress)));
    contracts.AvUSDToken = new AvUSD(deployerAddress);
    console.log("Deployed AvUSD to %s", address(contracts.AvUSDToken));

    // Checks the AvUSD owner
    _utilsIsOwner(deployerAddress, address(contracts.AvUSDToken));

    console.log("Deploying StakedAvUSD...");
    // contracts.stakedAvUSD = StakedAvUSD(
    //   _create2Deploy(
    //     SALT, type(StakedAvUSD).creationCode, abi.encode(address(contracts.AvUSDToken), deployerAddress, deployerAddress)
    //   )
    // );
    contracts.stakedAvUSD = new StakedAvUSD(contracts.AvUSDToken, deployerAddress, deployerAddress);
    console.log("Deployed StakedAvUSD to %s", address(contracts.stakedAvUSD));

    // Checks the staking owner and admin
    _utilsIsOwner(deployerAddress, address(contracts.stakedAvUSD));
    _utilsHasRole(contracts.stakedAvUSD.DEFAULT_ADMIN_ROLE(), deployerAddress, address(contracts.stakedAvUSD));

    IAvUSD iAvUSD = IAvUSD(address(contracts.AvUSDToken));

    // mock token //
    console.log("Deploying MockToken...");
    // contracts.mockTokenA = MockToken(
    //   _create2Deploy(
    //     SALT, type(MockToken).creationCode, abi.encode("Mock Token A", "mockTokenA", uint256(18), deployerAddress)
    //   )
    // );
    contracts.mockTokenA = new MockToken("Mock Token A", "mockTokenA", 18, deployerAddress);
    console.log("Deployed MockToken to %s", address(contracts.mockTokenA));

    // rETH //
    // contracts.rETH = MockToken(
    //   _create2Deploy(
    //     SALT,
    //     type(MockToken).creationCode,
    //     abi.encode('Mocked rETH', 'rETH', uint256(18), deployerAddress)
    //   )
    // );
    // // cbETH //
    // contracts.cbETH = MockToken(
    //   _create2Deploy(
    //     SALT,
    //     type(MockToken).creationCode,
    //     abi.encode('Mocked cbETH', 'cbETH', uint256(18), deployerAddress)
    //   )
    // );
    // // USDC //
    // contracts.usdc = MockToken(
    //   _create2Deploy(SALT, type(MockToken).creationCode, abi.encode('Mocked USDC', 'USDC', uint256(6), deployerAddress))
    // );
    // // USDT //
    // contracts.usdt = MockToken(
    //   _create2Deploy(SALT, type(MockToken).creationCode, abi.encode('Mocked USDT', 'USDT', uint256(6), deployerAddress))
    // );
    // // WBETH //
    // contracts.wbETH = MockToken(
    //   _create2Deploy(
    //     SALT,
    //     type(MockToken).creationCode,
    //     abi.encode('Mocked WBETH', 'WBETH', uint256(6), deployerAddress)
    //   )
    // );

    // AvUSD Minting
    address[] memory assets = new address[](1);
    assets[0] = address(contracts.mockTokenA);

    // assets[1] = address(contracts.cbETH);
    // assets[2] = address(contracts.rETH);
    // assets[3] = address(contracts.usdc);
    // assets[4] = address(contracts.usdt);
    // assets[5] = address(contracts.wbETH);
    
    // ETH
    // assets[1] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address[] memory custodians = new address[](1);
    // copper address
    // custodians[0] = address(0x6b95F243959329bb88F5D3Df9A7127Efba703fDA);
    custodians[0] = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);

    console.log("Deploying AvUSDMinting...");
    // contracts.avUSDMintingContract = AvUSDMinting(
    //   payable(
    //     _create2Deploy(
    //       SALT,
    //       type(AvUSDMinting).creationCode,
    //       abi.encode(iAvUSD, contracts.wavax, assets, custodians, deployerAddress, MAX_AVUSD_MINT_PER_BLOCK, MAX_AVUSD_REDEEM_PER_BLOCK)
    //     )
    //   )
    // );
    contracts.avUSDMintingContract = new AvUSDMinting(iAvUSD, contracts.wavax, assets, custodians, deployerAddress, MAX_AVUSD_MINT_PER_BLOCK, MAX_AVUSD_REDEEM_PER_BLOCK);
    console.log("Deployed AvUSDMinting to %s", address(contracts.avUSDMintingContract));

    // give minting contract AvUSD minter role
    contracts.AvUSDToken.setMinter(address(contracts.avUSDMintingContract));

    // Checks the minting owner and admin
    _utilsIsOwner(deployerAddress, address(contracts.avUSDMintingContract));

    _utilsHasRole(
      contracts.avUSDMintingContract.DEFAULT_ADMIN_ROLE(), deployerAddress, address(contracts.avUSDMintingContract)
    );

    uint256 finalDeployerBalance = deployerAddress.balance;
    console.log("Cost -> %s", deployerBalance - finalDeployerBalance);
    console.log("Balance -> %s", finalDeployerBalance);

    vm.stopBroadcast();

    uint256 chainId;
    assembly {
      chainId := chainid()
    }

    string memory blockExplorerUrl = "";
    if (chainId == 43113) {
      blockExplorerUrl = "https://subnets-test.avax.network";
    } else if (chainId == 43114) {
      blockExplorerUrl = "https://subnets.avax.network/";
    }

    // Logs
    console.log("=====> All AvUSD contracts deployed ....");
    console.log("AvUSD       : %s/address/%s", blockExplorerUrl, address(contracts.AvUSDToken));
    console.log("StakedAvUSD : %s/address/%s", blockExplorerUrl, address(contracts.stakedAvUSD));
    console.log("mockTokenA  : %s/address/%s", blockExplorerUrl, address(contracts.mockTokenA));
    // console.log('rETH                          : %s/address/%s', blockExplorerUrl, address(contracts.rETH));
    // console.log('cbETH                         : %s/address/%s', blockExplorerUrl, address(contracts.cbETH));
    // console.log("ETH9          : %s/address/%s", blockExplorerUrl, address(contracts.wavax));
    // console.log('USDC                          : %s/address/%s', blockExplorerUrl, address(contracts.usdc));
    // console.log('USDT                          : %s/address/%s', blockExplorerUrl, address(contracts.usdt));
    // console.log('WBETH                         : %s/address/%s', blockExplorerUrl, address(contracts.wbETH));
    console.log("AvUSDMinting: %s/address/%s", blockExplorerUrl, address(contracts.avUSDMintingContract));
    return contracts;
  }
}

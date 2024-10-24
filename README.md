# Table of contents


- Files within scope of audit
- Purpose of Avant Protocol
- Gitbook
- How Avant generates yield while maintaining delta neutrality
- 3 Contract architecture
- Owner of contracts


## Audit scope


`AvUSD.sol`
`AvUSDMinting.sol` and the contract it extends, `SingleAdminAccessControl.sol`
`StakedAvUSDV2.sol`, the contract it extends, `StakedAvUSD.sol` and the additional contract it creates `AvUSDSilo.sol`


## Gitbook


To get an overview of Avant, please visit our Gitbook: https://docs.avantprotocol.com/


## Purpose of Avant Protocol


The purpose of Avant is to offer a permissionless stable-value token, avUSD, to DeFi users and to offer users yield for being in our ecosystem. Avant is reshaping DeFi with its pioneering platform built and launching initially on the Avalanche network, delivering a fusion of security, stability, and profitability to a wide spectrum of users, including individual investors, DAOs, and institutional treasuries. At the core of Avant's offerings is avUSD, a unique stable value token designed to offer a high, sustainable and scalable yield by employing friendly, on-chain advanced managed strategies.


## How Avant generates yield while maintaining delta neutrality


Avant generates yield through advanced market-neutral strategies designed by selected managers or strategists. These include arbitrage and hedging techniques that capitalize on price discrepancies across different markets by buying an asset in one market at a lower price and selling it in another at a higher price, while hedging investments protect against adverse market movements. The cash and carry trade model, involving buying an asset and selling a short futures contract to lock in the funding rate and / or pricing difference, is validated by similar approaches in Ethereum-based protocols, ensuring high yield and scalability. Avant collaborates with leading liquidity manager or strategists such as 0xPartners, whose expertise in on-chain market-neutral strategies allows for optimized performance and scalability. All strategies are conducted on-chain, providing full visibility and verifiability, allowing users to track their investments in real-time.


## Our 3 Smart contracts


### AvUSD.sol


`AvUSD.sol` is the contract of our stablecoin. It extends `ERC20Burnable`, `ERC20Permit` and `Ownable2Step` from OpenZeppelin. There's a single variable, the `minter` address that can be modified by the `OWNER`. Outside of `Ownable2Step` contract owner only has one custom function, the ability to set the `minter` variable to any address.


The `minter` address is the only address that has the ability to mint avUSD. This minter address has one of the most powerful non-owner permissions, the ability to create an unlimited amount of avUSD. It will always be pointed to the `AvUSDMinting.sol` contract.


### AvUSDMinting.sol


`AvUSDMinting.sol` is the contract and address that the `minter` variable in `AvUSD.sol` points to. When users mint avUSD with supported collateral or redeem collateral for avUSD, this contract is invoked.


The primary functions used in this contract are `mint()` and `redeem()`. Only addresses granted permission by Avant can call these two functions. When outside users wish to mint or redeem, they perform an EIP712 signature based on an offchain price we provide. They sign the order and send it back to Avant's backend, where we run a series of checks. We are the ones who take their signed order and put it on-chain.


#### Minting


In the `mint()` function, the `order` and `signature` parameters come from users who wish to mint and have performed the EIP 712 signature. The `route` is generated by Avant and defines where the incoming collateral from users should go. The address specified in `route` must be included in `_custodianAddresses` as a safety check to ensure that funds from users end up with our custodians within a single transaction. Only those with the `DEFAULT_ADMIN_ROLE` can add custodian addresses.


#### Redeeming


Similar to minting, users perform an EIP712 signature with prices defined for avUSD. We then submit their signature and order to the `redeem()` function. The funds for redemption come directly from the minting contract. Avant aims to hold between $100k and $200k worth of collateral at all times for hot redemptions. This means that users intending to redeem a large amount will need to do so over several blocks. Alternatively, they can sell avUSD on the open market.


#### Setting delegated signer


Some users trade through smart contracts. The AvUSD minting process has the ability to delegate signers to sign for an address using `setDelegatedSigner`. The smart contract should call this function with the desired EOA (Externally Owned Account) address to delegate signing to. To remove delegation, use `removeDelegatedSigner`. Multiple signers can be delegated at once, and this feature can also be used by EOA addresses.


By setting a delegated signer, the smart contract allows both the `order.benefactor` and the delegated signer to be the address that's recovered from the order and signature, rather than just the `order.benefactor`.


### StakedAvUSDV2.sol


`StakedAvUSDV2.sol` is where holders of avUSD can stake, get savUSD in return and earn yield. Our protocol's yield is paid out by having a `REWARDER` role of the staking contract send yield in avUSD, increasing the savUSD value with respect to avUSD.


This contract is a modification of the ERC4626 standard, with a change to vest in rewards linearly over 8 hours to prevent users frontrunning the payment of yield, then unwinding their position right after (or even in the same block). This is also the reason for `REWARDER` role. Otherwise users can be denied rewards if random addresses send in 1 wei and modifies the rate of reward vesting.


There's also an optional additional change to add a 14 day cooldown period on unstaking savUSD. When the unstake process is initiated, from the user's perspective, savUSD is burnt immediately, and they will be able to invoke the withdraw function after cooldown is up to get their avUSD in return. Behind the scenes, on burning of savUSD, avUSD is sent to a seperate silo contract to hold the funds for the cooldown period. And on withdrawal, the staking contract moves user funds from silo contract out to the user's address. The cooldown is configurable up to 90 days.


Due to legal requirements, there's a `SOFT_RESTRICTED_STAKER_ROLE` and `FULL_RESTRICTED_STAKER_ROLE`. The former is for addresses based in countries we are not allowed to provide yield to, for example USA. Addresses under this category will be soft restricted. They cannot deposit avUSD to get savUSD or withdraw savUSD for avUSD. However they can participate in earning yield by buying and selling savUSD on the open market.


`FULL_RESTRICTED_STAKER_ROLE` is for sanction/stolen funds, or if we get a request from law enforcement to freeze funds. Addresses fully restricted cannot move their funds, and only Avant can unfreeze the address. Avant also has the ability to repossess funds of an address fully restricted. We understand having the ability to freeze and repossess funds of any address Avant chooses could be a cause of concern for defi users' decisions to stake avUSD. While we aim to make our operations as secure as possible, interacting with Avant still requires a certain amount of trust in our organisation outside of code on the smart contract, given the tie into cefi to earn yield.


Note that this restriction only applies to the staking contract, there are no restrictions or ability to freeze funds of avUSD.


## Owner of Avant's smart contracts


Avant utilises a gnosis safe multisig to hold ownership of its smart contracts. All multisig keys are cold wallets. This multisig is purely for the purpose of owning the smart contracts, and will not hold funds or do other on chain actions.


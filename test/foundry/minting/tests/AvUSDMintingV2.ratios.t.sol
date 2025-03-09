// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../AvUSDMinting.utils.sol";
import {IAvUSDMinting} from "../../../../contracts/interfaces/IAvUSDMinting.sol";

contract AvUSDMintingV2RatiosTest is AvUSDMintingUtils {
    function testRatios() public {
        // assertTrue(
        //     AvUSDMintingContract._checkCollateralToStablecoinRatio(
        //         100 * 10 ** 6, // collateralAmount
        //         100 ether, // avUsdAmount
        //         address(USDCToken),
        //         IAvUSDMinting.OrderType.MINT
        //     )
        // );
        // assertTrue(
        //     AvUSDMintingContract._checkCollateralToStablecoinRatio(
        //         100 * 10 ** 6, // collateralAmount
        //         99 ether, // avUsdAmount
        //         address(USDCToken),
        //         IAvUSDMinting.OrderType.MINT
        //     )
        // );
        // assertFalse(
        //     AvUSDMintingContract._checkCollateralToStablecoinRatio(
        //         99 * 10 ** 6, // collateralAmount
        //         100 ether, // avUsdAmount
        //         address(USDCToken),
        //         IAvUSDMinting.OrderType.MINT
        //     )
        // );
        // assertTrue(
        //     AvUSDMintingContract._checkCollateralToStablecoinRatio(
        //         100 * 10 ** 6, // collateralAmount
        //         100 ether, // avUsdAmount
        //         address(USDCToken),
        //         IAvUSDMinting.OrderType.REDEEM
        //     )
        // );
        // assertTrue(
        //     AvUSDMintingContract._checkCollateralToStablecoinRatio(
        //         99  * 10 ** 6, // collateralAmount
        //         100 ether, // avUsdAmount
        //         address(USDCToken),
        //         IAvUSDMinting.OrderType.REDEEM
        //     )
        // );
        // assertFalse(
        //     AvUSDMintingContract._checkCollateralToStablecoinRatio(
        //         100  * 10 ** 6, // collateralAmount
        //         99.99 ether, // avUsdAmount
        //         address(USDCToken),
        //         IAvUSDMinting.OrderType.REDEEM
        //     )
        // );
    }
}

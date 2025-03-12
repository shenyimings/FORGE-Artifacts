// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../contracts/mocks/MockERC20.sol";
import "../../../contracts/MarketDeployer.sol";

contract MarketDeployerUnitTest is Test {
    MarketDeployer marketDeployer;
    address quoteToken;
    address baseToken;
    address mockOrderToken = address(0x123);

    function setUp() public {
        marketDeployer = new MarketDeployer(address(this));
        quoteToken = address(new MockERC20("quote", "QUOTE", 6));
        baseToken = address(new MockERC20("base", "BASE", 18));
    }

    function testDeployByNonAdmin() public {
        address caller = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        vm.prank(caller);
        marketDeployer.deploy(mockOrderToken, quoteToken, baseToken, bytes32(uint256(1)), 1000, 0, 0, address(this));
    }

    function testDeploy() public {
        address market = marketDeployer.deploy(
            mockOrderToken,
            quoteToken,
            baseToken,
            bytes32(uint256(1)),
            1000,
            0,
            0,
            address(this)
        );
        assertEq(CloberOrderBook(market).quoteToken(), quoteToken, "MARKET_QUOTE");
        assertEq(CloberOrderBook(market).baseToken(), baseToken, "MARKET_BASE");
    }
}

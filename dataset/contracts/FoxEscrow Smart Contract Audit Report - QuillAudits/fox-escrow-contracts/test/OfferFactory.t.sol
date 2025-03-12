// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import {DSTest} from "@ds-test/test.sol";

import {OfferFactory} from "../OfferFactory.sol";
import {LockedTokenOffer} from "../LockedJewelOffer.sol";

contract OfferFactoryTest is DSTest {
    OfferFactory factory;

    address public USDC = 0x985458E523dB3d53125813eD68c274899e9DfAb4;

    function setUp() public {
        factory = new OfferFactory();
    }

    function testSetFee() public {
        assertEq(factory.fee(), 250);
        factory.setFee(350);
        assertEq(factory.fee(), 350);
    }

    function testSetFeeDoesntPropagate() public {
        LockedTokenOffer offer = factory.createOffer(USDC, 1000);

        uint256 oldFee = offer.fee();
        factory.setFee(oldFee + 100);
        assertEq(oldFee, offer.fee());
        assertTrue(oldFee != factory.fee());
    }

    function testCreateOffer() public {
        LockedTokenOffer offer = factory.createOffer(USDC, 10);

        assertEq(address(factory.offers(0)), address(offer));
        assertEq(offer.factory(), address(factory));
        assertEq(offer.seller(), address(this));
        assertEq(offer.tokenWanted(), USDC);
        assertEq(offer.amountWanted(), 10);
    }
}

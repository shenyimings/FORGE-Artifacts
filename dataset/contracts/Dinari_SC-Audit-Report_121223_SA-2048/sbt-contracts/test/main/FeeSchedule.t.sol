// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {BuyProcessor} from "../../src/orders/BuyProcessor.sol";
import {TokenLockCheck, ITokenLockCheck} from "../../src/TokenLockCheck.sol";
import {FeeSchedule, IFeeSchedule} from "../../src/orders/FeeSchedule.sol";
import {MockToken} from "../utils/mocks/MockToken.sol";
import "../utils/mocks/MockdShareFactory.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract FeeScheduleTest is Test {
    event FeesSet(address account, FeeSchedule.FeeRates feeRates);

    FeeSchedule feeSchedule;
    BuyProcessor issuer;
    TokenLockCheck tokenLockCheck;
    MockdShareFactory tokenFactory;
    dShare token;
    MockToken paymentToken;

    uint256 userPrivateKey;
    address user;
    address constant treasury = address(4);
    address constant operator = address(3);

    function setUp() public {
        userPrivateKey = 0x01;
        user = vm.addr(userPrivateKey);
        feeSchedule = new FeeSchedule();

        tokenFactory = new MockdShareFactory();
        token = tokenFactory.deploy("Dinari Token", "dTKN");
        paymentToken = new MockToken("Money", "$");

        tokenLockCheck = new TokenLockCheck(address(paymentToken), address(0));
        tokenLockCheck.setAsDShare(address(token));

        issuer = new BuyProcessor(address(this), treasury, 1 ether, 5_000, tokenLockCheck);
        issuer.grantRole(issuer.OPERATOR_ROLE(), operator);
    }

    function testSetFeeSchedule(uint64 _perOrderFee, uint24 _percentageRateFee) public {
        FeeSchedule.FeeRates memory fee = FeeSchedule.FeeRates({
            perOrderFeeBuy: _perOrderFee,
            percentageFeeRateBuy: _percentageRateFee,
            perOrderFeeSell: _perOrderFee,
            percentageFeeRateSell: _percentageRateFee
        });

        // Initially fees are zero
        FeeSchedule.FeeRates memory _fees = feeSchedule.getFees(user);
        assertEq(_fees.perOrderFeeBuy, 0);
        assertEq(_fees.percentageFeeRateBuy, 0);
        assertEq(_fees.perOrderFeeSell, 0);
        assertEq(_fees.percentageFeeRateSell, 0);

        // Only owner can set fees
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        feeSchedule.setFees(user, fee);

        vm.expectEmit(true, true, true, true);
        emit FeesSet(user, fee);
        feeSchedule.setFees(user, fee);

        _fees = feeSchedule.getFees(user);
        assertEq(_fees.perOrderFeeBuy, _perOrderFee);
        assertEq(_fees.percentageFeeRateBuy, _percentageRateFee);
        assertEq(_fees.perOrderFeeSell, _perOrderFee);
        assertEq(_fees.percentageFeeRateSell, _percentageRateFee);
    }

    function testEnableDisableFeeScheduleForAddress(uint64 _perOrderFee, uint24 _percentageRateFee) public {
        FeeSchedule.FeeRates memory fee = FeeSchedule.FeeRates({
            perOrderFeeBuy: _perOrderFee,
            percentageFeeRateBuy: _percentageRateFee,
            perOrderFeeSell: _perOrderFee,
            percentageFeeRateSell: _percentageRateFee
        });

        // Initially fees are default
        (, uint24 percentageRateFee) = issuer.getFeeRatesForOrder(user, false, address(token));
        assertEq(percentageRateFee, issuer.percentageFeeRate());

        // Set fee schedule
        issuer.setFeeScheduleForRequester(user, feeSchedule);

        // Setting fee schedule address without setting fee rates sets zero fees
        uint256 flatFee;
        (flatFee, percentageRateFee) = issuer.getFeeRatesForOrder(user, false, address(token));
        assertEq(flatFee, 0);
        assertEq(percentageRateFee, 0);

        feeSchedule.setFees(user, fee);

        (, percentageRateFee) = issuer.getFeeRatesForOrder(user, false, address(token));
        assertEq(percentageRateFee, _percentageRateFee);

        // Reset fees to default
        issuer.setFeeScheduleForRequester(user, IFeeSchedule(address(0)));

        (, percentageRateFee) = issuer.getFeeRatesForOrder(user, false, address(token));
        assertEq(percentageRateFee, issuer.percentageFeeRate());
    }
}

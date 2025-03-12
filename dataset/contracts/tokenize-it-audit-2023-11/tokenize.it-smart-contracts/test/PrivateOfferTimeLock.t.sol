// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/PrivateOffer.sol";
import "../contracts/factories/PrivateOfferFactory.sol";
import "./resources/CloneCreators.sol";
import "./resources/FakePaymentToken.sol";

contract PrivateOfferTimeLockTest is Test {
    PrivateOfferFactory privateOfferFactory;

    AllowList list;
    FeeSettings feeSettings;
    Token token;
    FakePaymentToken currency;

    uint256 MAX_INT = type(uint256).max;

    address public constant admin = 0x0109709eCFa91a80626FF3989D68f67f5b1dD120;
    address public constant tokenReceiver = 0x1109709ecFA91a80626ff3989D68f67F5B1Dd121;
    address public constant mintAllower = 0x2109709EcFa91a80626Ff3989d68F67F5B1Dd122;
    address public constant currencyPayer = 0x3109709ECfA91A80626fF3989D68f67F5B1Dd123;
    address public constant owner = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;
    address public constant currencyReceiver = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;
    address public constant paymentTokenProvider = 0x8109709ecfa91a80626fF3989d68f67F5B1dD128;
    address public constant trustedForwarder = 0x9109709EcFA91A80626FF3989D68f67F5B1dD129;

    uint256 public constant price = 10000000;

    uint256 requirements = 92785934;

    function setUp() public {
        Vesting vestingImplementation = new Vesting(trustedForwarder);
        VestingCloneFactory vestingCloneFactory = new VestingCloneFactory(address(vestingImplementation));
        privateOfferFactory = new PrivateOfferFactory(vestingCloneFactory);
        list = createAllowList(trustedForwarder, address(this));

        list.set(tokenReceiver, requirements);

        Fees memory fees = Fees(1, 100, 1, 100, 1, 100, 0);
        feeSettings = createFeeSettings(trustedForwarder, address(this), fees, admin, admin, admin);

        Token implementation = new Token(trustedForwarder);
        TokenProxyFactory tokenCloneFactory = new TokenProxyFactory(address(implementation));
        token = Token(
            tokenCloneFactory.createTokenProxy(
                0,
                trustedForwarder,
                feeSettings,
                admin,
                list,
                requirements,
                "token",
                "TOK"
            )
        );

        vm.prank(paymentTokenProvider);
        currency = new FakePaymentToken(0, 18);
    }

    /**
     *
     * @param salt can be used to generate different addresses
     * @param releaseStartTime when to start releasing tokens
     * @param attemptTime try to release tokens after this amount of time
     * @param releaseDuration how long the releasing of tokens should take
     */
    function testPrivateOfferWithTimeLock(
        bytes32 salt,
        uint64 releaseStartTime,
        uint64 releaseDuration,
        uint64 attemptTime
    ) public {
        vm.assume(releaseStartTime > attemptTime);
        vm.assume(releaseDuration < 20 * 365 * 24 * 60 * 60); // 20 years
        vm.assume(type(uint64).max - releaseDuration - 1 - block.timestamp > releaseStartTime);
        vm.assume(attemptTime < releaseStartTime + releaseDuration);
        vm.assume(attemptTime > 1);
        vm.assume(releaseStartTime > 1);

        // reference all times to current time. Important for when testing with mainnet forks.
        uint64 testStartTime = uint64(block.timestamp);
        attemptTime += testStartTime;
        releaseStartTime += testStartTime;
        assertTrue(testStartTime < releaseStartTime, "testStartTime >= releaseStartTime");

        PrivateOfferArguments memory arguments = PrivateOfferArguments(
            currencyPayer,
            tokenReceiver,
            currencyReceiver,
            20000000000000,
            price,
            block.timestamp + 1000,
            currency,
            token
        );

        uint256 currencyAmount = (arguments.tokenAmount * price) / 10 ** token.decimals();

        // predict addresses
        (address expectedInviteAddress, address expectedTimeLockAddress) = privateOfferFactory
            .predictPrivateOfferAndTimeLockAddress(
                salt,
                arguments,
                releaseStartTime,
                0,
                releaseDuration,
                admin,
                trustedForwarder
            );

        // add time lock and token receiver to the allow list
        list.set(expectedTimeLockAddress, requirements);
        list.set(tokenReceiver, requirements);

        // grant minting allowance to the invite address
        vm.prank(admin);
        token.increaseMintingAllowance(expectedInviteAddress, arguments.tokenAmount);

        // mint currency to the payer
        vm.prank(paymentTokenProvider);
        currency.mint(currencyPayer, currencyAmount);

        // approve the invite address to spend the currency
        vm.prank(currencyPayer);
        currency.approve(expectedInviteAddress, currencyAmount);

        // make sure balances are as expected before deployment

        assertEq(currency.balanceOf(currencyPayer), currencyAmount, "currencyPayer wrong balance before deployment");
        assertEq(currency.balanceOf(currencyReceiver), 0, "currencyReceiver wrong balance before deployment");
        assertEq(currency.balanceOf(expectedTimeLockAddress), 0, "timeLock wrong currency balance before deployment");
        assertEq(token.balanceOf(expectedTimeLockAddress), 0, "timeLock wrong token balance before deployment");

        console.log(
            "feeCollector currency balance before deployment: %s",
            currency.balanceOf(token.feeSettings().privateOfferFeeCollector(address(token)))
        );
        // measure and log gas
        uint256 gasBefore = gasleft();
        // deploy private offer
        Vesting timeLock = Vesting(
            privateOfferFactory.deployPrivateOfferWithTimeLock(
                salt,
                arguments,
                releaseStartTime,
                0,
                releaseDuration,
                admin,
                trustedForwarder
            )
        );
        uint256 gasAfter = gasleft();
        console.log("gas used: %s", gasBefore - gasAfter);

        //require(false);

        //assertEq(inviteAddress, expectedInviteAddress, "deployed contract address is not correct");

        console.log("payer balance: %s", currency.balanceOf(currencyPayer));
        console.log("receiver balance: %s", currency.balanceOf(currencyReceiver));
        console.log("timeLock token balance: %s", token.balanceOf(address(timeLock)));

        assertEq(currency.balanceOf(currencyPayer), 0, "currencyPayer wrong balance after deployment");

        assertEq(
            currency.balanceOf(currencyReceiver),
            currencyAmount - token.feeSettings().privateOfferFee(currencyAmount, address(token)),
            "currencyReceiver wrong balance after deployment"
        );

        assertEq(
            currency.balanceOf(token.feeSettings().privateOfferFeeCollector(address(token))),
            token.feeSettings().privateOfferFee(currencyAmount, address(token)),
            "feeCollector currency balance is not correct"
        );

        assertEq(
            token.balanceOf(address(timeLock)),
            arguments.tokenAmount,
            "timeLock wrong token balance after deployment"
        );

        assertEq(
            token.balanceOf(token.feeSettings().privateOfferFeeCollector(address(token))),
            token.feeSettings().tokenFee(arguments.tokenAmount, address(token)),
            "feeCollector token balance is not correct"
        );

        /*
         * PrivateOffer worked properly, now test the time lock
         */
        // immediate release should not work
        assertEq(token.balanceOf(tokenReceiver), 0, "investor vault should have no tokens");
        vm.prank(tokenReceiver);
        timeLock.release(uint64(1));
        assertEq(token.balanceOf(tokenReceiver), 0, "investor vault should still have no tokens");

        // too early release should not work
        vm.warp(attemptTime);
        vm.prank(tokenReceiver);
        timeLock.release(uint64(1));
        assertEq(token.balanceOf(tokenReceiver), 0, "investor vault should still be empty");

        // not testing the linear release time here because it's already tested in the vesting wallet tests

        // release all tokens after release duration has passed
        vm.warp(releaseStartTime + releaseDuration + 1);
        vm.prank(tokenReceiver);
        timeLock.release(uint64(1));
        assertEq(token.balanceOf(tokenReceiver), arguments.tokenAmount, "investor vault should have all tokens");
    }
}

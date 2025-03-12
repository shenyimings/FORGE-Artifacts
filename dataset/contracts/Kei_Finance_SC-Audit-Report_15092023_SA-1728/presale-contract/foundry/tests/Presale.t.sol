// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "forge-std/Test.sol";

import "contracts/PreSale.sol";

import "../mocks/TestERC20.sol";
import "../mocks/MockV3Aggregator.sol";

contract PresaleTest is Test {
    Presale internal presale;

    uint256 internal immutable PRECISION;
    uint256 internal immutable USD_PRECISION;
    uint256 internal immutable USDC_SCALE;

    address payable internal GLOBAL_ADMIN;

    address internal ALICE;
    address internal BOB;

    address payable internal WITHDRAW_TO;

    uint48 internal startDate;
    uint48 internal endDate;

    uint8 internal totalRounds;

    TestERC20 internal USDC;
    TestERC20 internal DAI;
    MockV3Aggregator internal ORACLE;
    IPresale.PresaleConfig internal config;
    IPresale.RoundConfig[] internal rounds;

    uint256[] internal tokenPrices;
    uint256[] internal tokensAllocated;

    uint256 internal aliceAllocationRemaining;
    uint256 internal bobAllocationRemaining;

    uint256 internal aliceEthBalance;
    uint256 internal bobEthBalance;
    uint256 internal withdrawToEthBalance;

    uint256 internal aliceUsdcBalance;
    uint256 internal bobUsdcBalance;
    uint256 internal withdrawToUsdcBalance;

    uint256 internal aliceDaiBalance;
    uint256 internal bobDaiBalance;
    uint256 internal withdrawToDaiBalance;

    constructor() {
        PRECISION = 1e8;
        USD_PRECISION = 1e18;
        USDC_SCALE = 1e12;

        GLOBAL_ADMIN = payable(makeAddr("GLOBAL_ADMIN"));
        vm.label(GLOBAL_ADMIN, "GLOBAL_ADMIN");

        ALICE = makeAddr("ALICE");
        vm.label(ALICE, "ALICE");

        BOB = makeAddr("BOB");
        vm.label(BOB, "BOB");

        WITHDRAW_TO = payable(makeAddr("WITHDRAW_TO"));
        vm.label(WITHDRAW_TO, "WITHDRAW_TO");

        startDate = 1 days;
        endDate = 10 days;

        totalRounds = 7;

        USDC = new TestERC20("USDC", "USDC");
        DAI = new TestERC20("DAI", "DAI");
        ORACLE = new MockV3Aggregator(8, int256(2000 * PRECISION));

        USDC.setDecimals(6);

        vm.deal(ALICE, 1_000 ether);
        vm.deal(BOB, 1_000 ether);
        vm.deal(GLOBAL_ADMIN, 1_000 ether);
        vm.deal(WITHDRAW_TO, 1_000 ether);
        vm.deal(address(presale), 100_000 ether);

        USDC.mint(ALICE, 100_000 * 10 ** 6);
        USDC.mint(BOB, 100_000 * 10 ** 6);

        DAI.mint(ALICE, 100_000 ether);
        DAI.mint(BOB, 100_000 ether);

        config = IPresale.PresaleConfig({
            minDepositAmount: 1 ether,
            maxUserAllocation: uint128(70_000 * PRECISION),
            startDate: startDate,
            endDate: endDate,
            withdrawTo: WITHDRAW_TO
        });

        tokenPrices = [0.07 ether, 0.07 ether, 0.08 ether, 0.08 ether, 0.09 ether, 0.09 ether, 0.1 ether];

        for (uint256 i; i < totalRounds; ++i) {
            tokensAllocated.push(10_000 * PRECISION);

            IPresale.RoundConfig memory _round = IPresale.RoundConfig({
                tokenPrice: tokenPrices[i],
                tokenAllocation: tokensAllocated[i],
                roundType: IPresale.RoundType.Tokens
            });

            rounds.push(_round);
        }

        vm.startPrank(GLOBAL_ADMIN);
        presale = new Presale(address(ORACLE), address(USDC), address(DAI), config, rounds);
        vm.stopPrank();

        vm.startPrank(ALICE);
        USDC.approve(address(presale), type(uint256).max);
        DAI.approve(address(presale), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(BOB);
        USDC.approve(address(presale), type(uint256).max);
        DAI.approve(address(presale), type(uint256).max);
        vm.stopPrank();

        aliceAllocationRemaining = config.maxUserAllocation;
        bobAllocationRemaining = config.maxUserAllocation;

        aliceEthBalance = ALICE.balance;
        bobEthBalance = BOB.balance;
        withdrawToEthBalance = address(config.withdrawTo).balance;

        aliceUsdcBalance = USDC.balanceOf(ALICE);
        bobUsdcBalance = USDC.balanceOf(BOB);
        withdrawToUsdcBalance = USDC.balanceOf(address(config.withdrawTo));

        aliceDaiBalance = DAI.balanceOf(ALICE);
        bobDaiBalance = DAI.balanceOf(BOB);
        withdrawToDaiBalance = DAI.balanceOf(address(config.withdrawTo));
    }

    function _fillRounds(address account, uint256 amountAsset, uint256 amountUSD)
        internal
        view
        returns (uint256 _totalCostAsset, uint256 _totalCostUSD, uint256 _totalAllocation, uint256 _newRoundIndex)
    {
        uint256 _remainingUSD = amountUSD;
        uint256 _userAllocationRemaining = config.maxUserAllocation - presale.userTokensAllocated(account);

        _newRoundIndex = presale.currentRoundIndex();

        while (_newRoundIndex < rounds.length && _remainingUSD > 0 && _userAllocationRemaining > 0) {
            IPresale.RoundConfig memory _round = presale.round(_newRoundIndex);
            uint256 _roundTotalAllocated = presale.roundTokensAllocated(_newRoundIndex);
            uint256 _roundAllocationRemaining =
                _roundTotalAllocated < _round.tokenAllocation ? _round.tokenAllocation - _roundTotalAllocated : 0;

            uint256 _userAllocation = presale.usdToTokens(_remainingUSD, _round.tokenPrice);

            if (_userAllocation > _roundAllocationRemaining) {
                _userAllocation = _roundAllocationRemaining;
            }
            if (_userAllocation > _userAllocationRemaining) {
                _userAllocation = _userAllocationRemaining;
            }

            if (_userAllocation > 0) {
                uint256 _tokensCostUSD = presale.tokensToUSD(_userAllocation, _round.tokenPrice);
                uint256 _roundPurchaseAmountAsset = (_tokensCostUSD * amountAsset) / amountUSD;

                _userAllocationRemaining -= _userAllocation;
                _totalAllocation += _userAllocation;
                _totalCostAsset += _roundPurchaseAmountAsset;
                _totalCostUSD += _tokensCostUSD;
                _remainingUSD -= _tokensCostUSD;
            }

            // if we have used everything then lets increment current index. and only increment if we are not on the last round.
            if (_userAllocation == _roundAllocationRemaining && _newRoundIndex < totalRounds - 1) {
                _newRoundIndex++;
            } else {
                break;
            }
        }
    }

    modifier assertEvent() {
        vm.expectEmit(true, true, true, true);
        _;
    }
}

contract PresaleTest_currentRoundIndex is PresaleTest {
    function test_success() external {
        vm.warp(startDate + 1);

        vm.prank(ALICE);
        presale.purchaseUSDC(ALICE, 701 * 1e6, "");

        assertEq(presale.currentRoundIndex(), 1);

        vm.prank(BOB);
        presale.purchaseDAI(BOB, 700 ether, "");

        assertEq(presale.currentRoundIndex(), 2);
    }
}

contract PresaleTest_config is PresaleTest {
    function test_success() external {
        IPresale.PresaleConfig memory _config = presale.config();

        assertEq(_config.minDepositAmount, config.minDepositAmount);
        assertEq(_config.maxUserAllocation, config.maxUserAllocation);
        assertEq(_config.startDate, config.startDate);
        assertEq(_config.endDate, config.endDate);
        assertEq(_config.withdrawTo, config.withdrawTo);
    }
}

contract PresaleTest_round is PresaleTest {
    function test_success() external {
        for (uint256 i; i < totalRounds; ++i) {
            IPresale.RoundConfig memory _round = presale.round(i);

            assertEq(_round.tokenPrice, tokenPrices[i]);
            assertEq(_round.tokenAllocation, tokensAllocated[i]);
        }
    }
}

contract PresaleTest_rounds is PresaleTest {
    function test_success() external {
        IPresale.RoundConfig[] memory _rounds = presale.rounds();

        for (uint256 i; i < totalRounds; ++i) {
            assertEq(_rounds[i].tokenPrice, rounds[i].tokenPrice);
            assertEq(_rounds[i].tokenAllocation, rounds[i].tokenAllocation);
        }
    }
}

contract PresaleTest_totalRounds is PresaleTest {
    function test_success() external {
        assertEq(presale.totalRounds(), totalRounds);
    }
}

contract PresaleTest_roundAllocated is PresaleTest {
    uint256 private _availableToPurchaseUSD;

    function setUp() public {
        IPresale.RoundConfig memory _round = rounds[0];

        _availableToPurchaseUSD = _round.tokenPrice * _round.tokenAllocation / (1 ether * PRECISION);

        vm.warp(startDate + 1);

        vm.prank(ALICE);
        presale.purchaseUSDC(ALICE, _availableToPurchaseUSD * 1e6, "");
    }

    function test_success() external {
        assertEq(presale.roundTokensAllocated(0), tokensAllocated[0]);
    }
}

contract PresaleTest_liquidityType is PresaleTest {
    constructor() {
        IPresale.RoundConfig[] memory _rounds = new IPresale.RoundConfig[](2);

        _rounds[0] = IPresale.RoundConfig({
            tokenPrice: 0.07 ether,
            tokenAllocation: 10_000 ether,
            roundType: IPresale.RoundType.Liquidity
        });

        _rounds[1] = IPresale.RoundConfig({
            tokenPrice: 0.09 ether,
            tokenAllocation: 10_000 ether,
            roundType: IPresale.RoundType.Liquidity
        });

        vm.prank(GLOBAL_ADMIN);
        presale.setRounds(_rounds);
    }

    function test_success() external {
        vm.warp(startDate);

        uint256 _alicePurchaseAmountAsset = 1e6;
        uint256 _alicePurchaseAmountUSD = _alicePurchaseAmountAsset * USDC_SCALE;

        vm.prank(ALICE);
        IPresale.Receipt memory _receipt = presale.purchaseUSDC(ALICE, _alicePurchaseAmountAsset, "");

        assertEq(presale.userUSDAllocated(ALICE), (_alicePurchaseAmountUSD - _receipt.remainingUSD) / 2);
        assertEq(presale.userUSDAllocated(ALICE), _receipt.usdAllocated);
        assertEq(presale.userTokensAllocated(ALICE), _receipt.tokensAllocated);
        assertEq(_receipt.costUSD, _receipt.usdAllocated * 2);
    }
}

contract PresaleTest_totalRaisedUSD is PresaleTest {
    function test_success() external {
        vm.warp(startDate);

        uint256 _purchaseAmountUSD = 1_234 ether;
        uint256 _purchaseAmountETH = _purchaseAmountUSD / (presale.ethPrice() / PRECISION);

        (, uint256 _totalCostUSD,,) = _fillRounds(ALICE, _purchaseAmountETH, _purchaseAmountUSD);

        vm.prank(ALICE);
        presale.purchase{value: _purchaseAmountETH}(ALICE, "");

        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
    }
}

contract PresaleTest_userTokensAllocated is PresaleTest {
    function test_success() external {
        vm.warp(startDate + 1);

        uint256 _purchaseAmountsUSD = 2301 ether;
        uint256 _purchaseAmountETH = _purchaseAmountsUSD / (presale.ethPrice() / PRECISION);

        (,, uint256 _totalAllocation,) = _fillRounds(ALICE, _purchaseAmountETH, _purchaseAmountsUSD);

        vm.prank(ALICE);
        presale.purchase{value: _purchaseAmountETH}(ALICE, "");

        assertEq(presale.userTokensAllocated(ALICE), _totalAllocation);
    }
}

contract PresaleTest_ethPrice is PresaleTest {
    function test_success() external {
        assertEq(presale.ethPrice(), 2_000 * PRECISION);
    }
}

contract PresaleTest_ethToUsd is PresaleTest {
    function test_success() external {
        uint256 _ethAmount = 2 * USD_PRECISION;
        uint256 _usdAmount = _ethAmount * presale.ethPrice() / PRECISION;
        assertEq(presale.ethToUsd(_ethAmount), _usdAmount);
    }
}

contract PresaleTest_ethToTokens is PresaleTest {
    function test_success() external {
        uint256 _ethAmount = 1 ether;
        uint256 _usdAmount = presale.ethToUsd(_ethAmount);
        uint256 _tokenAmount = 5 ether;

        uint256 _price = (_usdAmount * PRECISION) / _tokenAmount;

        assertEq(presale.ethToTokens(_ethAmount, _price), _tokenAmount);
    }
}

contract PresaleTest_usdToTokens is PresaleTest {
    function test_success() external {
        IPresale.RoundConfig memory _round = presale.round(0);
        uint256 _usdAmount = 100 * USD_PRECISION;
        uint256 _tokenAmount = _usdAmount * PRECISION / _round.tokenPrice;
        assertEq(presale.usdToTokens(_usdAmount, _round.tokenPrice), _tokenAmount);
    }
}

contract PresaleTest_pause is PresaleTest {
    event Paused(address account);

    function test_success() external {
        vm.prank(GLOBAL_ADMIN);
        presale.pause();

        assertTrue(presale.paused());
    }

    function test_rejects_whenPaused() external {
        vm.startPrank(GLOBAL_ADMIN);
        presale.pause();

        vm.expectRevert("Pausable: paused");
        presale.pause();

        vm.stopPrank();
    }

    function test_rejects_whenNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(ALICE);
        presale.pause();
    }

    function test_emits_Paused() external assertEvent {
        vm.prank(GLOBAL_ADMIN);
        emit Paused(GLOBAL_ADMIN);
        presale.pause();
    }
}

contract PresaleTest_unpause is PresaleTest {
    event Unpaused(address account);

    function setUp() public {
        vm.prank(GLOBAL_ADMIN);
        presale.pause();
    }

    function test_success() external {
        vm.prank(GLOBAL_ADMIN);
        presale.unpause();
        assertFalse(presale.paused());
    }

    function test_rejects_whenNotPaused() external {
        vm.startPrank(GLOBAL_ADMIN);
        presale.unpause();

        vm.expectRevert("Pausable: not paused");
        presale.unpause();

        vm.stopPrank();
    }

    function test_rejects_whenNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(ALICE);
        presale.unpause();
    }

    function test_emits_Unpaused() external assertEvent {
        vm.prank(GLOBAL_ADMIN);
        emit Unpaused(GLOBAL_ADMIN);
        presale.unpause();
    }
}

contract PresaleTest_setConfig is PresaleTest {
    event ConfigUpdated(IPresale.PresaleConfig prevConfig, IPresale.PresaleConfig newConfig, address indexed sender);

    IPresale.PresaleConfig private _newConfig;

    function setUp() public {
        _newConfig = IPresale.PresaleConfig({
            minDepositAmount: uint128(1 * USD_PRECISION),
            maxUserAllocation: uint128(10_000 * PRECISION),
            startDate: 1 days,
            endDate: 10 days,
            withdrawTo: GLOBAL_ADMIN
        });
    }

    function test_success() external {
        vm.prank(GLOBAL_ADMIN);

        presale.setConfig(_newConfig);

        IPresale.PresaleConfig memory _config = presale.config();

        assertEq(_config.minDepositAmount, uint128(1 * USD_PRECISION));
        assertEq(_config.maxUserAllocation, uint128(10_000 * PRECISION));
        assertEq(_config.startDate, 1 days);
        assertEq(_config.endDate, 10 days);
        assertEq(_config.withdrawTo, GLOBAL_ADMIN);
    }

    function test_rejects_whenNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(ALICE);
        presale.setConfig(_newConfig);
    }

    function test_rejects_whenInvalidDates() external {
        IPresale.PresaleConfig memory _invalidConfig = IPresale.PresaleConfig({
            minDepositAmount: uint128(1 * USD_PRECISION),
            maxUserAllocation: uint128(10_000 * PRECISION),
            startDate: 10 days,
            endDate: 1 days,
            withdrawTo: GLOBAL_ADMIN
        });

        vm.expectRevert("INVALID_DATES");

        vm.prank(GLOBAL_ADMIN);
        presale.setConfig(_invalidConfig);
    }

    function test_rejects_whenInvalidWithdrawTo() external {
        IPresale.PresaleConfig memory _invalidConfig = IPresale.PresaleConfig({
            minDepositAmount: uint128(1 * USD_PRECISION),
            maxUserAllocation: uint128(10_000 * PRECISION),
            startDate: 1 days,
            endDate: 10 days,
            withdrawTo: payable(address(0))
        });

        vm.expectRevert("INVALID_WITHDRAW_TO");

        vm.prank(GLOBAL_ADMIN);
        presale.setConfig(_invalidConfig);
    }

    function test_emit_ConfigUpdated() external assertEvent {
        IPresale.PresaleConfig memory _prevConfig = presale.config();
        vm.prank(GLOBAL_ADMIN);
        emit ConfigUpdated(_prevConfig, _newConfig, GLOBAL_ADMIN);
        presale.setConfig(_newConfig);
    }
}

contract PresaleTest_setRounds is PresaleTest {
    event RoundsUpdated(
        IPresale.RoundConfig[] prevRounds,
        IPresale.RoundConfig[] newRounds,
        uint256 prevCurrentRoundIndex,
        uint256 newCurrentRoundIndex,
        address indexed sender
    );

    IPresale.RoundConfig[] private _newRounds;
    uint256 private _totalRounds;

    function setUp() public {
        _totalRounds = 10;
        for (uint256 i; i < 10; ++i) {
            IPresale.RoundConfig memory _round = IPresale.RoundConfig({
                tokenPrice: i * 10,
                tokenAllocation: i * 100,
                roundType: IPresale.RoundType.Tokens
            });
            _newRounds.push(_round);
        }
    }

    function test_success() external {
        vm.prank(GLOBAL_ADMIN);
        presale.setRounds(_newRounds);

        IPresale.RoundConfig[] memory _rounds = presale.rounds();

        for (uint256 i; i < _totalRounds; ++i) {
            assertEq(_rounds[i].tokenPrice, i * 10);
            assertEq(_rounds[i].tokenAllocation, i * 100);
        }

        assertEq(_rounds.length, _totalRounds);
    }

    function test_should_setCurrentRoundIndex() external {
        vm.warp(startDate + 1);

        vm.prank(ALICE);
        presale.purchaseDAI(ALICE, 2100 * USD_PRECISION, "");

        while (_newRounds.length != 0) {
            _newRounds.pop();
        }

        uint256[] memory _tokenPrices = new uint256[](3);
        _tokenPrices[0] = 0.07 ether;
        _tokenPrices[1] = 0.07 ether;
        _tokenPrices[2] = 0.08 ether;

        for (uint256 i; i < 3; ++i) {
            IPresale.RoundConfig memory _round = IPresale.RoundConfig({
                tokenPrice: _tokenPrices[i],
                tokenAllocation: 10_000 * PRECISION,
                roundType: IPresale.RoundType.Tokens
            });
            _newRounds.push(_round);
        }

        vm.prank(GLOBAL_ADMIN);
        presale.setRounds(_newRounds);

        assertEq(presale.currentRoundIndex(), 2);
    }

    function test_rejects_whenNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(ALICE);
        presale.setRounds(_newRounds);
    }

    function test_emits_RoundsUpdated() external assertEvent {
        emit RoundsUpdated(rounds, _newRounds, 0, 1, GLOBAL_ADMIN);
        vm.prank(GLOBAL_ADMIN);
        presale.setRounds(_newRounds);
    }
}

contract PresaleTest_purchase is PresaleTest {
    event Purchase(uint256 indexed receiptId, uint256 indexed roundIndex, uint256 amountUSD, uint256 tokensAllocated);

    uint256 private _totalCostUSD;
    uint256 private _totalAllocation;

    function test_success(uint256 _alicePurchaseAmountETH, uint256 _bobPurchaseAmountETH) external {
        vm.assume(_alicePurchaseAmountETH != 0);
        vm.assume(_bobPurchaseAmountETH != 0);

        _alicePurchaseAmountETH = bound(_alicePurchaseAmountETH, 1 ether, aliceEthBalance);
        _bobPurchaseAmountETH = bound(_bobPurchaseAmountETH, 1 ether, bobEthBalance);

        uint256 _alicePurchaseAmountUSD = _alicePurchaseAmountETH * (presale.ethPrice() / PRECISION);
        uint256 _bobPurchaseAmountUSD = _bobPurchaseAmountETH * (presale.ethPrice() / PRECISION);

        vm.warp(startDate);

        (, uint256 _aliceCostUSD, uint256 _aliceAllocation, uint256 _aliceNewRoundIndex) =
            _fillRounds(ALICE, _alicePurchaseAmountETH, _alicePurchaseAmountUSD);

        _totalCostUSD += _aliceCostUSD;
        _totalAllocation += _aliceAllocation;

        vm.prank(ALICE);
        presale.purchase{value: _alicePurchaseAmountETH}(ALICE, "");

        // ensure bob has something to purchase
        uint256 currentIndex = presale.currentRoundIndex();
        vm.assume(presale.round(currentIndex).tokenAllocation > presale.roundTokensAllocated(currentIndex));

        assertEq(presale.currentRoundIndex(), _aliceNewRoundIndex);
        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
        assertEq(presale.userTokensAllocated(ALICE), _aliceAllocation);

        assertEq(ALICE.balance, aliceEthBalance - (_aliceCostUSD / (presale.ethPrice() / PRECISION)));
        assertEq(
            address(config.withdrawTo).balance,
            withdrawToEthBalance + (_totalCostUSD / (presale.ethPrice() / PRECISION))
        );

        (, uint256 _bobCostUSD, uint256 _bobAllocation, uint256 _bobNewRoundIndex) =
            _fillRounds(BOB, _bobPurchaseAmountETH, _bobPurchaseAmountUSD);

        _totalCostUSD += _bobCostUSD;
        _totalAllocation += _bobAllocation;

        vm.prank(BOB);
        presale.purchase{value: _bobPurchaseAmountETH}(BOB, "");

        assertEq(presale.currentRoundIndex(), _bobNewRoundIndex);
        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
        assertEq(presale.userTokensAllocated(BOB), _bobAllocation);

        assertEq(BOB.balance, bobEthBalance - (_bobCostUSD / (presale.ethPrice() / PRECISION)));
        assertEq(
            address(config.withdrawTo).balance,
            withdrawToEthBalance + (_totalCostUSD / (presale.ethPrice() / PRECISION))
        );
    }

    function test_rejects_whenPaused() external {
        vm.prank(GLOBAL_ADMIN);
        presale.pause();

        vm.expectRevert("Pausable: paused");

        vm.prank(ALICE);
        presale.purchase{value: 1 ether}(ALICE, "");
    }

    function test_rejects_whenRaiseNotStarted() external {
        vm.warp(startDate - 1);

        vm.expectRevert("RAISE_NOT_STARTED");

        vm.prank(ALICE);
        presale.purchase{value: 1 ether}(ALICE, "");
    }

    function test_rejects_whenRaiseEnded() external {
        vm.warp(endDate + 1);

        vm.expectRevert("RAISE_ENDED");

        vm.prank(ALICE);
        presale.purchase{value: 1 ether}(ALICE, "");
    }

    function test_rejects_whenMinDepositAmount() external {
        vm.warp(startDate + 1);

        vm.expectRevert("MIN_DEPOSIT_AMOUNT");

        vm.prank(GLOBAL_ADMIN);
        presale.purchase{value: 0.0004 ether}(GLOBAL_ADMIN, "");
    }

    function test_emits_Purchase() external {
        uint256 _alicePurchaseAmountUSD = 1_234 ether;
        uint256 _alicePurchaseAmountETH = _alicePurchaseAmountUSD / (presale.ethPrice() / PRECISION);

        uint256 _receiptId = presale.totalPurchases() + 1;

        vm.warp(startDate);

        vm.expectEmit(true, true, true, true);

        uint256 _remainingUSD = _alicePurchaseAmountUSD;
        for (uint256 i = presale.currentRoundIndex(); i < totalRounds; ++i) {
            IPresale.RoundConfig memory _round = presale.round(i);
            uint256 _roundAllocated = presale.roundTokensAllocated(i);
            uint256 _roundAllocationRemaining =
                _roundAllocated < _round.tokenAllocation ? _round.tokenAllocation - _roundAllocated : 0;

            uint256 _roundAllocation = _remainingUSD * PRECISION / _round.tokenPrice;

            if (_roundAllocation > _roundAllocationRemaining) {
                _roundAllocation = _roundAllocationRemaining;
            }

            _totalAllocation += _roundAllocation;

            uint256 _tokenCostUSD = _roundAllocation * _round.tokenPrice / PRECISION;
            _totalCostUSD += _tokenCostUSD;

            emit Purchase(_receiptId, i, _tokenCostUSD, _roundAllocation);

            _remainingUSD -= _tokenCostUSD;

            if (_remainingUSD == 0) {
                break;
            }
        }

        vm.prank(ALICE);
        presale.purchase{value: _alicePurchaseAmountETH}(ALICE, "");
    }
}

contract PresaleTest_purchaseForAccount is PresaleTest {
    event Purchase(uint256 indexed receiptId, uint256 indexed roundIndex, uint256 amountUSD, uint256 tokensAllocated);

    uint256 private _totalCostUSD;
    uint256 private _totalAllocation;

    function test_success(uint256 _alicePurchaseAmountETH, uint256 _bobPurchaseAmountETH) external {
        vm.assume(_alicePurchaseAmountETH != 0);
        vm.assume(_bobPurchaseAmountETH != 0);

        _alicePurchaseAmountETH = bound(_alicePurchaseAmountETH, 1 ether, GLOBAL_ADMIN.balance / 2);
        _bobPurchaseAmountETH = bound(_bobPurchaseAmountETH, 1 ether, GLOBAL_ADMIN.balance / 2);

        uint256 _alicePurchaseAmountUSD = _alicePurchaseAmountETH * (presale.ethPrice() / PRECISION);
        uint256 _bobPurchaseAmountUSD = _bobPurchaseAmountETH * (presale.ethPrice() / PRECISION);

        vm.warp(startDate);

        (uint256 _aliceCostAsset, uint256 _aliceCostUSD, uint256 _aliceAllocation, uint256 _aliceNewRoundIndex) =
            _fillRounds(ALICE, _alicePurchaseAmountETH, _alicePurchaseAmountUSD);

        _totalCostUSD += _aliceCostUSD;
        _totalAllocation += _aliceAllocation;

        uint256 _globalAdminEthBalance = GLOBAL_ADMIN.balance;

        vm.prank(GLOBAL_ADMIN);
        presale.purchase{value: _alicePurchaseAmountETH}(ALICE, "");

        {
            // ensure bob has something to purchase
            uint256 currentIndex = presale.currentRoundIndex();
            vm.assume(presale.round(currentIndex).tokenAllocation > presale.roundTokensAllocated(currentIndex));
        }

        assertEq(presale.currentRoundIndex(), _aliceNewRoundIndex);
        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
        assertEq(presale.userTokensAllocated(ALICE), _aliceAllocation);

        assertEq(ALICE.balance, aliceEthBalance + (_alicePurchaseAmountETH - _aliceCostAsset));
        assertEq(address(config.withdrawTo).balance, withdrawToEthBalance + _aliceCostAsset);
        assertEq(GLOBAL_ADMIN.balance, _globalAdminEthBalance - _alicePurchaseAmountETH); // refund goes to purchaseConfig.account

        (uint256 _bobCostAsset, uint256 _bobCostUSD, uint256 _bobAllocation, uint256 _bobNewRoundIndex) =
            _fillRounds(BOB, _bobPurchaseAmountETH, _bobPurchaseAmountUSD);

        _totalCostUSD += _bobCostUSD;
        _totalAllocation += _bobAllocation;

        vm.prank(GLOBAL_ADMIN);
        presale.purchase{value: _bobPurchaseAmountETH}(BOB, "");

        assertEq(presale.currentRoundIndex(), _bobNewRoundIndex);
        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
        assertEq(presale.userTokensAllocated(BOB), _bobAllocation);

        assertEq(BOB.balance, bobEthBalance + (_bobPurchaseAmountETH - _bobCostAsset));
        assertEq(address(config.withdrawTo).balance, withdrawToEthBalance + _aliceCostAsset + _bobCostAsset);
        assertEq(GLOBAL_ADMIN.balance, _globalAdminEthBalance - _alicePurchaseAmountETH - _bobPurchaseAmountETH); // refund goes to purchaseConfig.account
    }

    function test_rejects_whenPaused() external {
        vm.prank(GLOBAL_ADMIN);
        presale.pause();

        vm.expectRevert("Pausable: paused");

        vm.prank(GLOBAL_ADMIN);
        presale.purchase{value: 1 ether}(ALICE, "");
    }

    function test_rejects_whenRaiseNotStarted() external {
        vm.warp(startDate - 1);

        vm.expectRevert("RAISE_NOT_STARTED");

        vm.prank(GLOBAL_ADMIN);
        presale.purchase{value: 1 ether}(ALICE, "");
    }

    function test_rejects_whenRaiseEnded() external {
        vm.warp(endDate + 1);

        vm.expectRevert("RAISE_ENDED");

        vm.prank(GLOBAL_ADMIN);
        presale.purchase{value: 1 ether}(ALICE, "");
    }

    function test_rejects_whenMinDepositAmount() external {
        vm.warp(startDate + 1);

        vm.expectRevert("MIN_DEPOSIT_AMOUNT");

        vm.prank(GLOBAL_ADMIN);
        presale.purchase{value: 0.0004 ether}(ALICE, "");
    }

    function test_emits_Purchase() external {
        uint256 _alicePurchaseAmountUSD = 3_333 ether;
        uint256 _alicePurchaseAmountETH = _alicePurchaseAmountUSD / (presale.ethPrice() / PRECISION);

        uint256 _receiptId = presale.totalPurchases() + 1;

        vm.warp(startDate);

        vm.expectEmit(true, true, true, true);

        uint256 _remainingUSD = _alicePurchaseAmountUSD;
        for (uint256 i = presale.currentRoundIndex(); i < totalRounds; ++i) {
            IPresale.RoundConfig memory _round = presale.round(i);
            uint256 _roundAllocated = presale.roundTokensAllocated(i);
            uint256 _roundAllocationRemaining =
                _roundAllocated < _round.tokenAllocation ? _round.tokenAllocation - _roundAllocated : 0;

            uint256 _roundAllocation = _remainingUSD * PRECISION / _round.tokenPrice;

            if (_roundAllocation > _roundAllocationRemaining) {
                _roundAllocation = _roundAllocationRemaining;
            }

            _totalAllocation += _roundAllocation;

            uint256 _tokenCostUSD = _roundAllocation * _round.tokenPrice / PRECISION;
            _totalCostUSD += _tokenCostUSD;

            emit Purchase(_receiptId, i, _tokenCostUSD, _roundAllocation);

            _remainingUSD -= _tokenCostUSD;

            if (_remainingUSD == 0) {
                break;
            }
        }

        vm.prank(GLOBAL_ADMIN);
        presale.purchase{value: _alicePurchaseAmountETH}(ALICE, "");
    }
}

contract PresaleTest_purchaseUSDC is PresaleTest {
    event Purchase(uint256 indexed receiptId, uint256 indexed roundIndex, uint256 amountUSD, uint256 tokensAllocated);

    uint256 private _totalCostUSD;
    uint256 private _totalAllocation;

    uint256 private _aliceTotalCostUSD;
    uint256 private _bobTotalCostUSD;

    function test_success(uint256 _alicePurchaseAmountAsset, uint256 _bobPurchaseAmountAsset) external {
        vm.assume(_alicePurchaseAmountAsset != 0);
        vm.assume(_bobPurchaseAmountAsset != 0);

        _alicePurchaseAmountAsset = bound(_alicePurchaseAmountAsset, 1e6, aliceUsdcBalance);
        _bobPurchaseAmountAsset = bound(_bobPurchaseAmountAsset, 1e6, bobUsdcBalance);

        uint256 _alicePurchaseAmountUSD = _alicePurchaseAmountAsset * USDC_SCALE;
        uint256 _bobPurchaseAmountUSD = _bobPurchaseAmountAsset * USDC_SCALE;

        vm.warp(startDate);

        (, uint256 _aliceCostUSD, uint256 _aliceAllocation, uint256 _aliceNewRoundIndex) =
            _fillRounds(ALICE, _alicePurchaseAmountAsset, _alicePurchaseAmountUSD);

        _totalCostUSD += _aliceCostUSD;
        _totalAllocation += _aliceAllocation;

        vm.prank(ALICE);
        presale.purchaseUSDC(ALICE, _alicePurchaseAmountAsset, "");

        // ensure bob has something to purchase
        uint256 currentIndex = presale.currentRoundIndex();
        vm.assume(presale.round(currentIndex).tokenAllocation > presale.roundTokensAllocated(currentIndex));

        assertEq(presale.currentRoundIndex(), _aliceNewRoundIndex);
        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
        assertEq(presale.userTokensAllocated(ALICE), _aliceAllocation);

        assertEq(USDC.balanceOf(ALICE), aliceUsdcBalance - _alicePurchaseAmountAsset);
        assertEq(USDC.balanceOf(config.withdrawTo), withdrawToUsdcBalance + _alicePurchaseAmountAsset);

        (, uint256 _bobCostUSD, uint256 _bobAllocation, uint256 _bobNewRoundIndex) =
            _fillRounds(BOB, _bobPurchaseAmountAsset, _bobPurchaseAmountUSD);

        _totalCostUSD += _bobCostUSD;
        _totalAllocation += _bobAllocation;

        vm.prank(BOB);
        IPresale.Receipt memory _receipt = presale.purchaseUSDC(BOB, _bobPurchaseAmountAsset, "");

        assertEq(presale.currentRoundIndex(), _bobNewRoundIndex);
        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
        assertEq(presale.userTokensAllocated(BOB), _bobAllocation);

        assertEq(USDC.balanceOf(BOB), bobUsdcBalance - _bobPurchaseAmountAsset + _receipt.refundedAssets);
        assertEq(
            USDC.balanceOf(config.withdrawTo),
            withdrawToUsdcBalance + _bobPurchaseAmountAsset + _alicePurchaseAmountAsset - _receipt.refundedAssets
        );
    }

    function test_rejects_whenPaused() external {
        vm.prank(GLOBAL_ADMIN);
        presale.pause();

        vm.expectRevert("Pausable: paused");

        vm.prank(ALICE);
        presale.purchaseUSDC(ALICE, 5_000 * 1e6, "");
    }

    function test_rejects_whenRaiseNotStarted() external {
        vm.warp(startDate - 1);

        vm.expectRevert("RAISE_NOT_STARTED");

        vm.prank(ALICE);
        presale.purchaseUSDC(ALICE, 5_000 * 1e6, "");
    }

    function test_rejects_whenRaiseEnded() external {
        vm.warp(endDate + 1);

        vm.expectRevert("RAISE_ENDED");

        vm.prank(ALICE);
        presale.purchaseUSDC(ALICE, 5_000 * 1e6, "");
    }

    function test_rejects_whenMinDepositAmount() external {
        vm.warp(startDate);

        vm.expectRevert("MIN_DEPOSIT_AMOUNT");

        vm.prank(ALICE);
        presale.purchaseUSDC(ALICE, 0.1 * 1e6, "");
    }

    function test_emits_Purchase() external {
        uint256 _alicePurchaseAmountAsset = 1_345 * 1e6;
        uint256 _alicePurchaseAmountUSD = _alicePurchaseAmountAsset * USDC_SCALE;

        uint256 _receiptId = presale.totalPurchases() + 1;

        vm.warp(startDate);

        vm.expectEmit(true, true, true, true);

        uint256 _remainingUSD = _alicePurchaseAmountUSD;
        for (uint256 i = presale.currentRoundIndex(); i < totalRounds; ++i) {
            IPresale.RoundConfig memory _round = presale.round(i);
            uint256 _roundAllocated = presale.roundTokensAllocated(i);
            uint256 _roundAllocationRemaining =
                _roundAllocated < _round.tokenAllocation ? _round.tokenAllocation - _roundAllocated : 0;

            uint256 _roundAllocation = _remainingUSD * PRECISION / _round.tokenPrice;

            if (_roundAllocation > _roundAllocationRemaining) {
                _roundAllocation = _roundAllocationRemaining;
            }

            _totalAllocation += _roundAllocation;

            uint256 _tokenCostUSD = _roundAllocation * _round.tokenPrice / PRECISION;
            _totalCostUSD += _tokenCostUSD;

            emit Purchase(_receiptId, i, _tokenCostUSD, _roundAllocation);

            _remainingUSD -= _tokenCostUSD;

            if (_remainingUSD == 0) {
                break;
            }
        }

        vm.prank(ALICE);
        presale.purchaseUSDC(ALICE, _alicePurchaseAmountAsset, "");
    }
}

contract PresaleTest_purchaseDAI is PresaleTest {
    event Purchase(uint256 indexed receiptId, uint256 indexed roundIndex, uint256 amountUSD, uint256 tokensAllocated);

    uint256 private _totalCostUSD;
    uint256 private _totalAllocation;

    function test_success(uint256 _alicePurchaseAmountAsset, uint256 _bobPurchaseAmountAsset) external {
        vm.assume(_alicePurchaseAmountAsset != 0);
        vm.assume(_bobPurchaseAmountAsset != 0);

        _alicePurchaseAmountAsset = bound(_alicePurchaseAmountAsset, 1 ether, aliceDaiBalance);
        _bobPurchaseAmountAsset = bound(_bobPurchaseAmountAsset, 1 ether, bobDaiBalance);

        uint256 _alicePurchaseAmountUSD = _alicePurchaseAmountAsset;
        uint256 _bobPurchaseAmountUSD = _bobPurchaseAmountAsset;

        vm.warp(startDate);

        (, uint256 _aliceCostUSD, uint256 _aliceAllocation, uint256 _aliceNewRoundIndex) =
            _fillRounds(ALICE, _alicePurchaseAmountAsset, _alicePurchaseAmountUSD);

        _totalCostUSD += _aliceCostUSD;
        _totalAllocation += _aliceAllocation;

        vm.prank(ALICE);
        presale.purchaseDAI(ALICE, _alicePurchaseAmountAsset, "");

        {
            // ensure bob has something to purchase
            uint256 currentIndex = presale.currentRoundIndex();
            vm.assume(presale.round(currentIndex).tokenAllocation > presale.roundTokensAllocated(currentIndex));
        }

        assertEq(presale.currentRoundIndex(), _aliceNewRoundIndex);
        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
        assertEq(presale.userTokensAllocated(ALICE), _aliceAllocation);

        assertEq(DAI.balanceOf(ALICE), aliceDaiBalance - _aliceCostUSD);
        assertEq(DAI.balanceOf(config.withdrawTo), withdrawToDaiBalance + _totalCostUSD);

        (, uint256 _bobCostUSD, uint256 _bobAllocation, uint256 _bobNewRoundIndex) =
            _fillRounds(BOB, _bobPurchaseAmountAsset, _bobPurchaseAmountUSD);

        _totalCostUSD += _bobCostUSD;
        _totalAllocation += _bobAllocation;

        vm.prank(BOB);
        presale.purchaseDAI(BOB, _bobPurchaseAmountAsset, "");

        assertEq(presale.currentRoundIndex(), _bobNewRoundIndex);
        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
        assertEq(presale.userTokensAllocated(BOB), _bobAllocation);

        assertEq(DAI.balanceOf(BOB), bobDaiBalance - _bobCostUSD);
        assertEq(DAI.balanceOf(config.withdrawTo), withdrawToDaiBalance + _totalCostUSD);
    }

    function test_rejects_whenPaused() external {
        vm.prank(GLOBAL_ADMIN);
        presale.pause();

        vm.expectRevert("Pausable: paused");

        vm.prank(ALICE);
        presale.purchaseDAI(ALICE, 1 ether, "");
    }

    function test_rejects_whenRaiseNotStarted() external {
        vm.warp(startDate - 1);

        vm.expectRevert("RAISE_NOT_STARTED");

        vm.prank(ALICE);
        presale.purchaseDAI(ALICE, 1 ether, "");
    }

    function test_rejects_whenRaiseEnded() external {
        vm.warp(endDate + 1);

        vm.expectRevert("RAISE_ENDED");

        vm.prank(ALICE);
        presale.purchaseDAI(ALICE, 1 ether, "");
    }

    function test_rejects_whenMinDepositAmount() external {
        vm.warp(startDate);

        vm.expectRevert("MIN_DEPOSIT_AMOUNT");

        vm.prank(ALICE);
        presale.purchaseDAI(ALICE, 0.1 ether, "");
    }

    function test_emits_Purchase() external {
        uint256 _alicePurchaseAmountUSD = 1_234 ether;

        uint256 _receiptId = presale.totalPurchases() + 1;

        vm.warp(startDate);

        vm.expectEmit(true, true, true, true);

        uint256 _remainingUSD = _alicePurchaseAmountUSD;
        for (uint256 i = presale.currentRoundIndex(); i < totalRounds; ++i) {
            IPresale.RoundConfig memory _round = presale.round(i);
            uint256 _roundAllocated = presale.roundTokensAllocated(i);
            uint256 _roundAllocationRemaining =
                _roundAllocated < _round.tokenAllocation ? _round.tokenAllocation - _roundAllocated : 0;

            uint256 _roundAllocation = _remainingUSD * PRECISION / _round.tokenPrice;

            if (_roundAllocation > _roundAllocationRemaining) {
                _roundAllocation = _roundAllocationRemaining;
            }

            _totalAllocation += _roundAllocation;

            uint256 _tokenCostUSD = _roundAllocation * _round.tokenPrice / PRECISION;
            _totalCostUSD += _tokenCostUSD;

            emit Purchase(_receiptId, i, _tokenCostUSD, _roundAllocation);

            _remainingUSD -= _tokenCostUSD;

            if (_remainingUSD == 0) {
                break;
            }
        }

        vm.prank(ALICE);
        presale.purchaseDAI(ALICE, _alicePurchaseAmountUSD, "");
    }
}

contract PresaleTest_allocate is PresaleTest {
    event Purchase(uint256 indexed receiptId, uint256 indexed roundIndex, uint256 amountUSD, uint256 tokensAllocated);

    uint256 private _totalCostUSD;
    uint256 private _totalAllocation;

    function test_success(uint256 _aliceAllocationAmountUSD, uint256 _bobAllocationAmountUSD) external {
        vm.assume(_aliceAllocationAmountUSD != 0);
        vm.assume(_bobAllocationAmountUSD != 0);

        _aliceAllocationAmountUSD = bound(
            _aliceAllocationAmountUSD,
            1 ether,
            config.maxUserAllocation * presale.round(rounds.length - 1).tokenPrice / PRECISION
        );
        _bobAllocationAmountUSD = bound(
            _bobAllocationAmountUSD,
            1 ether,
            config.maxUserAllocation * presale.round(rounds.length - 1).tokenPrice / PRECISION
        );

        vm.warp(startDate);

        (, uint256 _aliceCostUSD, uint256 _aliceAllocation, uint256 _aliceNewRoundIndex) =
            _fillRounds(ALICE, 0, _aliceAllocationAmountUSD);

        _totalCostUSD += _aliceCostUSD;
        _totalAllocation += _aliceAllocation;

        vm.prank(GLOBAL_ADMIN);
        presale.allocate(ALICE, _aliceAllocationAmountUSD, "");

        {
            // ensure bob has something to purchase
            uint256 currentIndex = presale.currentRoundIndex();
            vm.assume(presale.round(currentIndex).tokenAllocation > presale.roundTokensAllocated(currentIndex));
        }

        assertEq(presale.currentRoundIndex(), _aliceNewRoundIndex);
        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
        assertEq(presale.userTokensAllocated(ALICE), _aliceAllocation);

        (, uint256 _bobCostUSD, uint256 _bobAllocation, uint256 _bobNewRoundIndex) =
            _fillRounds(BOB, 0, _bobAllocationAmountUSD);

        _totalCostUSD += _bobCostUSD;
        _totalAllocation += _bobAllocation;

        vm.prank(GLOBAL_ADMIN);
        presale.allocate(BOB, _bobAllocationAmountUSD, "");

        assertEq(presale.currentRoundIndex(), _bobNewRoundIndex);
        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
        assertEq(presale.userTokensAllocated(BOB), _bobAllocation);
    }

    function test_rejects_whenNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(ALICE);
        presale.allocate(ALICE, 1 ether, "");
    }

    function test_rejects_whenRaiseNotStarted() external {
        vm.warp(startDate - 1);

        vm.expectRevert("RAISE_NOT_STARTED");

        vm.prank(GLOBAL_ADMIN);
        presale.allocate(ALICE, 1 ether, "");
    }

    function test_rejects_whenRaiseEnded() external {
        vm.warp(endDate + 1);

        vm.expectRevert("RAISE_ENDED");

        vm.prank(GLOBAL_ADMIN);
        presale.allocate(ALICE, 1 ether, "");
    }

    function test_rejects_whenMinDepositAmount() external {
        vm.warp(startDate);

        vm.expectRevert("MIN_DEPOSIT_AMOUNT");

        vm.prank(GLOBAL_ADMIN);
        presale.allocate(ALICE, 0.1 ether, "");
    }

    function test_emits_Purchase(bytes memory data) external {
        uint256 _alicePurchaseAmountUSD = 5_000 ether;
        uint256 _receiptId = presale.totalPurchases() + 1;

        vm.warp(startDate);

        vm.expectEmit(true, true, true, true);

        uint256 _remainingUSD = _alicePurchaseAmountUSD;
        for (uint256 i = presale.currentRoundIndex(); i < totalRounds; ++i) {
            IPresale.RoundConfig memory _round = presale.round(i);

            uint256 _roundAllocation;

            {
                uint256 _roundAllocated = presale.roundTokensAllocated(i);
                uint256 _roundAllocationRemaining =
                    _roundAllocated < _round.tokenAllocation ? _round.tokenAllocation - _roundAllocated : 0;
                _roundAllocation = _remainingUSD * PRECISION / _round.tokenPrice;
                if (_roundAllocation > _roundAllocationRemaining) {
                    _roundAllocation = _roundAllocationRemaining;
                }
            }

            _totalAllocation += _roundAllocation;

            uint256 _tokenCostUSD = _roundAllocation * _round.tokenPrice / PRECISION;
            _totalCostUSD += _tokenCostUSD;

            emit Purchase(_receiptId, i, _tokenCostUSD, _roundAllocation);

            _remainingUSD -= _tokenCostUSD;

            if (_remainingUSD == 0) {
                break;
            }
        }

        vm.prank(GLOBAL_ADMIN);
        presale.allocate(ALICE, _alicePurchaseAmountUSD, data);
    }
}

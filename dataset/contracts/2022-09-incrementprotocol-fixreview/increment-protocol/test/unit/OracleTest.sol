// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Test} from "../../lib/forge-std/src/Test.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// interfaces
import "../../contracts/Oracle.sol";
import "../../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../../lib/chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

// libraries
import "../../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../../contracts/lib/LibMath.sol";

contract OracleTest is Test {
    event OracleUpdated(address asset, AggregatorV3Interface aggregator, bool isVault);
    event AssetGotFixedPrice(address asset, int256 fixedPrice);
    event HeartBeatUpdated(address asset, uint24 newHeartBeat);
    event SequencerUptimeFeedUpdated(AggregatorV3Interface newSequencerUptimeFeed);
    event GracePeriodUpdated(uint256 newGracePeriod);

    using LibMath for int256;
    using LibMath for uint256;

    address user = address(123);

    uint8 constant DECIMALS = 18;
    uint256 constant GRACE_PERIOD = 1000;
    uint256 constant HEARTBEAT = 25 hours;
    int256 constant STARTING_PRICE = 100 ether;

    MockV3Aggregator aggregator;
    MockV3Aggregator sequencerUptimeFeed;
    ERC20 token;
    Oracle oracle;

    function setUp() public virtual {
        deal(user, 100 ether);

        aggregator = new MockV3Aggregator(DECIMALS, STARTING_PRICE);
        sequencerUptimeFeed = new MockV3Aggregator(DECIMALS, 0);
        oracle = new Oracle(sequencerUptimeFeed, GRACE_PERIOD);
        token = new ERC20("Test", "TEST");
        vm.warp(block.timestamp + HEARTBEAT * 3);
    }

    // TESTS

    function test_AddAggregator() public {
        (, AggregatorV3Interface currentAggregator,,) = oracle.assetToOracles(address(token));
        assertEq(address(currentAggregator), address(0));

        // expect emit OracleUpdated event
        vm.expectEmit(true, true, true, false);
        emit OracleUpdated(address(token), aggregator, false);
        oracle.setOracle(address(token), aggregator, uint24(HEARTBEAT), false);

        (, AggregatorV3Interface newAggregator,,) = oracle.assetToOracles(address(token));
        assertEq(address(newAggregator), address(aggregator));
    }

    function test_FailsToAddAggregatorZeroAddress() public {
        vm.expectRevert(IOracle.Oracle_AssetZeroAddress.selector);
        oracle.setOracle(address(0), aggregator, uint24(HEARTBEAT), false);

        vm.expectRevert(IOracle.Oracle_AggregatorZeroAddress.selector);
        oracle.setOracle(address(token), AggregatorV3Interface(address(0)), uint24(HEARTBEAT), true);
    }

    function test_FailsWhenOraclePriceValueZero() public {
        aggregator.updateAnswer(0);
        oracle.setOracle(address(token), aggregator, uint24(HEARTBEAT), false);
        aggregator.updateRoundData(0, 0, 0, 0);

        vm.expectRevert(IOracle.Oracle_InvalidRoundTimestamp.selector);
        oracle.getPrice(address(token), uint256(DECIMALS).toInt256());
    }

    function test_FailsWhenOracleRoundTimestampValueZero() public {
        aggregator.updateAnswer(0);
        oracle.setOracle(address(token), aggregator, uint24(HEARTBEAT), false);

        vm.expectRevert(IOracle.Oracle_InvalidRoundPrice.selector);
        oracle.getPrice(address(token), uint256(DECIMALS).toInt256());
    }

    function testFuzz_FailsWhenSequencerDown(int256 answer) public {
        vm.assume(answer > 0);

        aggregator.updateAnswer(answer);
        oracle.setOracle(address(token), aggregator, uint24(HEARTBEAT), false);

        sequencerUptimeFeed.updateAnswer(1);

        vm.expectRevert(IOracle.Oracle_SequencerDown.selector);
        oracle.getPrice(address(token), uint256(DECIMALS).toInt256());
    }

    function testFuzz_FailsWhenSequencerBackBeforeEndOfGracePeriod(uint256 timeAfterSequencerDown) public {
        vm.assume(timeAfterSequencerDown > 0 && timeAfterSequencerDown < GRACE_PERIOD);
        oracle.setOracle(address(token), aggregator, uint24(HEARTBEAT), false);

        sequencerUptimeFeed.updateAnswer(1);
        vm.warp(GRACE_PERIOD);

        uint256 sequencerStatusLastUpdated = block.timestamp - timeAfterSequencerDown;
        sequencerUptimeFeed.updateRoundData(0, 0, sequencerStatusLastUpdated, 0);

        vm.expectRevert(IOracle.Oracle_GracePeriodNotOver.selector);
        oracle.getPrice(address(token), uint256(DECIMALS).toInt256());
    }

    function testFuzz_FailsToReturnSpotPriceIfOldTimestamp(uint256 timeBeforeHeartBeat) public {
        vm.assume(timeBeforeHeartBeat > 0 && timeBeforeHeartBeat < block.timestamp - HEARTBEAT);
        uint256 oldTimestamp = block.timestamp - HEARTBEAT - timeBeforeHeartBeat;

        aggregator.updateRoundData(0, STARTING_PRICE, oldTimestamp, 0);
        oracle.setOracle(address(token), aggregator, uint24(HEARTBEAT), false);

        vm.expectRevert(IOracle.Oracle_DataNotFresh.selector);
        oracle.getPrice(address(token), uint256(DECIMALS).toInt256());
    }

    function test_GetsSpotPrice18Decimals(int256 answer) public {
        vm.assume(answer > 0);

        aggregator.updateAnswer(answer);
        oracle.setOracle(address(token), aggregator, uint24(HEARTBEAT), false);

        assertEq(oracle.getPrice(address(token), uint256(DECIMALS).toInt256()), answer);
    }

    function test_GetSpotPriceLT18Decimals(uint8 decimals) public {
        int256 anwser = 1 ether;
        vm.assume(decimals < DECIMALS);

        MockV3Aggregator altAggregator = new MockV3Aggregator(decimals, anwser);
        altAggregator.updateAnswer(anwser / (10 ** uint256(DECIMALS - decimals)).toInt256());

        oracle.setOracle(address(token), altAggregator, uint24(HEARTBEAT), false);

        assertEq(oracle.getPrice(address(token), uint256(DECIMALS).toInt256()), anwser);
    }

    function test_GetSpotPriceGT18Decimals(uint8 decimals) public {
        vm.assume(decimals > DECIMALS);
        vm.assume(decimals < 30);

        int256 answer = 1 ether;

        MockV3Aggregator altAggregator =
            new MockV3Aggregator(decimals, answer * (10 ** uint256(decimals - DECIMALS)).toInt256());
        altAggregator.updateAnswer(answer * (uint256(10) ** uint256(decimals - DECIMALS)).toInt256());

        oracle.setOracle(address(token), altAggregator, uint24(HEARTBEAT), false);

        assertEq(oracle.getPrice(address(token), uint256(DECIMALS).toInt256()), answer);
    }

    function testFuzz_FailsToSetFixedPriceUnsupportedAsset(int256 fixedPrice) public {
        vm.expectRevert(IOracle.Oracle_UnsupportedAsset.selector);
        oracle.setFixedPrice(address(token), fixedPrice);
    }

    function testFuzz_FailsToSetFixedPriceNonGovernanceAddress(int256 fixedPrice) public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(user),
                " is missing role ",
                Strings.toHexString(uint256(oracle.GOVERNANCE()), 32)
            )
        );
        vm.startPrank(user);
        oracle.setFixedPrice(address(token), fixedPrice);
        vm.stopPrank();
    }

    function testFuzz_FailsToSetFixedPriceZeroAddress(int256 price) public {
        vm.assume(price > 0);

        // set initial aggregator
        oracle.setOracle(address(token), aggregator, uint24(HEARTBEAT), false);

        vm.expectRevert(IOracle.Oracle_UnsupportedAsset.selector);
        oracle.setFixedPrice(address(0), price);
    }

    function testFuzz_SetValidFixedPrice(int256 price) public {
        vm.assume(price > 0);

        // set initial aggregator
        oracle.setOracle(address(token), aggregator, uint24(HEARTBEAT), false);

        // expect emit AssetGotFixedPrice event
        vm.expectEmit(true, true, true, false);
        emit AssetGotFixedPrice(address(token), price);
        oracle.setFixedPrice(address(token), price);

        (,,, int256 fixedPrice) = oracle.assetToOracles(address(token));
        assertEq(fixedPrice, price);
        assertEq(oracle.getPrice(address(token), uint256(DECIMALS).toInt256()), price);
    }

    function testFuzz_FailsToSetHeartBeatForUnsupportedAsset(address randToken, uint24 newHeartBeat) public {
        vm.expectRevert(IOracle.Oracle_UnsupportedAsset.selector);
        oracle.setHeartBeat(randToken, newHeartBeat);
    }

    function testFuzz_FailsToSetHeartBeatNonGovernanceAddress(uint24 newHeartBeat) public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(user),
                " is missing role ",
                Strings.toHexString(uint256(oracle.GOVERNANCE()), 32)
            )
        );
        vm.startPrank(user);
        oracle.setHeartBeat(address(token), newHeartBeat);
        vm.stopPrank();
    }

    function test_FailsToSetHeartBeatZero() public {
        oracle.setOracle(address(token), aggregator, uint24(HEARTBEAT), false);

        vm.expectRevert(IOracle.Oracle_IncorrectHeartBeat.selector);
        oracle.setHeartBeat(address(token), 0);
    }

    function testFuzz_SetValidHeartBeat(uint24 newHeartBeat) public {
        vm.assume(newHeartBeat > 0);
        oracle.setOracle(address(token), aggregator, uint24(HEARTBEAT), false);

        // expect emit HeartBeatUpdated event
        vm.expectEmit(true, true, true, false);
        emit HeartBeatUpdated(address(token), newHeartBeat);
        oracle.setHeartBeat(address(token), newHeartBeat);

        (uint24 heartBeat,,,) = oracle.assetToOracles(address(token));
        assertEq(heartBeat, newHeartBeat);

        aggregator.updateRoundData(0, STARTING_PRICE, block.timestamp, 0);

        // expect price to be valid before newHeartBeat
        vm.warp(block.timestamp + newHeartBeat);
        oracle.getPrice(address(token), uint256(DECIMALS).toInt256());

        // expect price to be invalid after newHeartBeat
        vm.warp(block.timestamp + 1);
        vm.expectRevert(IOracle.Oracle_DataNotFresh.selector);
        oracle.getPrice(address(token), uint256(DECIMALS).toInt256());
    }

    function test_failsToSetSequencerUptimeFeedNonGovernanceAddress() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(user),
                " is missing role ",
                Strings.toHexString(uint256(oracle.GOVERNANCE()), 32)
            )
        );
        vm.startPrank(user);
        oracle.setSequencerUptimeFeed(sequencerUptimeFeed);
        vm.stopPrank();
    }

    function test_FailsToSetSequencerUptimeFeedZeroAddress() public {
        vm.expectRevert(IOracle.Oracle_SequencerUptimeFeedZeroAddress.selector);
        oracle.setSequencerUptimeFeed(AggregatorV3Interface(address(0)));
    }

    function test_SetValidSequencerUptimeFeed() public {
        MockV3Aggregator newSequencerUptimeFeed = new MockV3Aggregator(DECIMALS, 0);

        // expect emit SequencerUptimeFeedUpdated event
        vm.expectEmit(true, true, true, false);
        emit SequencerUptimeFeedUpdated(newSequencerUptimeFeed);
        oracle.setSequencerUptimeFeed(newSequencerUptimeFeed);

        assertEq(address(oracle.sequencerUptimeFeed()), address(newSequencerUptimeFeed));
    }

    function testFuzz_FailsToSetNewGracePeriodNonGovernanceAddress(uint256 newGracePeriod) public {
        vm.assume(newGracePeriod >= 60 && newGracePeriod <= 3600);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(user),
                " is missing role ",
                Strings.toHexString(uint256(oracle.GOVERNANCE()), 32)
            )
        );
        vm.startPrank(user);
        oracle.setGracePeriod(newGracePeriod);
        vm.stopPrank();
    }

    function testFuzz_FailsToSetNewGracePeriodOutOfRange(uint256 newGracePeriod) public {
        vm.assume(newGracePeriod < 60 || newGracePeriod > 3600);
        vm.expectRevert(IOracle.Oracle_IncorrectGracePeriod.selector);
        oracle.setGracePeriod(newGracePeriod);
    }

    function testFuzz_NewGracePeriod(uint256 newGracePeriod) public {
        vm.assume(newGracePeriod >= 60 && newGracePeriod <= 3600);
        // expect emit GracePeriodUpdated event
        vm.expectEmit(true, true, true, false);
        emit GracePeriodUpdated(newGracePeriod);
        oracle.setGracePeriod(newGracePeriod);
    }
}

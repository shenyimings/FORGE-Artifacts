// SPDX-License-Identifier: GPL-3.0-only

// ┏━━━┓━━━━━┏┓━━━━━━━━━┏━━━┓━━━━━━━━━━━━━━━━━━━━━━━
// ┃┏━┓┃━━━━┏┛┗┓━━━━━━━━┃┏━━┛━━━━━━━━━━━━━━━━━━━━━━━
// ┃┗━┛┃┏━┓━┗┓┏┛┏━━┓━━━━┃┗━━┓┏┓┏━┓━┏━━┓━┏━┓━┏━━┓┏━━┓
// ┃┏━┓┃┃┏┓┓━┃┃━┃┏┓┃━━━━┃┏━━┛┣┫┃┏┓┓┗━┓┃━┃┏┓┓┃┏━┛┃┏┓┃
// ┃┃ ┃┃┃┃┃┃━┃┗┓┃┃━┫━┏┓━┃┃━━━┃┃┃┃┃┃┃┗┛┗┓┃┃┃┃┃┗━┓┃┃━┫
// ┗┛ ┗┛┗┛┗┛━┗━┛┗━━┛━┗┛━┗┛━━━┗┛┗┛┗┛┗━━━┛┗┛┗┛┗━━┛┗━━┛
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

pragma solidity ^0.7.0;

import "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";

import "../AnteTest.sol";

// checks the 12 to 24-hour TWAP price of IRON does not fall 10% below peg

// NB: It is possible to force this test to fail by calling checkpoint() then
// calling checkTestPasses() after approximately 136 years (2**32 seconds plus 12 hours)
// however, the exploit window is only 12 hours long and it is prevented if anyone
// else calls checkpoint() again within the 136 year window
contract AnteIronPegTest is AnteTest("IRON Peg Holds Test") {
    using FixedPoint for *;

    // if TWAP price of IRON/USDC is greater than 1.1 IRON per USDC over a 12-24 hour period, this test fails
    // decimals for USDC are 6 and for IRON are 18
    uint256 public constant MAX_PRICE = 11 * 10e11;
    uint32 public constant MIN_PERIOD = 12 hours;
    uint32 public constant MAX_PERIOD = 24 hours;
    uint32 public constant PROTECTED_PERIOD = 2 hours;

    uint32 public lastCheckpointTime = 0;
    uint256 public lastCumPrice;
    uint256 public lastTestedTwap;

    // address which called checkpoint() to prime test
    address public checkpointer;
    address public constant QUICKSWAP_POOL = 0x2Bbe0F728f4d5821F84eeE0432D2A4be7C0cB7Fc;

    constructor() {
        protocolName = "Iron Finance";
        testedContracts = [
            QUICKSWAP_POOL,
            0xD86b5923F3AD7b585eD81B448170ae026c65ae9a, //IRON token
            0x4a812C5EE699A40530eB49727E1818D43964324e, //treasury
            0xEc12B5d70a84895F819FE037dc4EABDbD24707f2, //Collateral Pool
            0xC7b1F244397e2157036a89CE0D58F3A467A7Ed2F, // USDC minting pool
            0xD078B62f8D9f5F69a6e6343e3e1eC9059770B830
        ]; //Zap pool
    }

    function testPrimed() external view returns (bool) {
        return (UniswapV2OracleLibrary.currentBlockTimestamp() - lastCheckpointTime < MAX_PERIOD);
    }

    function testCallable() external view returns (bool) {
        uint32 timeSinceLastCheckpoint = UniswapV2OracleLibrary.currentBlockTimestamp() - lastCheckpointTime;
        return (timeSinceLastCheckpoint < MAX_PERIOD && timeSinceLastCheckpoint > MIN_PERIOD);
    }

    function twap() public view returns (uint256) {
        // only calculate if checkpoint exists
        if (UniswapV2OracleLibrary.currentBlockTimestamp() - lastCheckpointTime > MAX_PERIOD) {
            return 0;
        }

        (uint256 currentCumPrice, , uint32 currentTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(
            QUICKSWAP_POOL
        );

        // overflow is desired
        uint32 timeElapsed = currentTimestamp - lastCheckpointTime;
        FixedPoint.uq112x112 memory _twap = FixedPoint.uq112x112(
            uint224((currentCumPrice - lastCumPrice) / timeElapsed)
        );

        //_twap is a q112.112 fixed point
        return _twap.decode();
    }

    function uncheckpoint() external {
        require(checkpointer == msg.sender, "Only checkpointer can reset checkpoint");

        lastCheckpointTime = 0;
        lastCumPrice = 0;
    }

    function checkpoint() public {
        require(
            UniswapV2OracleLibrary.currentBlockTimestamp() - lastCheckpointTime > MAX_PERIOD,
            "Cannot take a checkpoint within 24 hours of another checkpoint"
        );

        checkpointer = msg.sender;
        (lastCumPrice, , lastCheckpointTime) = UniswapV2OracleLibrary.currentCumulativePrices(QUICKSWAP_POOL);
    }

    // in order to trigger a failing test, challengers must first 'prime' by calling checkTestPasses or checkpoint once
    // then after 12-24 hours call checkTestPasses again
    // the test will then fail if the TWAP since the first checkpoint greater than MAX_PRICE

    // the challenger who primed the test will have a 2 hour protected window after 12 hours pass to
    // trigger a failing test (if possible). After this, anyone may try and trigger a failing test
    // by calling checkTestPasses()
    function checkTestPasses() public override returns (bool) {
        // check if we need to take a checkpoint
        uint32 timeSinceLastCheckpoint = UniswapV2OracleLibrary.currentBlockTimestamp() - lastCheckpointTime;
        if (timeSinceLastCheckpoint > MAX_PERIOD) {
            checkpoint();
        } else if (timeSinceLastCheckpoint > MIN_PERIOD) {
            if (msg.sender != checkpointer && timeSinceLastCheckpoint < MIN_PERIOD + PROTECTED_PERIOD) {
                // only checkpointer can trigger failing test in protected period
                return true;
            }

            lastTestedTwap = twap();
            return lastTestedTwap < MAX_PRICE;
        }

        // if timeSinceLastCheckpoint is less than MIN_PERIOD don't take checkpoint
        // otherwise someone could poke test every 12 hours and prevent it from ever failing
        return true;
    }
}

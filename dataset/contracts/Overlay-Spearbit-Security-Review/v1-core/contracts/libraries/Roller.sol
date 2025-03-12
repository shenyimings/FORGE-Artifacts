// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./Cast.sol";

library Roller {
    using Cast for uint256;
    using Cast for int256;

    struct Snapshot {
        uint32 timestamp; // time last snapshot was taken
        uint32 window; // window (length of time) over which will decay
        int192 accumulator; // accumulator value which will decay to zero over window
    }

    /// @dev returns the stored accumulator value as an int256
    function cumulative(Snapshot memory self) internal view returns (int256) {
        return int256(self.accumulator);
    }

    /// @dev adjusts accumulator value downward linearly over time.
    /// @dev accumulator should go to zero as one window passes
    function transform(
        Snapshot memory self,
        uint256 timestamp,
        uint256 window,
        int256 value
    ) internal view returns (Snapshot memory) {
        uint32 timestamp32 = uint32(timestamp % 2**32); // mod to fit in uint32

        // int/uint256 values to use in calculations
        uint256 dt = uint256(timestamp32 - self.timestamp);
        uint256 snapWindow = uint256(self.window);
        int256 snapAccumulator = cumulative(self);

        if (dt >= snapWindow || snapWindow == 0) {
            // if one window has passed, prior value has decayed to zero
            return
                Snapshot({
                    timestamp: timestamp32,
                    window: window.toUint32Bounded(),
                    accumulator: value.toInt192Bounded()
                });
        }

        // otherwise, calculate fraction of value remaining given linear decay.
        // fraction of value to take off due to decay (linear drift toward zero)
        // is fraction of windowLast that has elapsed since timestampLast
        snapAccumulator -= (snapAccumulator * int256(dt)) / int256(snapWindow);

        // add in the new value for accumulator now
        int256 accumulatorNow = snapAccumulator + value;
        if (accumulatorNow == 0) {
            // if accumulator now is zero, windowNow is simply window
            // to avoid 0/0 case below
            return
                Snapshot({
                    timestamp: timestamp32,
                    window: window.toUint32Bounded(),
                    accumulator: 0
                });
        }

        // recalculate windowNow_ for future decay as a value weighted average time
        // of time left in windowLast for accumulatorLast and window for value
        // vwat = (|accumulatorLastWithDecay| * (windowLast - dt) + |value| * window) /
        //        (|accumulatorLastWithDecay| + |value|)
        // TODO: Use SignedMath in next open zeppelin release 4.5.0
        uint256 w1 = uint256(snapAccumulator >= 0 ? snapAccumulator : -snapAccumulator);
        uint256 w2 = uint256(value >= 0 ? value : -value);
        uint256 windowNow = (w1 * (snapWindow - dt) + w2 * window) / (w1 + w2);
        return
            Snapshot({
                timestamp: timestamp32,
                window: windowNow.toUint32Bounded(),
                accumulator: accumulatorNow.toInt192Bounded()
            });
    }
}

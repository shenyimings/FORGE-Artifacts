// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface IZivoeGlobals_OCE_ZVE {
    /// @notice Returns the address of the ZivoeRewards ($zJTT) contract.
    function stJTT() external view returns (address);

    /// @notice Returns the address of the ZivoeRewards ($zSTT) contract.
    function stSTT() external view returns (address);

    /// @notice Returns the address of the ZivoeRewards ($ZVE) contract.
    function stZVE() external view returns (address);

    /// @notice Returns the address of the Timelock contract.
    function TLC() external view returns (address);

    /// @notice Returns the address of the ZivoeToken contract.
    function ZVE() external view returns (address);
}

interface IZivoeRewards_OCE_ZVE {
    /// @notice Deposits a reward to this contract for distribution.
    /// @param _rewardsToken The asset that's being distributed.
    /// @param reward The amount of the _rewardsToken to deposit.
    function depositReward(address _rewardsToken, uint256 reward) external;
}



/// @notice This contract facilitates an exponential decay emissions schedule for $ZVE.
///         This contract has the following responsibilities:
///           - Handles accounting (with governable variables) to support emissions schedule.
///           - Forwards $ZVE to all ZivoeRewards contracts at will (stZVE, stSTT, stJTT).
contract OCE_ZVE is ZivoeLocker, ReentrancyGuard {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;           /// @dev The ZivoeGlobals contract.

    uint256 public exponentialDecayPerSecond = RAY * 99999999 / 100000000;    /// @dev The rate of decay per second.
    uint256 public lastDistribution;        /// @dev The block.timestamp value of last distribution.

    /// @dev Determines distribution between rewards contract, in BIPS.
    /// @dev Sum of distributionRatioBIPS[0], distributionRatioBIPS[1], and distributionRatioBIPS[2] must equal BIPS.
    ///      distributionRatioBIPS[0] => stZVE
    ///      distributionRatioBIPS[1] => stSTT
    ///      distributionRatioBIPS[2] => stJTT
    uint256[3] public distributionRatioBIPS;

    uint256 private constant BIPS = 10000;
    uint256 private constant RAY = 10 ** 27;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCE_ZVE contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The ZivoeGlobals contract.
    constructor(address DAO, address _GBL) {
        transferOwnershipAndLock(DAO);
        GBL = _GBL;
        lastDistribution = block.timestamp;

        distributionRatioBIPS[0] = 3334;
        distributionRatioBIPS[1] = 3333;
        distributionRatioBIPS[2] = 3333;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during updateDistributionRatioBIPS().
    /// @param  oldRatios The old distribution ratios.
    /// @param  newRatios The new distribution ratios.
    event UpdatedDistributionRatioBIPS(uint256[3] oldRatios, uint256[3] newRatios);

    /// @notice Emitted during forwardEmissions().
    /// @param  stZVE The amount of $ZVE emitted to the $ZVE rewards contract.
    /// @param  stJTT The amount of $ZVE emitted to the $zJTT rewards contract.
    /// @param  stSTT The amount of $ZVE emitted to the $zSTT rewards contract.
    event EmissionsForwarded(uint256 stZVE, uint256 stJTT, uint256 stSTT);

    /// @notice Emitted during updateExponentialDecayPerSecond().
    /// @param  oldValue The old value of exponentialDecayPerSecond.
    /// @param  newValue The new value of exponentialDecayPerSecond.
    event UpdatedExponentialDecayPerSecond(uint256 oldValue, uint256 newValue);



    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice Allocates ZVE from the DAO to this locker for emissions.
    /// @dev    Only callable by the DAO.
    /// @param  asset The asset to push to this locker (in this case $ZVE).
    /// @param  amount The amount of $ZVE to push to this locker.
    /// @param  data Accompanying transaction data.
    function pushToLocker(address asset, uint256 amount, bytes calldata data) external override onlyOwner {
        require(
            asset == IZivoeGlobals_OCE_ZVE(GBL).ZVE(), 
            "OCE_ZVE::pushToLocker() asset != IZivoeGlobals_OCE_ZVE(GBL).ZVE()"
        );
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
    }

    /// @notice Forwards $ZVE available for distribution.
    function forwardEmissions() external nonReentrant {
        uint zveBalance = IERC20(IZivoeGlobals_OCE_ZVE(GBL).ZVE()).balanceOf(address(this));
        _forwardEmissions(zveBalance - decay(zveBalance, block.timestamp - lastDistribution));
        lastDistribution = block.timestamp;
    }

    /// @notice This handles the accounting for forwarding ZVE to lockers privately.
    /// @param amount The amount of $ZVE to distribute.
    function _forwardEmissions(uint256 amount) private {
        require(amount >= 100 ether, "OCE_ZVE::_forwardEmissions amount < 100 ether");

        uint amountZero = amount * distributionRatioBIPS[0] / BIPS;
        uint amountOne = amount * distributionRatioBIPS[1] / BIPS;
        uint amountTwo = amount * distributionRatioBIPS[2] / BIPS;
        address ZVE = IZivoeGlobals_OCE_ZVE(GBL).ZVE();
        address stZVE = IZivoeGlobals_OCE_ZVE(GBL).stZVE();
        address stSTT = IZivoeGlobals_OCE_ZVE(GBL).stSTT();
        address stJTT = IZivoeGlobals_OCE_ZVE(GBL).stJTT();

        emit EmissionsForwarded(amountZero, amountOne, amountTwo);

        IERC20(ZVE).safeIncreaseAllowance(stZVE, amountZero);
        IERC20(ZVE).safeIncreaseAllowance(stSTT, amountOne);
        IERC20(ZVE).safeIncreaseAllowance(stJTT, amountTwo);
        IZivoeRewards_OCE_ZVE(stZVE).depositReward(ZVE, amountZero);
        IZivoeRewards_OCE_ZVE(stSTT).depositReward(ZVE, amountOne);
        IZivoeRewards_OCE_ZVE(stJTT).depositReward(ZVE, amountTwo);
    }
    
    /// @notice Updates the distribution between rewards contract, in BIPS.
    /// @dev    The sum of distributionRatioBIPS[0], [1], and [2] must equal BIPS.
    /// @param  _distributionRatioBIPS The updated values for the state variable distributionRatioBIPS.
    function updateDistributionRatioBIPS(uint256[3] calldata _distributionRatioBIPS) external {
        require(
            _msgSender() == IZivoeGlobals_OCE_ZVE(GBL).TLC(), 
            "OCE_ZVE::updateDistributionRatioBIPS() _msgSender() != IZivoeGlobals_OCE_ZVE(GBL).TLC()"
        );
        require(
            _distributionRatioBIPS[0] + _distributionRatioBIPS[1] + _distributionRatioBIPS[2] == BIPS,
            "OCE_ZVE::updateDistributionRatioBIPS() sum(_distributionRatioBIPS[0-2]) != BIPS"
        );

        emit UpdatedDistributionRatioBIPS(distributionRatioBIPS, _distributionRatioBIPS);
        distributionRatioBIPS[0] = _distributionRatioBIPS[0];
        distributionRatioBIPS[1] = _distributionRatioBIPS[1];
        distributionRatioBIPS[2] = _distributionRatioBIPS[2];
    }

    /// @notice Updates the exponentialDecayPerSecond variable with provided input.
    /// @dev    For 1.0000% decrease per second, _exponentialDecayPerSecond would be (1 - 0.01) * RAY.
    /// @dev    For 0.0001% decrease per second, _exponentialDecayPerSecond would be (1 - 0.000001) * RAY.
    /// @param _exponentialDecayPerSecond The updated value for exponentialDecayPerSecond state variable.
    function updateExponentialDecayPerSecond(uint256 _exponentialDecayPerSecond) external {
        require(
            _msgSender() == IZivoeGlobals_OCE_ZVE(GBL).TLC(), 
            "OCE_ZVE::updateExponentialDecayPerSecond() _msgSender() != IZivoeGlobals_OCE_ZVE(GBL).TLC()"
        );
        require(
            _exponentialDecayPerSecond >= RAY * 99999998 / 100000000,
            "OCE_ZVE::updateExponentialDecayPerSecond() _exponentialDecayPerSecond < RAY * 99999998 / 100000000"
        );
        require(
            _exponentialDecayPerSecond < RAY,
            "OCE_ZVE::updateExponentialDecayPerSecond() _exponentialDecayPerSecond >= RAY"
        );
        emit UpdatedExponentialDecayPerSecond(exponentialDecayPerSecond, _exponentialDecayPerSecond);
        exponentialDecayPerSecond = _exponentialDecayPerSecond; 
    }



    // ----------
    //    Math
    // ----------

    /// @notice Returns the amount remaining after a decay.
    /// @param top The amount decaying.
    /// @param dur The seconds of decay.
    function decay(uint256 top, uint256 dur) public view returns (uint256) {
        return rmul(top, rpow(exponentialDecayPerSecond, dur, RAY));
    }

    // rmul() and rpow() were ported from MakerDAO:
    // https://github.com/makerdao/dss/blob/master/src/abaci.sol

    /// @notice Multiplies two variables and returns value, truncated by RAY precision.
    /// @param x First value to multiply.
    /// @param y Second value to multiply.
    /// @return z Resulting value of x * y, truncated by RAY precision.
    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x * y;
        require(y == 0 || z / y == x, "OCE_ZVE::rmul() y != 0 && z / y != x");
        z = z / RAY;
    }
    
    /**
        @notice rpow(uint256 x, uint256 n, uint256 b), used for exponentiation in drip, is a fixed-point arithmetic 
                function that raises x to the power n. It is implemented in Solidity assembly as a repeated squaring 
                algorithm. x and the returned value are to be interpreted as fixed-point integers with scaling factor b. 
                For example, if b == 100, this specifies two decimal digits of precision and the normal decimal value 
                2.1 would be represented as 210; rpow(210, 2, 100) returns 441 (the two-decimal digit fixed-point 
                representation of 2.1^2 = 4.41). In the current implementation, 10^27 is passed for b, making x and 
                the rpow result both of type RAY in standard MCD fixed-point terminology. rpow's formal invariants 
                include "no overflow" as well as constraints on gas usage.
        @param  x The base value.
        @param  n The power to raise "x" by.
        @param  b The scaling factor, a.k.a. resulting precision of "z".
        @return z Resulting value of x^n, scaled by factor b.
    */
    function rpow(uint256 x, uint256 n, uint256 b) internal pure returns (uint256 z) {
        assembly {
            switch n case 0 { z := b }
            default {
                switch x case 0 { z := 0 }
                default {
                    switch mod(n, 2) case 0 { z := b } default { z := x }
                    let half := div(b, 2)  // For rounding.
                    for { n := div(n, 2) } n { n := div(n,2) } {
                        let xx := mul(x, x)
                        if shr(128, x) { revert(0,0) }
                        let xxRound := add(xx, half)
                        if lt(xxRound, xx) { revert(0,0) }
                        x := div(xxRound, b)
                        if mod(n,2) {
                            let zx := mul(z, x)
                            if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                            let zxRound := add(zx, half)
                            if lt(zxRound, zx) { revert(0,0) }
                            z := div(zxRound, b)
                        }
                    }
                }
            }
        }
    }

}

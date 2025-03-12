// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./IPool.sol";

/*
 * The Stability Pool holds EUSD tokens deposited by Stability Pool depositors.
 *
 * When a trove is liquidated, then depending on system conditions, some of its EUSD debt gets offset with
 * EUSD in the Stability Pool:  that is, the offset debt evaporates, and an equal amount of EUSD tokens in the Stability Pool is burned.
 *
 * Thus, a liquidation causes each depositor to receive a EUSD loss, in proportion to their deposit as a share of total deposits.
 * They also receive an ETH/wrapperETH gain, as the ETH/wrapperETH collateral of the liquidated trove is distributed among Stability depositors,
 * in the same proportion.
 *
 * When a liquidation occurs, it depletes every deposit by the same fraction: for example, a liquidation that depletes 40%
 * of the total EUSD in the Stability Pool, depletes 40% of each deposit.
 *
 * A deposit that has experienced a series of liquidations is termed a "compounded deposit": each liquidation depletes the deposit,
 * multiplying it by some factor in range ]0,1[
 */
interface IStabilityPool is IPool {
    // --- Data structures ---

    struct FrontEnd {
        uint256 kickbackRate;
        bool registered;
    }

    struct Deposit {
        uint256 initialValue;
        address frontEndTag;
    }

    struct Snapshots {
        mapping(address => uint256) S;
        uint256 P;
        uint256 G;
        uint128 scale;
        uint128 epoch;
    }

    // --- Events ---
    event StabilityPoolCollBalanceUpdated(
        address _collateral,
        uint256 _newBalance
    );
    event StabilityPoolEUSDBalanceUpdated(uint256 _newBalance);

    event P_Updated(uint256 _P);
    event S_Updated(uint256[] _S, uint128 _epoch, uint128 _scale);
    event G_Updated(uint256 _G, uint128 _epoch, uint128 _scale);
    event EpochUpdated(uint128 _currentEpoch);
    event ScaleUpdated(uint128 _currentScale);

    event FrontEndRegistered(address indexed _frontEnd, uint256 _kickbackRate);
    event FrontEndTagSet(address indexed _depositor, address indexed _frontEnd);

    event DepositSnapshotUpdated(
        address indexed _depositor,
        uint256 _P,
        uint256[] _S,
        uint256 _G
    );
    event FrontEndSnapshotUpdated(
        address indexed _frontEnd,
        uint256 _P,
        uint256 _G
    );
    event UserDepositChanged(address indexed _depositor, uint256 _newDeposit);
    event FrontEndStakeChanged(
        address indexed _frontEnd,
        uint256 _newFrontEndStake,
        address _depositor
    );

    event CollGainWithdrawn(
        address indexed _depositor,
        uint256[] _collAmounts,
        uint256 _EUSDLoss
    );
    event GainPaidToDepositor(address indexed _depositor, uint256 _GAIN);
    event GainPaidToFrontEnd(address indexed _frontEnd, uint256 _GAIN);

    // --- Functions ---

    /*
     * Called only once on init, to set addresses of other ERD contracts
     * Callable only by owner, renounces ownership at the end
     */
    function setAddresses(
        address _borrowerOperationsAddress,
        address _troveManagerAddress,
        address _collateralManagerAddress,
        address _troveManagerLiquidationsAddress,
        address _activePoolAddress,
        address _eusdTokenAddress,
        address _sortedTrovesAddress,
        address _priceFeedAddress,
        address _communityIssuanceAddress,
        address _wethAddress
    ) external;

    /*
     * Initial checks:
     * - Frontend is registered or zero address
     * - Sender is not a registered frontend
     * - _amount is not zero
     * ---
     * - Triggers a gain or nothing issuance, based on time passed since the last issuance. The gain issuance is shared between *all* depositors and front ends
     * - Tags the deposit with the provided front end tag param, if it's a new deposit
     * - Sends depositor's accumulated gains collateral(ETH/wrapperETH) to depositor
     * - Sends the tagged front end's accumulated GAIN gains to the tagged front end
     * - Increases deposit and tagged front end's stake, and takes new snapshots for each.
     */
    function provideToSP(uint256 _amount, address _frontEndTag) external;

    /*
     * Initial checks:
     * - _amount is zero or there are no under collateralized troves left in the system
     * - User has a non zero deposit
     * ---
     * - Triggers a gain or nothing issuance, based on time passed since the last issuance. The gain issuance is shared between *all* depositors and front ends
     * - Removes the deposit's front end tag if it is a full withdrawal
     * - Sends all depositor's accumulated gains (ETH/wrapperETH) to depositor
     * - Sends the tagged front end's accumulated GAIN gains to the tagged front end
     * - Decreases deposit and tagged front end's stake, and takes new snapshots for each.
     *
     * If _amount > userDeposit, the user withdraws all of their compounded deposit.
     */
    function withdrawFromSP(uint256 _amount) external;

    /*
     * Initial checks:
     * - User has a non zero deposit
     * - User has an open trove
     * - User has some ETH gain
     * ---
     * - Triggers a gain or nothing issuance, based on time passed since the last issuance. The gain issuance is shared between *all* depositors and front ends
     * - Sends all depositor's GAIN gain to  depositor
     * - Sends all tagged front end's GAIN gain to the tagged front end
     * - Transfers the depositor's entire ETH/wrapperETH gain from the Stability Pool to the caller's trove
     * - Leaves their compounded deposit in the Stability Pool
     * - Updates snapshots for deposit and tagged front end stake
     */
    function withdrawCollateralGainToTrove(
        address _upperHint,
        address _lowerHint
    ) external;

    /*
     * Initial checks:
     * - Frontend (sender) not already registered
     * - User (sender) has no deposit
     * - _kickbackRate is in the range [0, 100%]
     * ---
     * Front end makes a one-time selection of kickback rate upon registering
     */
    function registerFrontEnd(uint256 _kickbackRate) external;

    /*
     * Initial checks:
     * - Caller is TroveManager
     * ---
     * Cancels out the specified debt against the EUSD contained in the Stability Pool (as far as possible)
     * and transfers the Trove's ETH/wrapperETH collateral from ActivePool to StabilityPool.
     * Only called by liquidation functions in the TroveManager.
     */
    function offset(
        uint256 _debtToOffset,
        address[] memory _collaterals,
        uint256[] memory _collToAdd
    ) external;

    /*
     * Returns the total amount of collateral held by the pool, accounted in an internal variable instead of `balance`,
     * to exclude edge cases like collateral received from a self-destruct.
     */
    // function getTotalCollateral() external view returns (uint256, address[] memory, uint256[] memory);

    // function getCollateralAmount(address _collateral) external view returns (uint256);

    /*
     * Returns EUSD held in the pool. Changes when users deposit/withdraw, and when Trove debt is offset.
     */
    function getTotalEUSDDeposits() external view returns (uint256);

    /*
     * Calculates the colalteral gain earned by the deposit since its last snapshots were taken.
     */
    function getDepositorCollateralGain(
        address _depositor
    ) external view returns (address[] memory, uint256[] memory);

    /*
     * Return the user's compounded deposit.
     */
    function getCompoundedEUSDDeposit(
        address _depositor
    ) external view returns (uint256);

    /*
     * Return the front end's compounded stake.
     *
     * The front end's compounded stake is equal to the sum of its depositors' compounded deposits.
     */
    function getCompoundedFrontEndStake(
        address _frontEnd
    ) external view returns (uint256);

    function getDepositorGain(
        address _depositor
    ) external view returns (uint256);

    function getFrontEndGain(address _frontEnd) external view returns (uint256);

    function getDepositSnapshotS(
        address depositor,
        address collateral
    ) external view returns (uint256);
}

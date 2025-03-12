// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// contracts
import {Pausable} from "../lib/openzeppelin-contracts/contracts/security/Pausable.sol";
import {IncreAccessControl} from "./utils/IncreAccessControl.sol";

// interfaces
import {ISettlement} from "./interfaces/ISettlement.sol";
import {IPerpetual} from "./interfaces/IPerpetual.sol";
import {IVBase} from "./interfaces/IVBase.sol";
import {IVQuote} from "./interfaces/IVQuote.sol";
import {ICryptoSwap} from "./interfaces/ICryptoSwap.sol";
import {IClearingHouse} from "./interfaces/IClearingHouse.sol";
import {ICurveCryptoViews} from "./interfaces/ICurveCryptoViews.sol";
import {IERC20Metadata} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// libraries
import {LibMath} from "./lib/LibMath.sol";
import {LibPerpetual} from "./lib/LibPerpetual.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

/// @notice Used for settling users' profit and loss for one or more Perpetual contracts that have been delisted
/// @dev This contract gets treated as a Perpetual contract by the Clearing House after being allowlisted, so it
///      implements the IPerpetual interface, albeit with most functions doing nothing since it isn't a market.
///      However it does prevent users who had open positions in the delisted markets from interacting with other
///      markets until they have proved their PnL for the delisted markets by reverting in certain functions which
///      the Clearing House calls for all markets before changing the user's position. To prove their PnL, users
///      prove their position in a merkle tree containing user addresses and settlement values, which is generated
///      offchain and must be agreed upon by governance.
contract PerpSettlement is IPerpetual, ISettlement, Pausable, IncreAccessControl {
    using LibMath for int256;
    using LibMath for uint256;

    /// @notice Clearing House contract
    IClearingHouse public immutable clearingHouse;

    // constants for variables in IPerpetual which are not used here
    // slither-disable-next-line naming-convention
    bool public constant isTradingExpansionAllowed = false;
    // slither-disable-next-line naming-convention
    ICryptoSwap public constant market = ICryptoSwap(address(0));
    // slither-disable-next-line naming-convention
    IVBase public constant vBase = IVBase(address(0));
    // slither-disable-next-line naming-convention
    IVQuote public constant vQuote = IVQuote(address(0));
    // slither-disable-next-line naming-convention
    ICurveCryptoViews public constant curveCryptoViews = ICurveCryptoViews(address(0));
    // slither-disable-next-line naming-convention
    uint256 public constant maxLiquidityProvided = 0;
    // slither-disable-next-line naming-convention
    int256 public constant oracleCumulativeAmount = 0;
    // slither-disable-next-line naming-convention
    int256 public constant oracleCumulativeAmountAtBeginningOfPeriod = 0;
    // slither-disable-next-line naming-convention
    int256 public constant marketCumulativeAmount = 0;
    // slither-disable-next-line similar-names,naming-convention
    int256 public constant marketCumulativeAmountAtBeginningOfPeriod = 0;
    // slither-disable-next-line naming-convention
    uint256 public constant riskWeight = 1e18;
    // slither-disable-next-line naming-convention
    uint256 public constant twapFrequency = 0;
    // slither-disable-next-line naming-convention
    int256 public constant sensitivity = 0;
    // slither-disable-next-line naming-convention
    uint256 public constant maxBlockTradeAmount = 0;
    // slither-disable-next-line naming-convention
    uint256 public constant maxPosition = 0;
    // slither-disable-next-line naming-convention
    int256 public constant insuranceFee = 0;
    // slither-disable-next-line naming-convention
    int256 public constant lpDebtCoef = 1e18;
    // slither-disable-next-line naming-convention
    uint256 public constant lockPeriod = 0;
    // slither-disable-next-line naming-convention
    int128 public constant oracleTwap = 1e18;
    // slither-disable-next-line naming-convention
    int128 public constant marketTwap = 1e18;
    // slither-disable-next-line naming-convention
    uint256 public constant marketPrice = 1e18;
    // slither-disable-next-line naming-convention
    int256 public constant indexPrice = 1e18;
    // slither-disable-next-line naming-convention
    uint256 public constant getTotalLiquidityProvided = 0;

    /// @notice List of delisted Perpetual contracts
    /// @dev Effectively immutable, but arrays cannot be declared as immutable
    IPerpetual[] public markets;

    /// @notice Merkle root of the PnL tree
    bytes32 public merkleRoot;

    // user state
    mapping(address => LibPerpetual.TraderPosition) internal traderPosition;
    mapping(address => bool) internal isTraderPositionProved;

    constructor(IClearingHouse _clearingHouse, IPerpetual[] memory _markets, bytes32 newMerkleRoot) {
        clearingHouse = _clearingHouse;
        markets = _markets;
        merkleRoot = newMerkleRoot;
        emit MerkleRootUpdated(bytes32(0), newMerkleRoot);
    }

    /// @notice Modifier for functions that can only be called by the Clearing House
    /// @dev In a normal Perpetual this would be applied to `changePosition`, `settleTraderFunding`,
    ///      `provideLiquidity`, `removeLiquidity` and `settleLpFunding`, but here it is only needed
    ///      for `changePosition` since the other functions do nothing in this contract
    modifier onlyClearingHouse() {
        if (msg.sender != address(clearingHouse)) revert Perpetual_SenderNotClearingHouse();
        _;
    }

    modifier checkPositionProof(address account) {
        if (mustPostPosition(account)) revert Settlement_MustPostPositionProof();
        _;
    }

    /* ****************** */
    /*     Settlement     */
    /* ****************** */

    /// @notice Post the PnL proof for a trader or LP
    /// @param userProof PnLProof struct containing:
    ///         address account: the address of the trader or LP
    ///         int128 pnl: the settlement value of the trader or LP
    ///         bytes32[] merkleProof: array of hashes from the merkle tree to prove the position
    function postPnL(PnLProof calldata userProof) external {
        if (!verifyPnL(userProof)) revert Settlement_InvalidMerkleProof();

        traderPosition[userProof.account].openNotional = userProof.pnl;
        isTraderPositionProved[userProof.account] = true;

        emit PositionVerified(userProof.account, userProof.pnl, userProof.merkleProof);
    }

    /// @notice Determines if a user must post a position proof for the delisted market(s)
    /// @dev A user must post a proof if they have an open position in any of the markets and haven't already proved their PnL
    /// @param account The address of the trader or LP
    /// @return true if the trader or LP must post a position proof, false otherwise
    function mustPostPosition(address account) public view returns (bool) {
        // if trader has already proved their position, then return false
        if (isTraderPositionProved[account]) return false;
        uint256 numMarkets = markets.length;
        // slither-disable-next-line uninitialized-local
        for (uint256 i; i < numMarkets; ++i) {
            if (markets[i].isTraderPositionOpen(account) || markets[i].isLpPositionOpen(account)) {
                // if trader has an open position in any of the delisted markets, then return true
                return true;
            }
        }
        // if trader has no open positions in any of the delisted markets, then return false
        return false;
    }

    /// @notice Verify the PnL proof for a trader or LP
    /// @dev Does not store the proof or change any state
    /// @param userProof PnLProof struct containing:
    ///         address account: the address of the trader or LP
    ///         int128 pnl: the settlement value of the trader or LP
    ///         bytes32[] merkleProof: array of hashes from the merkle tree to prove the position
    /// @return True if the proof is valid, false otherwise
    function verifyPnL(PnLProof calldata userProof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(userProof.account, userProof.pnl));
        return MerkleProof.verify(userProof.merkleProof, merkleRoot, leaf);
    }

    /// @notice Set the merkle root of the PnL tree
    /// @dev Only callable by governance
    /// @param newMerkleRoot The new merkle root
    function setMerkleRoot(bytes32 newMerkleRoot) external onlyRole(GOVERNANCE) {
        emit MerkleRootUpdated(merkleRoot, newMerkleRoot);
        merkleRoot = newMerkleRoot;
    }

    /* ****************** */
    /*     Perpetual      */
    /* (state modifying)  */
    /* ****************** */

    /// @notice Settles the position of a user in the delisted markets if they have proved their PnL
    /// @dev This function is normally used to change the position of a user in a market, whether
    ///      that be opening, closing or increasing a position. However, here it is used only to
    ///      settle the position, so the only parameter we care about is `account`.
    /// @return quoteProceeds Always 0
    /// @return baseProceeds Always 0
    /// @return profit The profit or loss of the user before settling
    /// @return tradingFeesPayed Always 0
    /// @return isPositionIncreased Always false
    /// @return isPositionClosed Always true
    function changePosition(address account, uint256, uint256, LibPerpetual.Side, bool)
        external
        onlyClearingHouse
        checkPositionProof(account)
        returns (
            int256 quoteProceeds,
            int256 baseProceeds,
            int256 profit,
            int256 tradingFeesPayed,
            bool isPositionIncreased,
            bool isPositionClosed
        )
    {
        profit = traderPosition[account].openNotional;
        traderPosition[account].openNotional = 0;
        return (0, 0, profit, 0, false, true);
    }

    /* ****************** */
    /*     Perpetual      */
    /*    (view/pure)     */
    /* ****************** */

    /// @notice Get a trader's position in the delisted markets
    /// @dev Reverts if the trader needs to prove their PnL
    /// @param account The address of the trader
    /// @return TraderPosition struct with the trader's PnL as `openNotional`
    function getTraderPosition(address account)
        external
        view
        checkPositionProof(account)
        returns (LibPerpetual.TraderPosition memory)
    {
        return traderPosition[account];
    }

    /// @notice Always returns an empty TraderPosition struct
    function getLpPositionAfterWithdrawal(address) external pure returns (LibPerpetual.TraderPosition memory) {
        // we do not support LP position in settlement contract
        return LibPerpetual.TraderPosition({openNotional: 0, positionSize: 0, cumFundingRate: 0});
    }

    /// @notice Always returns 0
    function getLpLiquidity(address) external pure returns (uint256) {
        // we do not support LP position in settlement contract
        return 0;
    }

    /// @notice Always returns an empty LiquidityProviderPosition struct
    function getLpPosition(address) external pure returns (LibPerpetual.LiquidityProviderPosition memory) {
        // we do not support LP position in settlement contract
        return LibPerpetual.LiquidityProviderPosition({
            openNotional: 0,
            positionSize: 0,
            liquidityBalance: 0,
            depositTime: 0,
            totalTradingFeesGrowth: 0,
            totalBaseFeesGrowth: 0,
            totalQuoteFeesGrowth: 0,
            cumFundingPerLpToken: 0
        });
    }

    /// @notice Always returns an empty GlobalPosition struct
    function getGlobalPosition() external pure returns (LibPerpetual.GlobalPosition memory) {
        return LibPerpetual.GlobalPosition({
            timeOfLastTrade: 0,
            timeOfLastTwapUpdate: 0,
            cumFundingRate: 0,
            totalQuoteProvided: 0,
            totalBaseProvided: 0,
            cumFundingPerLpToken: 0,
            currentBlockTradeAmount: 0,
            totalTradingFeesGrowth: 0,
            totalBaseFeesGrowth: 0,
            totalQuoteFeesGrowth: 0,
            traderLongs: 0,
            traderShorts: 0
        });
    }

    /// @notice Get a user's PnL in the delisted markets
    /// @dev Reverts if the user needs to prove their PnL
    /// @param account The address of the trader or LP
    /// @return The user's PnL
    function getTraderUnrealizedPnL(address account) external view checkPositionProof(account) returns (int256) {
        return traderPosition[account].openNotional;
    }

    /// @notice Always returns 0
    /// @dev For LP's PnL, we still use `getTraderUnrealizedPnL` here
    function getLpUnrealizedPnL(address) external pure returns (int256) {
        return 0;
    }

    /// @notice Always returns 0
    function getLpTradingFees(address) external pure returns (uint256) {
        return 0;
    }

    /// @notice Get a user's PnL in the delisted markets
    /// @dev Reverts if the user needs to prove their PnL
    /// @param account The address of the trader or LP
    /// @return The user's PnL
    function getPendingPnL(address account) external view checkPositionProof(account) returns (int256) {
        return traderPosition[account].openNotional;
    }

    /// @notice Get a user's debt in the delisted markets
    /// @dev Reverts if the user needs to prove their PnL
    /// @param account The address of the trader or LP
    /// @return The user's PnL if negative, 0 otherwise
    function getUserDebt(address account) external view checkPositionProof(account) returns (int256) {
        return int256(traderPosition[account].openNotional).min(0);
    }

    /// @notice Check if a user has an open position in the delisted markets
    /// @dev Reverts if the user needs to prove their PnL
    /// @param account The address of the trader or LP
    /// @return true if the user has an unsettled open position, false otherwise
    function isTraderPositionOpen(address account) external view checkPositionProof(account) returns (bool) {
        return traderPosition[account].openNotional != 0;
    }

    /// @notice Always returns false
    function isLpPositionOpen(address) external pure returns (bool) {
        return false;
    }

    /// @notice Always returns 0
    function getLpOpenNotional(address) external pure returns (int256) {
        return 0;
    }

    /// @notice Always reverts
    function removeLiquiditySwap(address, uint256, uint256[2] calldata, bytes memory) external pure {
        revert Settlement_RemoveLiquidityNotAllowed();
    }

    /// @notice Always reverts
    function provideLiquidity(address, uint256[2] calldata, uint256) external pure returns (int256) {
        revert Settlement_ProvideLiquidityNotAllowed();
    }

    /// @notice Always reverts
    function removeLiquidity(address, uint256, uint256[2] calldata, uint256, uint256, bool)
        external
        pure
        returns (int256, int256, uint256, int256, bool)
    {
        revert Settlement_RemoveLiquidityNotAllowed();
    }

    /// @notice Always returns 0
    /// @dev Reverts if the user needs to prove their PnL
    /// @param account The address of the trader or LP
    function settleTraderFunding(address account)
        external
        view
        checkPositionProof(account)
        returns (int256 fundingPayments)
    {
        return 0;
    }

    /// @notice Always returns 0
    function settleLpFunding(address) external pure returns (int256 fundingPayments) {
        return 0;
    }

    /// @notice Always reverts
    function toggleTradingExpansionPause(bool) external pure {
        revert Settlement_ToggleTradingExpansionNotAllowed();
    }

    /// @notice Does nothing
    function pause() external pure {}

    /// @notice Does nothing
    function unpause() external pure {}

    /// @notice Always reverts
    function setParameters(PerpetualParams memory) external pure {
        revert Settlement_SetParametersNotAllowed();
    }

    /// @notice Does nothing
    function updateGlobalState() external pure {}
}

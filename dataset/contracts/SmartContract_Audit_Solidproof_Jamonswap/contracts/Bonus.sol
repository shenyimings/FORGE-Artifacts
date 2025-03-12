// SPDX-License-Identifier: MIT
pragma solidity =0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IERC20MintBurn.sol";
import "./interfaces/IJamonRouter.sol";
import "./interfaces/IJamonPair.sol";
import "./interfaces/IJamonVesting.sol";

/**
 * @title Bonus
 * @notice This contract allows the contribution of liquidity to the DEX in exchange for rewards in the JamonV2 token.
 *   Each bonus will have a ratio and hardcap that will be set at the time of creation.
 *   The reward will be calculated based on the value of the contributed LP in USD times the reward ratio.
 */
contract Bonus is ReentrancyGuard, Pausable, Ownable {
    //---------- Libraries ----------//
    using SafeMath for uint256;
    using SafeERC20 for IJamonPair;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    //---------- Contracts ----------//
    IERC20MintBurn private Jamon_V2;
    IJamonRouter private Router;
    IJamonVesting private Vesting;
    IJamonPair private JamonUSDCV2LP;

    //---------- Variables ----------//
    EnumerableSet.Bytes32Set private BonusMap;
    EnumerableSet.AddressSet private StableCoins;
    EnumerableSet.AddressSet private PriceFeeds;
    address private Governor;
    address private JamonShareVault;
    address private USDC;

    //---------- Storage -----------//
    struct BonusInput {
        uint256 amount;
        uint256 reward;
    }

    struct Proposal {
        address lpAddress;
        address feedToken;
        uint256 startBlock;
        uint256 endBlock;
        uint256 collected;
        uint256 hardcap;
        uint256 rate;
        mapping(address => BonusInput) holders;
    }

    struct Feed {
        address proxy;
        uint256 decimals;
    }

    mapping(bytes32 => Proposal) internal BONUS;
    mapping(address => Feed) public FEEDS;

    //---------- Events -----------//
    event Contributed(
        bytes32 indexed id,
        address indexed wallet,
        address lp,
        uint256 amount,
        uint256 reward
    );

    event NewBonus(address indexed lp, bytes32 id);

    //---------- Constructor ----------//
    constructor(
        address jamonV2_,
        address jamonUSDClp_,
        address vesting_,
        address governor_,
        address jamonShareVault_,
        address usdc_
    ) {
        require(
            jamonV2_ != address(0x0) &&
                jamonUSDClp_ != address(0x0) &&
                vesting_ != address(0x0) &&
                governor_ != address(0x0) &&
                jamonShareVault_ != address(0x0) &&
                usdc_ != address(0x0),
            "Invalid address"
        );
        Jamon_V2 = IERC20MintBurn(jamonV2_);
        Router = IJamonRouter(0xdBe30E8742fBc44499EB31A19814429CECeFFaA0);
        JamonUSDCV2LP = IJamonPair(jamonUSDClp_);
        Vesting = IJamonVesting(vesting_);
        Governor = governor_;
        JamonShareVault = jamonShareVault_;
        USDC = usdc_;
        /**
         * Network: Polygon
         ------------------------------
         * Aggregator: MATIC/USD
         * Address: 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
         */
        FEEDS[Router.WETH()].proxy = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;
        FEEDS[Router.WETH()].decimals = 8;
        require(PriceFeeds.add(address(Router.WETH())), "Add feed error");
    }

    //----------- Internal Functions -----------//
    /**
     * @dev Take the price of the token depending on whether it is stable, JamonV2 or by consulting the ChainLink aggregator.
     * @return the price of token in ether
     */
    function _getTokenPrice(address token_) public view returns (uint256) {
        if (StableCoins.contains(token_)) {
            return 1 ether;
        }
        if (token_ == address(Jamon_V2)) {
            return _getJamon2USD(1 ether);
        }
        if (PriceFeeds.contains(token_)) {
            (, int256 price, , , ) = AggregatorV3Interface(FEEDS[token_].proxy)
                .latestRoundData();
            uint256 decimals = FEEDS[token_].decimals;
            decimals = decimals < 18 ? uint256(18).sub(decimals) : decimals;
            if (decimals != 18) {
                return uint256(price).mul(10**decimals);
            }
            return uint256(price);
        }
        return 0;
    }

    /**
     * @dev Take the price of JamonV2 compared to USD.
     * @param usdAmount_ amount in USD for query.
     * @return the price of token in ether
     */
    function _getUSD2Jamon(uint256 usdAmount_) public view returns (uint256) {
        address token0 = JamonUSDCV2LP.token0();
        (uint256 Res0, uint256 Res1, ) = JamonUSDCV2LP.getReserves();
        uint256 price;
        if (USDC == token0) {
            Res0 = Res0 * (1e12); // USDC 6 decimals, 6 + 12
            price = ((usdAmount_ * Res1) / Res0);
        } else {
            Res1 = Res1 * (1e12); // USDC 6 decimals, 6 + 12
            price = ((usdAmount_ * Res0) / Res1);
        }
        return price; // return amount of token0 needed to buy token1
    }

    /**
     * @dev Take the price of USD compared to JamonV2.
     * @param jamonAmount_ amount in JamonV2 for query.
     * @return the price of token in ether
     */
    function _getJamon2USD(uint256 jamonAmount_) public view returns (uint256) {
        address token0 = JamonUSDCV2LP.token0();
        (uint256 Res0, uint256 Res1, ) = JamonUSDCV2LP.getReserves();
        uint256 price;
        if (USDC == token0) {
            Res0 = Res0 * (1e12); // USDC 6 decimals, 6 + 12
            price = ((jamonAmount_ * Res0) / Res1);
        } else {
            Res1 = Res1 * (1e12); // USDC 6 decimals, 6 + 12
            price = ((jamonAmount_ * Res1) / Res0);
        }
        return price; // return amount of token0 needed to buy token1
    }

    /**
     * @dev Make the transfers of the contributed liquidity, 0.2% is sent to the JamonShare pool and the rest to the governance contract to block the liquidity.
     * @param lp_ Address of pair.
     * @param from_ The spender of the liquidity.
     * @param amount_ The amount aported.
     */
    function _doTransfers(
        address lp_,
        address from_,
        uint256 amount_
    ) internal virtual {
        uint256 toVault = amount_.mul(20).div(10000);
        uint256 amount = amount_;
        if (toVault > 0) {
            IJamonPair(lp_).safeTransferFrom(from_, JamonShareVault, toVault);
            amount = amount.sub(toVault);
        }
        IJamonPair(lp_).safeTransferFrom(from_, Governor, amount);
    }

    //----------- External Functions -----------//

    function bonusInfo(bytes32 bonusId_)
        external
        view
        returns (
            address lpAddress,
            address feedToken,
            uint256 startBlock,
            uint256 endBlock,
            uint256 collected,
            uint256 hardcap,
            uint256 rate
        )
    {
        Proposal storage p = BONUS[bonusId_];
        return (
            p.lpAddress,
            p.feedToken,
            p.startBlock,
            p.endBlock,
            p.collected,
            p.hardcap,
            p.rate
        );
    }

    /**
     * @notice Show the contribution data by wallet.
     * @param bonusId_ The id of the bonus in bytes32.
     * @param wallet_ The wallet address to query.
     * @return amount The amount contributed by wallet.
     * @return reward The reward earned by wallet.
     */
    function walletInfo(bytes32 bonusId_, address wallet_)
        external
        view
        returns (uint256 amount, uint256 reward)
    {
        Proposal storage p = BONUS[bonusId_];
        return (p.holders[wallet_].amount, p.holders[wallet_].reward);
    }

    /**
     * @notice Calculate the remaining amount on sale of the bonus.
     * @param bonusId_ The id of the bonus in bytes32.
     * @return The amount of LP available to contribute.
     */
    function remaining4Sale(bytes32 bonusId_) public view returns (uint256) {
        Proposal storage p = BONUS[bonusId_];
        uint256 available = p.hardcap.sub(p.collected);
        if (available > 0) {
            uint256 tokensBase = (available.div(2).mul(1e18)).div(
                _getTokenPrice(p.feedToken)
            );
            uint256 totalTokenBase = IERC20(p.feedToken).balanceOf(
                address(p.lpAddress)
            );
            uint256 totalSupply = IJamonPair(p.lpAddress).totalSupply();
            uint256 percentage = tokensBase.mul(1e18).div(totalTokenBase);
            return percentage.mul(totalSupply).div(1e18);
        }
        return 0;
    }

    /**
     * @notice Check if the base token for the price query is correct.
     * @param token_ The address of the base token for query.
     * @return If it is correct or not.
     */
    function isValidBase(address token_) public view returns (bool) {
        return (StableCoins.contains(token_) ||
            PriceFeeds.contains(token_) ||
            token_ == address(Jamon_V2));
    }

    /**
     * @dev Check the total number of bonuses.
     * @return The total number of bonuses.
     */
    function totalBonus() external view returns (uint256) {
        return BonusMap.length();
    }

    /**
     * @notice Check the bonus according to the index.
     * @param index_ The index to check.
     * @return The id corresponding to the queried index.
     */
    function bonusAt(uint256 index_) external view returns (bytes32) {
        return BonusMap.at(index_);
    }

    /**
     * @notice Check if the bonus is already on sale.
     * @param bonus_ The id of bonus to check.
     * @return If it is on sale or not.
     */
    function isBonusOpen(bytes32 bonus_) public view returns (bool) {
        Proposal storage p = BONUS[bonus_];
        if (p.startBlock < block.number && p.endBlock > block.number) {
            return remaining4Sale(bonus_) > 0;
        }
        return false;
    }

    /**
     * @notice Provides liquidity to the dex rewarding with JamonV2 based on the value in USD contributed for a fixed ratio and locking the reward for 12 months.
     * @param bonusId_ bytes32 id of the bonus desired.
     * @param amount_ uint256 amount of LP tokens aported.
     */
    function contribute(bytes32 bonusId_, uint256 amount_)
        external
        whenNotPaused
        nonReentrant
    {
        require(BonusMap.contains(bonusId_), "Invalid ID");
        require(amount_ > 0, "Invalid amount");
        require(isBonusOpen(bonusId_), "Not open");
        uint256 allowed = remaining4Sale(bonusId_);
        uint256 amount = amount_ > allowed ? allowed : amount_;
        require(amount > 0, "Amount not allowed");
        Proposal storage p = BONUS[bonusId_];
        address LP = p.lpAddress;
        address feedToken = p.feedToken;
        uint256 totalSupply = IERC20(LP).totalSupply();
        uint256 totalFeedToken = IERC20(feedToken).balanceOf(LP);
        uint256 feedDecimals = IERC20Metadata(feedToken).decimals();
        require(
            feedDecimals > 0 && totalSupply > 0 && totalFeedToken > 0,
            "Balances error"
        );
        feedDecimals = feedDecimals < 18
            ? uint256(18).sub(feedDecimals)
            : feedDecimals;
        if (feedDecimals != 18) {
            totalFeedToken = totalFeedToken.mul(10**feedDecimals);
        }
        totalFeedToken = totalFeedToken.mul(2);
        uint256 percentage = amount.mul(10e18).div(totalSupply);
        uint256 contributed = percentage.mul(totalFeedToken).div(10e18);
        uint256 amountUSD = contributed.mul(_getTokenPrice(feedToken)).div(
            1e18
        );
        uint256 JamonReward = _getUSD2Jamon(amountUSD).mul(p.rate).div(100);
        require(JamonReward > 0, "Zero reward");
        _doTransfers(LP, _msgSender(), amount);
        p.collected += amountUSD;
        p.holders[_msgSender()].amount += amount;
        p.holders[_msgSender()].reward += JamonReward;
        Vesting.createVestingSchedule(_msgSender(), JamonReward);
        emit Contributed(bonusId_, _msgSender(), LP, amount, JamonReward);
    }

    /**
     * @notice Creates a new bonus.
     * @param lpAddress_ address of lp token accepted.
     * @param feedToken_ address of the token that will be used to query the price.
     * @param startBlock_ uint256 of the block in which the contribution will start.
     * @param endBlock_ uint256 of the block in which the contribution ends.
     * @param hardcap_ uint256 in wei of the maximum in USD that is allowed to contribute.
     * @param rate_ uint256 of the reward ratio per USD contributed, ratio between 1.2 and 1.8.
     */
    function addBonus(
        address lpAddress_,
        address feedToken_,
        uint256 startBlock_,
        uint256 endBlock_,
        uint256 hardcap_,
        uint256 rate_
    ) external onlyOwner returns (bytes32) {
        require(
            lpAddress_ != address(0) && feedToken_ != address(0x0),
            "Invalid address"
        );
        require(isValidBase(feedToken_), "Invalid feed token");
        require(
            startBlock_ > block.number && endBlock_ > startBlock_,
            "Blocks invalids"
        );
        require(rate_ >= 120 && rate_ <= 180, "Invalid rate");
        IJamonPair pair = IJamonPair(lpAddress_);
        require(
            pair.token0() == feedToken_ || pair.token1() == feedToken_,
            "Feed not on pair"
        );
        bytes32 bonusId = keccak256(
            abi.encodePacked(
                lpAddress_,
                startBlock_,
                endBlock_,
                hardcap_,
                block.timestamp
            )
        );
        Proposal storage p = BONUS[bonusId];
        p.lpAddress = lpAddress_;
        p.feedToken = feedToken_;
        p.startBlock = startBlock_;
        p.endBlock = endBlock_;
        p.hardcap = hardcap_;
        p.rate = rate_;
        BonusMap.add(bonusId);
        emit NewBonus(lpAddress_, bonusId);
        return bonusId;
    }

    /**
     * @notice Add a new price query feed with the Chainlink aggregator.
     * @param token_ address of token for query.
     * @param proxy_ address of aggregator proxy of ChainLink.
     * @param decimals_ uint256 the decimals that the returned price has.
     */
    function addFeed(
        address token_,
        address proxy_,
        uint256 decimals_
    ) external onlyOwner {
        require(
            token_ != address(0) && proxy_ != address(0),
            "Invalid address"
        );
        require(decimals_ <= 18 && decimals_ > 0, "Invalid decimals");
        FEEDS[token_].proxy = proxy_;
        FEEDS[token_].decimals = decimals_;
        require(PriceFeeds.add(token_), "Add feed error");
    }

    /**
     * @notice Add a new stable coin token for query the price.
     * @param token_ address of token for query.
     */
    function addStableCoin(address token_) external onlyOwner {
        require(token_ != address(0), "Invalid address");
        require(StableCoins.add(token_), "Add token error");
    }

    /**
     * @notice Remove bonus.
     * @param bonusId_ id of the bonus.
     */
    function removeBonus(bytes32 bonusId_) external onlyOwner {
        require(BonusMap.contains(bonusId_), "Invalid ID");
        require(!isBonusOpen(bonusId_), "Bonus is open");
        delete BONUS[bonusId_];
    }

    /**
     * @notice Functions for pause and unpause the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity =0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IJamonSharePresale.sol";
import "./interfaces/IJamonShareVesting.sol";
import "./interfaces/IConversor.sol";
import "./interfaces/IJamonPair.sol";
import "./interfaces/IERC20MintBurn.sol";

/**
 * @title JamonSharePresale
 * @notice This contract will distribute the JamonShare tokens based on the new liquidity provided based on the value in USD for a ratio of 3 rounds.
 * It also allows you to contribute the JamonV2 token, blocking it for 12 months and receiving JamonShare.
 * Round 1 = 2 JamonV2 and 1 JamonShare for 1 USD aported.
 * Round 1 = 1.8 JamonV2 and 1 JamonShare for 1 USD aported.
 * Round 1 = 1.6 JamonV2 and 1 JamonShare for 1 USD aported.
 * Jamon vested = 1.1 JamonV2 and 1.5 JamonShare for 1 USD aported at price 0.0113387 USD of old Jamon.
 */
contract JamonSharePresale is
    IJamonSharePresale,
    ReentrancyGuard,
    Pausable,
    Ownable
{
    //---------- Libraries ----------//
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    //---------- Contracts ----------//
    AggregatorV3Interface private maticFeed; // ChainLink aggregator MATIC/USD.
    IJamonShareVesting private RewardVesting; // JamonShare vesting contract.
    IConversor private Conversor; // Conversor V1 to V2 contract.

    //---------- Variables ----------//
    EnumerableSet.AddressSet private WhitelistLP; // List of wallets allowed for this pre-sale.
    uint256 public constant max4list = 1400 ether; // 1400 USD per user in whitelist. 
    address private Governor; // Address of Governor contract for send a liquidity.
    bool public listActive; // If the whitelist is active.
    uint256 private constant roundHardcap = 350000 ether; // The maximum amount per round allowed in USD.

    //---------- Storage -----------//
    struct TokensContracts {
        // WMATIC token contract.
        IERC20 WMATIC;
        // USDC token contract.
        IERC20 USDC;
        // New Jamon token contract.
        IERC20MintBurn JAMON_V2;
        // New pair MATIC/JAMONV2 contract.
        IJamonPair MATIC_LP;
        // New pair YSDC/JAMONV2 contract.
        IJamonPair USDC_LP;
    }

    struct Round {
        // Date in timestamp of the end of round.
        uint256 endTime;
        // Total amount collected of the round in wei.
        uint256 collected;
    }

    TokensContracts internal CONTRACTS; // Struct of the contracts necessary for the operation
    Round[3] public ROUNDS; // Array of 3 rounds.
    mapping(address => uint256) public Max4Wallet; // Maximum quantity allowed for pre-sale blocking JamonV2.
    mapping(address => uint256) public Spended; // Amount contributed by wallet for the limit of round 1
    mapping(address => uint256) public JamonSpended; // Amount contributed by wallet for the limit of JamonV2 blocking  

    //---------- Events -----------//
    event Contributed(
        address indexed lp,
        address indexed wallet,
        uint256 rewardJV2,
        uint256 rewardJS
    );

    //---------- Constructor ----------//
    constructor(address jamon_, address conversor_) {
        /**
         * Network: Polygon
         ------------------------------
         * Aggregator: MATIC/USD
         * Address: 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
         * Decimals: 8
         */
        maticFeed = AggregatorV3Interface(
            0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
        );
        CONTRACTS.JAMON_V2 = IERC20MintBurn(jamon_);
        Conversor = IConversor(conversor_);
        listActive = true;
    }

    function initialize(
        address wmatic_,
        address usdc_,
        address maticlpV2_,
        address usdclpV2_,
        address rewardVesting_,
        address governor_
    ) external onlyOwner {
        require(
            address(CONTRACTS.WMATIC) == address(0x0),
            "Already initialized"
        );
        CONTRACTS.WMATIC = IERC20(wmatic_);
        CONTRACTS.USDC = IERC20(usdc_);
        CONTRACTS.MATIC_LP = IJamonPair(maticlpV2_);
        CONTRACTS.USDC_LP = IJamonPair(usdclpV2_);
        RewardVesting = IJamonShareVesting(rewardVesting_);
        Governor = governor_;
        uint256 startAt = Conversor.endTime();
        ROUNDS[0].endTime = startAt.add(10 days); 
        ROUNDS[1].endTime = startAt.add(20 days); 
        ROUNDS[2].endTime = startAt.add(30 days); 
    }

    //----------- Internal Functions -----------//
    /**
     * @dev Take the price of JamonV2 compared to USD.
     * @param usdAmount_ amount in USD for query.
     * @return the price of token in ether
     */
    function _getUSD2Jamon(uint256 usdAmount_) internal view returns (uint256) {
        IJamonPair pair = IJamonPair(CONTRACTS.USDC_LP);
        address token0 = pair.token0();
        (uint256 Res0, uint256 Res1, ) = pair.getReserves();
        uint256 price;
        if (address(CONTRACTS.USDC) == token0) {
            Res0 = Res0 * (1e12); // USDC 6 decimals, 6 + 12
            price = ((usdAmount_ * Res1) / Res0);
        } else {
            Res1 = Res1 * (1e12); // USDC 6 decimals, 6 + 12
            price = ((usdAmount_ * Res0) / Res1);
        }
        return price; // return amount of token0 needed to buy token1
    }

    /**
     * @dev Take the price of MATIC compared to USD.
     * @return the price of MATIC in ether.
     */
    function _getMaticPrice() internal view returns (uint256) {
        (, int256 price, , , ) = maticFeed.latestRoundData();
        return uint256(price * 1e10); // Return price with 18 decimals, 8 + 10.
    }

    //----------- External Functions -----------//
    /**
     * @dev Check when the presale ends.
     * @return The date in completion timestamp.
     */
    function endsAt() external view returns (uint256) {
        return ROUNDS[2].endTime;
    }

    /**
     * @dev Check when the presale ends.
     * @return The date in completion timestamp.
     */
    function endsJamonAt() public view returns (uint256) {
        return ROUNDS[2].endTime.add(10 days); 
    }

    /**
     * @dev Check when if limit in whitelist is actived.
     * @return If limit is active or not.
     */
    function listLimit() public view returns (bool) {
        return Conversor.endTime().add(1 days) > block.timestamp;
    }

    /**
     * @dev Check if a wallet is whitelisted.
     * @param wallet_ Address to check.
     * @return Whether it's on the list or not.
     */
    function isOnWhitelist(address wallet_) external view returns (bool) {
        return WhitelistLP.contains(wallet_);
    }

    /**
     * @dev Check pre sale status.
     * @return round the current round.
     * @return rate the current rate.
     */
    function status()
        public
        view
        override
        returns (uint256 round, uint256 rate)
    {
        if (ROUNDS[0].endTime < block.timestamp) {
            if (ROUNDS[1].endTime < block.timestamp) {
                if (ROUNDS[2].endTime < block.timestamp) {
                    return (4, 0);
                }
                return (3, 160);
            }
            return (2, 180);
        }
        if (Conversor.endTime() < block.timestamp) {
            return (1, 200);
        }
        return (0, 0);
    }

    /**
     * @notice Calculate the remaining amount on sale.
     * @param lp_ Address of the LP token to query.
     * @param round_ Round for query.
     * @return The amount of LP available to sale.
     */
    function remaining4Sale(
        address wallet_,
        address lp_,
        uint256 round_ 
    ) public view returns (uint256) {
        uint256 remaining;
        uint256 available;
        if (round_ == 1) {
            available = roundHardcap.sub(ROUNDS[0].collected);
            if (listLimit()) {
                uint256 userRemaining = max4list.sub(Spended[wallet_]);
                available = userRemaining > available
                    ? available
                    : userRemaining;
            }
        }
        if (round_ == 2) {
            available = roundHardcap.sub(ROUNDS[1].collected);
        }
        if (round_ == 3) {
            available = roundHardcap.sub(ROUNDS[2].collected);
        }
        if (lp_ == address(CONTRACTS.MATIC_LP)) {
            if (available > 0) {
                uint256 matics = (available.div(2).mul(1e18)).div(
                    _getMaticPrice()
                );
                uint256 totalMatic = CONTRACTS.WMATIC.balanceOf(
                    address(CONTRACTS.MATIC_LP)
                );
                uint256 totalSupply = CONTRACTS.MATIC_LP.totalSupply();
                uint256 percentage = matics.mul(10e18).div(totalMatic);
                remaining = percentage.mul(totalSupply).div(10e18);
            }
        }
        if (lp_ == address(CONTRACTS.USDC_LP)) {
            if (available > 0) {
                uint256 usdc = available.div(2);
                uint256 totalUSDC = CONTRACTS.USDC.balanceOf(
                    address(CONTRACTS.USDC_LP)
                );
                uint256 totalSupply = CONTRACTS.USDC_LP.totalSupply();
                uint256 percentage = usdc.mul(10e18).div(totalUSDC.mul(1e12));
                remaining = percentage.mul(totalSupply).div(10e18);
            }
        }
        return remaining;
    }

    /**
     * @notice Calculate the reward to receive based on the contributed MATIC/JAMONV2 lp tokens.
     * @param amount_ Amount of the LP token to query.
     * @return usd_in value in USD contributed.
     * @return jamon_out Jamon V2 tokens to be received.
     */
    function getRewardMaticLP(uint256 amount_)
        public
        view
        returns (uint256 usd_in, uint256 jamon_out)
    {
        uint256 totalSupply = CONTRACTS.MATIC_LP.totalSupply();
        uint256 totalMatic = CONTRACTS.WMATIC.balanceOf(
            address(CONTRACTS.MATIC_LP)
        );
        uint256 totalUSD = (totalMatic.mul(2).mul(_getMaticPrice())).div(10e18);
        uint256 percentage = amount_.mul(10e18).div(totalSupply);
        uint256 contributed = percentage.mul(totalUSD).div(10e18);
        uint256 amountJamon = _getUSD2Jamon(contributed);
        return (contributed, amountJamon);
    }

    /**
     * @notice Calculate the reward to receive based on the contributed USDC/JAMONV2 lp tokens.
     * @param amount_ Amount of the LP token to query.
     * @return usd_in value in USD contributed.
     * @return jamon_out Jamon V2 tokens to be received.
     */
    function getRewardUSDCLP(uint256 amount_)
        public
        view
        returns (uint256 usd_in, uint256 jamon_out)
    {
        uint256 totalSupply = CONTRACTS.USDC_LP.totalSupply();
        uint256 totalUSDC = CONTRACTS
            .USDC
            .balanceOf(address(CONTRACTS.USDC_LP))
            .mul(1e12);
        uint256 totalUSD = totalUSDC.mul(2);
        uint256 percentage = amount_.mul(10e18).div(totalSupply);
        uint256 contributed = percentage.mul(totalUSD).div(10e18);
        uint256 amountJamon = _getUSD2Jamon(contributed);
        return (contributed, amountJamon);
    }

    /**
     * @notice Contribute MATIC/JAMONV2 lp tokens to receive a reward in JamonV2 + JamonShare locked for 12 months.
     * @param amount_ Amount of the LP token to contribute.
     * @return jamonReward amount of JamonV2 token to receive in 12 months.
     * @return jsnow JamonShare tokens to receive at the time of contribution.
     * @return jsend JamonShare tokens to be received at the end of distribution time (12 months).
     */
    function contributeMaticLP(uint256 amount_)
        external
        whenNotPaused
        nonReentrant
        returns (
            uint256 jamonReward,
            uint256 jsnow,
            uint256 jsend
        )
    {
        require(amount_ > 0, "Invalid amount");
        (uint256 round, uint256 rate) = status();
        require(round > 0 && round < 4, "Not on sale");
        if (round == 1 && listActive) {
            require(WhitelistLP.contains(_msgSender()), "Wallet not allowed");
        }
        require(
            CONTRACTS.MATIC_LP.allowance(_msgSender(), address(this)) >=
                amount_,
            "LP not allowed"
        );
        uint256 allowed = remaining4Sale(
            _msgSender(),
            address(CONTRACTS.MATIC_LP),
            round
        );
        uint256 amount = amount_ > allowed ? allowed : amount_;
        (uint256 contributed, uint256 reward) = getRewardMaticLP(amount);
        reward = reward.mul(rate).div(100);
        require(reward >= 600, "Reward too low");
        require(
            CONTRACTS.MATIC_LP.transferFrom(_msgSender(), Governor, amount),
            "Transfer LP error"
        );
        uint256 rewardMonth = reward.div(12);
        uint256 JSnow = rewardMonth.div(50);
        uint256 JSend = contributed.sub(JSnow);
        ROUNDS[round.sub(1)].collected += contributed;
        Spended[_msgSender()] += contributed; 
        RewardVesting.createVesting(_msgSender(), JSnow, JSend);
        emit Contributed(
            address(CONTRACTS.MATIC_LP),
            _msgSender(),
            reward,
            contributed
        );
        return (reward, JSnow, JSend);
    }

    /**
     * @notice Contribute USDC/JAMONV2 lp tokens to receive a reward in JamonV2 + JamonShare locked for 12 months.
     * @param amount_ Amount of the LP token to contribute.
     * @return jamonReward amount of JamonV2 token to receive in 12 months.
     * @return jsnow JamonShare tokens to receive at the time of contribution.
     * @return jsend JamonShare tokens to be received at the end of distribution time (12 months).
     */
    function contributeUSDCLP(uint256 amount_)
        external
        whenNotPaused
        nonReentrant
        returns (
            uint256 jamonReward,
            uint256 jsnow,
            uint256 jsend
        )
    {
        require(amount_ > 0, "Invalid amount");
        (uint256 round, uint256 rate) = status();
        require(round > 0 && round < 4, "Not on sale");
        if (round == 1 && listActive) {
            require(WhitelistLP.contains(_msgSender()), "Wallet not allowed");
        }
        require(
            CONTRACTS.USDC_LP.allowance(_msgSender(), address(this)) >= amount_,
            "LP not allowed"
        );
        uint256 allowed = remaining4Sale(
            _msgSender(),
            address(CONTRACTS.USDC_LP),
            round
        );
        uint256 amount = amount_ > allowed ? allowed : amount_;
        (uint256 contributed, uint256 reward) = getRewardUSDCLP(amount);
        reward = reward.mul(rate).div(100);
        require(reward >= 600, "Reward too low");
        require(
            CONTRACTS.USDC_LP.transferFrom(_msgSender(), Governor, amount),
            "Transfer LP error"
        );
        uint256 rewardMonth = reward.div(12);
        uint256 JSnow = rewardMonth.div(50);
        uint256 JSend = contributed.sub(JSnow);
        ROUNDS[round.sub(1)].collected += contributed;
        Spended[_msgSender()] += contributed; 
        RewardVesting.createVesting(_msgSender(), JSnow, JSend);
        emit Contributed(
            address(CONTRACTS.USDC_LP),
            _msgSender(),
            reward,
            contributed
        );
        return (reward, JSnow, JSend);
    }

    /**
     * @notice Contribute JamonV2 tokens to receive a reward in JamonV2 + JamonShare locked for 12 months.
     * @param amount_ Amount of JamonV2 token to block in 12 months.
     * @return jamonReward amount of JamonV2 token to receive in 12 months.
     * @return jsnow JamonShare tokens to receive at the time of contribution.
     * @return jsend JamonShare tokens to be received at the end of distribution time (12 months).
     */
    function contributeJamon(uint256 amount_)
        external
        whenNotPaused
        nonReentrant
        returns (
            uint256 jamonReward,
            uint256 jsnow,
            uint256 jsend
        )
    {
        require(amount_ > 0, "Invalid amount");
        (uint256 round, ) = status();
        require(round == 4 && endsJamonAt() > block.timestamp, "Lock not live");
        require(
            Max4Wallet[_msgSender()].sub(JamonSpended[_msgSender()]) >= amount_,
            "Amount not allowed"
        );
        require(
            CONTRACTS.JAMON_V2.allowance(_msgSender(), address(this)) >=
                amount_,
            "Jamon not allowed"
        );
        uint256 aportedUSD = amount_.mul(11338700000000000).div(1 ether);
        uint256 contributed = aportedUSD.mul(150).div(100);
        uint256 reward = amount_.mul(110).div(100);
        require(reward >= 600 && contributed > 0, "Reward too low");
        uint256 rewardMonth = reward.div(12);
        uint256 JSnow = rewardMonth.div(50);
        uint256 JSend = contributed.sub(JSnow);
        JamonSpended[_msgSender()] += amount_; 
        CONTRACTS.JAMON_V2.burnFrom(_msgSender(), amount_);
        RewardVesting.createVesting(_msgSender(), JSnow, JSend);
        emit Contributed(
            address(CONTRACTS.JAMON_V2),
            _msgSender(),
            reward,
            contributed
        );
        return (reward, JSnow, JSend);
    }

    /**
     * @notice Show the total of wallets in the white list.
     * @return The total of wallets in the white list.
     */
    function whitelistCount() external view returns (uint256) {
        return WhitelistLP.length();
    }

    /**
     * @notice Allows enable or disable the white list of LP.
     * @param set_ Boolean to define if it is active or not.
     */
    function setWhitelist(bool set_) external onlyOwner {
        listActive = set_;
    }

    /**
     * @notice Allows edit the white list of LP.
     * @param users_ Address of the wallets to edit.
     * @param add_ Boolean to define if add or remove wallet on white list.
     */
    function editWhitelistLP(address[] memory users_, bool add_)
        external
        onlyOwner
    {
        if (add_) {
            for (uint256 i = 0; i < users_.length; i++) {
                WhitelistLP.add(users_[i]);
            }
        } else {
            for (uint256 i = 0; i < users_.length; i++) {
                WhitelistLP.remove(users_[i]);
            }
        }
    }

    /**
     * @notice Allows edit the white list of JamonV2.
     * @param users_ Address of the wallets to edit.
     * @param amounts_ Maximum allowed amount of contribution per wallet.
     * @param add_ Boolean to define if add or remove wallet on white list.
     */
    function editWhitelist(
        address[] memory users_,
        uint256[] memory amounts_,
        bool add_
    ) external onlyOwner {
        if (add_) {
            for (uint256 i = 0; i < users_.length; i++) {
                Max4Wallet[users_[i]] = amounts_[i];
            }
        } else {
            for (uint256 i = 0; i < users_.length; i++) {
                delete Max4Wallet[users_[i]];
            }
        }
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

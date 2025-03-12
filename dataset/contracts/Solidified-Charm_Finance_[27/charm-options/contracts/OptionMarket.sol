// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./libraries/openzeppelin/ERC20UpgradeSafe.sol";
import "./libraries/openzeppelin/OwnableUpgradeSafe.sol";
import "./libraries/openzeppelin/ReentrancyGuardUpgradeSafe.sol";
import "./libraries/UniERC20.sol";
import "./OptionMath.sol";
import "./OptionToken.sol";
import "../interfaces/IOracle.sol";

/**
 * Automated market-maker for options
 *
 * This contract allows an asset to be split up into tokenized payoffs such that
 * different combinations of payoffs sum up to different call/put option payoffs.
 * An LMSR (Hanson's market-maker) is used to provide liquidity for the tokenized
 * payoffs.
 *
 * The parameter `b` in the LMSR represents the market depth. `b` is increased when
 * users provide liquidity by depositing funds and it is decreased when they withdraw
 * liquidity. Trading fees are distributed proportionally to liquidity providers
 * at the time of the trade.
 *
 * Call and put option with any of the supported strikes are provided. Short options
 * (equivalent to owning 1 underlying + sell 1 option) are provided, which let users
 * take on short option exposure
 *
 * `buy`, `sell`, `deposit` and `withdraw` are the main methods used to interact with
 * this contract.
 *
 * After expiration, `settle` can be called to fetch the expiry price from a
 * price oracle. `buy` and `deposit` cannot be called after expiration, but `sell`
 * can be called to redeem options for their corresponding payouts and `withdraw`
 * can be called to redeem LP tokens for a stake of the remaining funds left
 * in the contract.
 *
 * Methods to calculate the LMSR cost and option payoffs can be found in `OptionMath`.
 * `OptionToken` is an ERC20 token representing a long or short option position
 * that's minted or burned when users buy or sell options.
 *
 * This contract is also an ERC20 token itself representing shares in the liquidity
 * pool.
 *
 * The intended way to deploy this contract is to call `createMarket` in `OptionFactory`
 * Then liquidity has to be provided using `deposit` before trades can occur.
 *
 * Please note that the deployer of this contract is highly privileged and has
 * permissions such as withdrawing all funds from the contract, being able to pause
 * trading, modify the market parameters and override the settlement price. These
 * permissions will be removed in future versions.
 */
contract OptionMarket is ERC20UpgradeSafe, ReentrancyGuardUpgradeSafe, OwnableUpgradeSafe {
    using Address for address;
    using SafeERC20 for IERC20;
    using UniERC20 for IERC20;
    using SafeMath for uint256;

    event Buy(
        address indexed account,
        bool isLongToken,
        uint256 strikeIndex,
        uint256 optionsOut,
        uint256 amountIn,
        uint256 newSupply
    );

    event Sell(
        address indexed account,
        bool isLongToken,
        uint256 strikeIndex,
        uint256 optionsIn,
        uint256 amountOut,
        uint256 newSupply,
        bool isSettled
    );

    event Deposit(address indexed account, uint256 sharesOut, uint256 amountIn, uint256 newSupply);
    event Withdraw(address indexed account, uint256 sharesIn, uint256 amountOut, uint256 newSupply, bool isSettled);
    event Settle(uint256 expiryPrice);

    uint256 public constant SCALE = 1e18;
    uint256 public constant SCALE_SCALE = 1e36;

    IERC20 public baseToken;
    IOracle public oracle;
    OptionToken[] public longTokens;
    OptionToken[] public shortTokens;
    uint256[] public strikePrices;
    uint256 public expiryTime;
    bool public isPut;
    uint256 public tradingFee;
    uint256 public balanceCap;
    uint256 public totalSupplyCap;
    uint256 public disputePeriod;

    bool public isPaused;
    bool public isSettled;
    uint256 public expiryPrice;

    // cache getCurrentCost and getCurrentPayoff between trades to save gas
    uint256 public lastCost;
    uint256 public lastPayoff;

    // total value of fees owed to LPs
    uint256 public poolValue;

    /**
     * @param _baseToken        Underlying asset if call. Strike currency if put
     *                          Represents ETH if equal to 0x0
     * @param _oracle           Oracle from which settlement price is obtained
     * @param _longTokens       Tokens representing long calls/puts
     * @param _shortTokens      Tokens representing short calls/puts
     * @param _strikePrices     Strike prices expressed in wei. Must be in increasing order
     * @param _expiryTime       Expiration time as a unix timestamp
     * @param _isPut            Whether this market provides calls or puts
     * @param _tradingFee       Trading fee as fraction of underlying expressed in wei
     * @param _symbol           Name and symbol of LP tokens
     */
    function initialize(
        address _baseToken,
        address _oracle,
        address[] memory _longTokens,
        address[] memory _shortTokens,
        uint256[] memory _strikePrices,
        uint256 _expiryTime,
        bool _isPut,
        uint256 _tradingFee,
        string memory _symbol
    ) public payable initializer {
        // this contract is also an ERC20 token, representing shares in the liquidity pool
        __ERC20_init(_symbol, _symbol);
        __ReentrancyGuard_init();
        __Ownable_init();

        // use same decimals as base token
        uint8 decimals = IERC20(_baseToken).isETH() ? 18 : ERC20UpgradeSafe(_baseToken).decimals();
        _setupDecimals(decimals);

        require(_longTokens.length == _strikePrices.length, "Lengths do not match");
        require(_shortTokens.length == _strikePrices.length, "Lengths do not match");

        require(_strikePrices.length > 0, "Strike prices must not be empty");
        require(_strikePrices[0] > 0, "Strike prices must be > 0");

        // check strike prices are increasing
        for (uint256 i = 0; i < _strikePrices.length - 1; i++) {
            require(_strikePrices[i] < _strikePrices[i + 1], "Strike prices must be increasing");
        }

        // check trading fee is less than 100%
        // note trading fee can be 0
        require(_tradingFee < SCALE, "Trading fee must be < 1");

        baseToken = IERC20(_baseToken);
        oracle = IOracle(_oracle);
        strikePrices = _strikePrices;
        expiryTime = _expiryTime;
        isPut = _isPut;
        tradingFee = _tradingFee;

        for (uint256 i = 0; i < _strikePrices.length; i++) {
            longTokens.push(OptionToken(_longTokens[i]));
            shortTokens.push(OptionToken(_shortTokens[i]));
        }

        require(!isExpired(), "Already expired");
    }

    /**
     * Buy options
     *
     * The option bought is specified by `isLongToken` and `strikeIndex` and the
     * amount by `optionsOut`
     *
     * This method reverts if the resulting cost is greater than `maxAmountIn`
     */
    function buy(
        bool isLongToken,
        uint256 strikeIndex,
        uint256 optionsOut,
        uint256 maxAmountIn
    ) external payable nonReentrant returns (uint256 amountIn) {
        require(totalSupply() > 0, "No liquidity");
        require(!isExpired(), "Already expired");
        require(msg.sender == owner() || !isPaused, "Paused");
        require(strikeIndex < strikePrices.length, "Index too large");
        require(optionsOut > 0, "Options out must be > 0");

        // mint options to user
        OptionToken option = isLongToken ? longTokens[strikeIndex] : shortTokens[strikeIndex];
        option.mint(msg.sender, optionsOut);

        // calculate trading fee and allocate it to the LP pool
        // like LMSR cost, fees have to be multiplied by strike price
        uint256 fee = optionsOut.mul(tradingFee);
        fee = isPut ? fee.mul(strikePrices[strikeIndex]).div(SCALE_SCALE) : fee.div(SCALE);
        poolValue = poolValue.add(fee);

        // calculate amount that needs to be paid by user to buy these options
        // it's equal to the increase in LMSR cost after minting the options
        uint256 costAfter = getCurrentCost();
        amountIn = costAfter.sub(lastCost).add(fee); // do sub first as a check since should not fail
        lastCost = costAfter;
        require(amountIn > 0, "Amount in must be > 0");
        require(amountIn <= maxAmountIn, "Max slippage exceeded");

        // transfer in amount from user
        _transferIn(amountIn);
        emit Buy(msg.sender, isLongToken, strikeIndex, optionsOut, amountIn, option.totalSupply());
    }

    /**
     * Sell options
     *
     * The option sold is specified by `isLongToken` and `strikeIndex` and the
     * amount by `optionsIn`
     *
     * This method reverts if the resulting amount returned is less than `minAmountOut`
     */
    function sell(
        bool isLongToken,
        uint256 strikeIndex,
        uint256 optionsIn,
        uint256 minAmountOut
    ) external nonReentrant returns (uint256 amountOut) {
        require(!isExpired() || isSettled, "Must be called before expiry or after settlement");
        require(!isDisputePeriod(), "Dispute period");
        require(msg.sender == owner() || !isPaused, "Paused");
        require(strikeIndex < strikePrices.length, "Index too large");
        require(optionsIn > 0, "Options in must be > 0");

        // burn user's options
        OptionToken option = isLongToken ? longTokens[strikeIndex] : shortTokens[strikeIndex];
        option.burn(msg.sender, optionsIn);

        // calculate amount that needs to be returned to user
        if (isSettled) {
            // if after settlement, amount is the option payoff
            uint256 payoffAfter = getCurrentPayoff();
            amountOut = lastPayoff.sub(payoffAfter);
            lastPayoff = payoffAfter;
        } else {
            // if before expiry, amount is the decrease in LMSR cost after burning the options
            uint256 costAfter = getCurrentCost();
            amountOut = lastCost.sub(costAfter);
            lastCost = costAfter;
        }
        require(amountOut > 0, "Amount out must be > 0");
        require(amountOut >= minAmountOut, "Max slippage exceeded");

        // transfer amount to user
        baseToken.uniTransfer(msg.sender, amountOut);
        emit Sell(msg.sender, isLongToken, strikeIndex, optionsIn, amountOut, option.totalSupply(), isSettled);
    }

    /**
     * Deposit liquidity
     *
     * `sharesOut` is the intended increase in the parameter `b`
     *
     * This method reverts if the resulting cost is greater than `maxAmountIn`
     */
    function deposit(uint256 sharesOut, uint256 maxAmountIn) external payable nonReentrant returns (uint256 amountIn) {
        require(!isExpired(), "Already expired");
        require(msg.sender == owner() || !isPaused, "Paused");
        require(sharesOut > 0, "Shares out must be > 0");

        // user needs to contribute proportional amount of fees to pool, which
        // ensures they are only earning fees generated after they have deposited
        if (totalSupply() > 0) {
            // add 1 to round up
            amountIn = poolValue.mul(sharesOut).div(totalSupply()).add(1);
            poolValue = poolValue.add(amountIn);
        }
        _mint(msg.sender, sharesOut);
        require(totalSupplyCap == 0 || totalSupply() <= totalSupplyCap, "Total supply cap exceeded");

        // need to add increase in LMSR cost after increasing b
        uint256 costAfter = getCurrentCost();
        amountIn = costAfter.sub(lastCost).add(amountIn); // do sub first as a check since should not fail
        lastCost = costAfter;
        require(amountIn > 0, "Amount in must be > 0");
        require(amountIn <= maxAmountIn, "Max slippage exceeded");

        // transfer in amount from user
        _transferIn(amountIn);
        emit Deposit(msg.sender, sharesOut, amountIn, totalSupply());
    }

    /**
     * Withdraw liquidity
     *
     * `sharesIn` is the intended decrease in the parameter `b`
     *
     * This method reverts if the resulting amount returned is less than `minAmountOut`
     */
    function withdraw(uint256 sharesIn, uint256 minAmountOut) external nonReentrant returns (uint256 amountOut) {
        require(!isExpired() || isSettled, "Must be called before expiry or after settlement");
        require(!isDisputePeriod(), "Dispute period");
        require(msg.sender == owner() || !isPaused, "Paused");
        require(sharesIn > 0, "Shares in must be > 0");

        // calculate cut of fees earned by user
        amountOut = poolValue.mul(sharesIn).div(totalSupply());
        poolValue = poolValue.sub(amountOut);
        _burn(msg.sender, sharesIn);

        // if before expiry, add decrease in LMSR cost after decreasing b
        if (!isSettled) {
            uint256 costAfter = getCurrentCost();
            amountOut = lastCost.sub(costAfter).add(amountOut); // do sub first as a check since should not fail
            lastCost = costAfter;
        }
        require(amountOut > 0, "Amount out must be > 0");
        require(amountOut >= minAmountOut, "Max slippage exceeded");

        // return amount to user
        baseToken.uniTransfer(msg.sender, amountOut);
        emit Withdraw(msg.sender, sharesIn, amountOut, totalSupply(), isSettled);
    }

    /**
     * Retrieve and store the underlying price from the oracle
     *
     * This method can be called by anyone after expiration but cannot be called
     * more than once. In practice it should be called as soon as possible after the
     * expiration time.
     */
    function settle() external nonReentrant {
        require(isExpired(), "Cannot be called before expiry");
        require(!isSettled, "Already settled");

        // fetch expiry price from oracle
        isSettled = true;
        expiryPrice = oracle.getPrice();
        require(expiryPrice > 0, "Price from oracle must be > 0");

        // update cached payoff and pool value
        lastPayoff = getCurrentPayoff();
        poolValue = baseToken.uniBalanceOf(address(this)).sub(lastPayoff);
        emit Settle(expiryPrice);
    }

    /**
     * Calculate LMSR cost
     *
     * Represents total amount locked in the LMSR
     *
     * This value will increase as options are bought and decrease as options
     * are sold. The change in value corresponds to the total cost of a purchase
     * or the amount returned from a sale.
     *
     * This method is only used before expiry. Before expiry, the `baseToken`
     * balance of this contract is always at least current cost + pool value.
     * Current cost is maximum possible amount that needs to be paid out to
     * option holders. Pool value is the fees earned by LPs.
     */
    function getCurrentCost() public view returns (uint256) {
        uint256[] memory longSupplies = getTotalSupplies(longTokens);
        uint256[] memory shortSupplies = getTotalSupplies(shortTokens);
        uint256[] memory quantities = OptionMath.calcQuantities(strikePrices, isPut, longSupplies, shortSupplies);
        return OptionMath.calcLmsrCost(quantities, totalSupply());
    }

    /**
     * Calculate option payoff
     *
     * Represents total payoff to option holders
     *
     * This value will decrease as options are redeemed. The change in value
     * corresponds to the payoff returned from a redemption.
     *
     * This method is only used after expiry. After expiry, the `baseToken` balance
     * of this contract is always at least current payoff + pool value. Current
     * payoff is the amount owed to option holders and pool value is the amount
     * owed to LPs.
     */
    function getCurrentPayoff() public view returns (uint256) {
        uint256[] memory longSupplies = getTotalSupplies(longTokens);
        uint256[] memory shortSupplies = getTotalSupplies(shortTokens);
        return OptionMath.calcPayoff(strikePrices, expiryPrice, isPut, longSupplies, shortSupplies);
    }

    function getTotalSupplies(OptionToken[] memory optionTokens) public view returns (uint256[] memory totalSupplies) {
        totalSupplies = new uint256[](optionTokens.length);
        for (uint256 i = 0; i < optionTokens.length; i++) {
            totalSupplies[i] = optionTokens[i].totalSupply();
        }
    }

    function isExpired() public view returns (bool) {
        return block.timestamp >= expiryTime;
    }

    function isDisputePeriod() public view returns (bool) {
        return block.timestamp >= expiryTime && block.timestamp < expiryTime.add(disputePeriod);
    }

    function numStrikes() external view returns (uint256) {
        return strikePrices.length;
    }

    /**
     * Transfer amount from sender and do additional checks
     */
    function _transferIn(uint256 amountIn) private {
        // save gas
        IERC20 _baseToken = baseToken;
        uint256 balanceBefore = _baseToken.uniBalanceOf(address(this));
        _baseToken.uniTransferFromSenderToThis(amountIn);
        uint256 balanceAfter = _baseToken.uniBalanceOf(address(this));
        require(_baseToken.isETH() || balanceAfter.sub(balanceBefore) == amountIn, "Deflationary tokens not supported");
        require(balanceCap == 0 || _baseToken.uniBalanceOf(address(this)) <= balanceCap, "Balance cap exceeded");
    }

    // used for guarded launch
    function setBalanceCap(uint256 _balanceCap) external onlyOwner {
        balanceCap = _balanceCap;
    }

    // used for guarded launch
    function setTotalSupplyCap(uint256 _totalSupplyCap) external onlyOwner {
        totalSupplyCap = _totalSupplyCap;
    }

    // emergency use only. to be removed in future versions
    function pause() external onlyOwner {
        isPaused = true;
    }

    // emergency use only. to be removed in future versions
    function unpause() external onlyOwner {
        isPaused = false;
    }

    // emergency use only. to be removed in future versions
    function setOracle(IOracle _oracle) external onlyOwner {
        oracle = _oracle;
    }

    // emergency use only. to be removed in future versions
    function setExpiryTime(uint256 _expiryTime) external onlyOwner {
        expiryTime = _expiryTime;
    }

    // emergency use only. to be removed in future versions
    function setDisputePeriod(uint256 _disputePeriod) external onlyOwner {
        disputePeriod = _disputePeriod;
    }

    // emergency use only. to be removed in future versions
    function disputeExpiryPrice(uint256 _expiryPrice) external onlyOwner {
        require(isDisputePeriod(), "Not dispute period");
        require(isSettled, "Cannot be called before settlement");
        expiryPrice = _expiryPrice;

        // update cached payoff and pool value
        lastPayoff = getCurrentPayoff();
        poolValue = baseToken.uniBalanceOf(address(this)).sub(lastPayoff);
        emit Settle(_expiryPrice);
    }

    // emergency use only. to be removed in future versions
    function emergencyWithdraw() external onlyOwner {
        baseToken.uniTransfer(msg.sender, baseToken.uniBalanceOf(address(this)));
    }
}

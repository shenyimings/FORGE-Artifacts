// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../libraries/UniERC20.sol";
import "../OptionMarket.sol";
import "../OptionToken.sol";
import "./OptionViews.sol";


contract OptionLpVault is Ownable, ReentrancyGuard, ERC20 {
    using Address for address;
    using SafeERC20 for IERC20;
    using UniERC20 for IERC20;
    using SafeMath for uint256;

    address public manager;
    IERC20 public baseToken;
    OptionViews public optionViewsLibrary;

    mapping(OptionMarket => bool) public marketAdded;
    OptionMarket[] public markets;

    uint256 public totalAssets;
    uint256 public totalSupplyCap;
    uint256 public depositFee;
    uint256 public cooldown;

    mapping(address => uint256) public lastDeposit;
    bool public paused;
    bool public finalized;

    constructor(
        address _baseToken,
        address _optionViewsLibrary,
        string memory name,
        string memory symbol
    ) public ERC20(name, symbol) {
        manager = msg.sender;
        baseToken = IERC20(_baseToken);
        optionViewsLibrary = OptionViews(_optionViewsLibrary);

        // use same decimals as base token
        uint8 decimals = IERC20(_baseToken).isETH() ? 18 : ERC20UpgradeSafe(_baseToken).decimals();
        _setupDecimals(decimals);
    }

    /**
     * Deposit base tokens
     */
    function deposit(uint256 amount, address recipient) external payable nonReentrant returns (uint256 shares) {
        require(!paused, "Paused");
        shares = totalAssets > 0 ? amount.mul(totalSupply()).div(totalAssets) : amount;
        shares = shares.sub(shares.mul(depositFee).div(1e18));
        totalAssets = totalAssets.add(amount);

        lastDeposit[msg.sender] = block.timestamp;
        baseToken.uniTransferFromSenderToThis(amount);
        _mint(recipient, shares);

        if (totalSupplyCap > 0) {
            require(totalSupply() <= totalSupplyCap, "Total supply cap exceeded");
        }
    }

    /**
     * Withdraw base tokens
     */
    function withdraw(uint256 shares, address recipient) external nonReentrant returns (uint256 amount) {
        require(!paused, "Paused");
        require(block.timestamp > lastDeposit[msg.sender].add(cooldown), "Cooldown");

        amount = shares.mul(totalAssets).div(totalSupply());
        require(amount <= baseToken.uniBalanceOf(address(this)), "Not enough free balance in vault");

        totalAssets = totalAssets.sub(amount);
        _burn(msg.sender, shares);
        baseToken.uniTransfer(payable(recipient), amount);
    }

    function withdrawTokens(uint256 sharesIn, address recipient) external nonReentrant {
        require(!paused, "Paused");
        _withdrawToken(baseToken, sharesIn, recipient);
        for (uint256 i = 0; i < markets.length; i = i.add(1)) {
            OptionMarket market = markets[i];
            for (uint256 j = 0; j < market.numStrikes(); j = j.add(1)) {
                OptionToken longToken = market.longTokens(j);
                OptionToken shortToken = market.shortTokens(j);
                _withdrawToken(longToken, sharesIn, recipient);
                _withdrawToken(shortToken, sharesIn, recipient);
            }
            _withdrawToken(market, sharesIn, recipient);
        }

        totalAssets = estimatedTotalAssets();
        _burn(msg.sender, sharesIn);
    }

    function _withdrawToken(IERC20 token, uint256 sharesIn, address recipient) internal returns (uint256) {
        uint256 balance = token.uniBalanceOf(address(this));
        if (balance > 0) {
            uint256 amount = balance.mul(sharesIn).div(totalSupply());
            token.uniTransfer(payable(recipient), amount);
        }
    }

    /**
     * Convert vault's base tokens to options and lp tokens
     *
     * The total value of assets held by vault should stay the same. Can only be called by manager
     */
    function buy(
        OptionMarket market,
        uint256[] memory longOptionsOut,
        uint256[] memory shortOptionsOut,
        uint256 lpSharesOut,
        uint256 maxAmountIn
    ) external nonReentrant returns (uint256 amountIn) {
        require(msg.sender == manager, "!manager");
        require(marketAdded[market], "Market not found");

        uint256 balanceBefore = baseToken.uniBalanceOf(address(this));
        if (lpSharesOut > 0) {
            uint256 balance = baseToken.uniBalanceOf(address(this));
            uint256 value = baseToken.isETH() ? balance : 0;
            market.deposit{value: value}(lpSharesOut, balance);
        }

        for (uint256 i = 0; i < market.numStrikes(); i = i.add(1)) {
            if (longOptionsOut[i] > 0) {
                uint256 balance = baseToken.uniBalanceOf(address(this));
                uint256 value = baseToken.isETH() ? balance : 0;
                market.buy{value: value}(true, i, longOptionsOut[i], balance);
            }
            if (shortOptionsOut[i] > 0) {
                uint256 balance = baseToken.uniBalanceOf(address(this));
                uint256 value = baseToken.isETH() ? balance : 0;
                market.buy{value: value}(false, i, shortOptionsOut[i], balance);
            }
        }

        uint256 balanceAfter = baseToken.uniBalanceOf(address(this));
        amountIn = balanceBefore.sub(balanceAfter);
        require(amountIn <= maxAmountIn, "Max slippage exceeded");
    }

    /**
     * Convert vault's options and lp tokens back to base tokens
     *
     * The total value of assets held by vault should stay the same. Can only be called by manager
     */
    function sell(
        OptionMarket market,
        uint256[] memory longOptionsIn,
        uint256[] memory shortOptionsIn,
        uint256 lpSharesIn,
        uint256 minAmountOut
    ) public nonReentrant returns (uint256 amountOut) {
        require(msg.sender == manager, "!manager");
        require(marketAdded[market], "Market not found");

        uint256 balanceBefore = baseToken.uniBalanceOf(address(this));
        for (uint256 i = 0; i < market.numStrikes(); i = i.add(1)) {
            if (longOptionsIn[i] > 0) {
                market.sell(true, i, longOptionsIn[i], 0);
            }
            if (shortOptionsIn[i] > 0) {
                market.sell(false, i, shortOptionsIn[i], 0);
            }
        }

        if (lpSharesIn > 0) {
            market.withdraw(lpSharesIn, 0);
        }

        uint256 balanceAfter = baseToken.uniBalanceOf(address(this));
        amountOut = balanceAfter.sub(balanceBefore);
        require(amountOut >= minAmountOut, "Max slippage exceeded");
    }

    /**
     * Get value of vault holdings if all options and lp tokens were sold back
     * into base tokens
     */
    function estimatedTotalAssets() public view returns (uint256 total) {
        for (uint256 i = 0; i < markets.length; i = i.add(1)) {
            OptionMarket market = markets[i];

            uint256 n = market.numStrikes();
            uint256[] memory longBalances = new uint256[](n);
            uint256[] memory shortBalances = new uint256[](n);

            for (uint256 j = 0; j < n; j = j.add(1)) {
                longBalances[j] = market.longTokens(j).balanceOf(address(this)).div(1000);
                shortBalances[j] = market.shortTokens(j).balanceOf(address(this)).div(1000);
            }

            uint256 sellCost = optionViewsLibrary.getSellCost(
                market,
                longBalances,
                shortBalances,
                market.balanceOf(address(this)).div(1000)
            );
            total = total.add(sellCost);
        }
        total = total.mul(1000);
        total = total.add(baseToken.uniBalanceOf(address(this)));
    }

    function updateTotalAssets() external {
        totalAssets = estimatedTotalAssets();
    }

    function addMarket(OptionMarket market) external {
        require(msg.sender == manager, "!manager");
        require(!marketAdded[market], "Already added");
        require(market.baseToken() == baseToken, "Base tokens don't match");
        if (!baseToken.isETH()) {
            baseToken.approve(address(market), uint256(-1));
        }
        markets.push(market);
        marketAdded[market] = true;
    }

    function removeMarket(OptionMarket market) external {
        require(msg.sender == manager, "!manager");
        require(marketAdded[market], "Market not found");
        marketAdded[market] = false;

        bool found;
        uint256 n = markets.length;
        for (uint256 i = 0; i < n; i = i.add(1)) {
            if (markets[i] == market) {
                found = true;
            } else if (found) {
                markets[i.sub(1)] = markets[i];
            }
        }
        assert(found);
        markets.pop();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(block.timestamp > lastDeposit[from].add(cooldown), "Cooldown");
    }

    function numMarkets() external view returns (uint256) {
        return markets.length;
    }

    function setManager(address _manager) external onlyOwner {
        manager = _manager;
    }

    function setDepositFee(uint256 _depositFee) external onlyOwner {
        depositFee = _depositFee;
    }

    function setCooldown(uint256 _cooldown) external onlyOwner {
        cooldown = _cooldown;
    }

    // used for guarded launch
    function setTotalSupplyCap(uint256 _totalSupplyCap) external onlyOwner {
        totalSupplyCap = _totalSupplyCap;
    }

    function setOptionViewsLibrary(address _optionViewsLibrary) external onlyOwner {
        optionViewsLibrary = OptionViews(_optionViewsLibrary);
    }

    function finalize() external onlyOwner {
        finalized = true;
    }

    function pause() external onlyOwner {
        require(!finalized, "Finalized");
        paused = true;
    }

    function unpause() external onlyOwner {
        require(!finalized, "Finalized");
        paused = false;
    }

    function emergencyWithdraw(IERC20 token, uint256 amount) external onlyOwner {
        require(!finalized, "Finalized");
        token.uniTransfer(msg.sender, amount);
    }

    receive() external payable {}
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../../libraries/TransferHelper.sol";
import "../../../libraries/TimeLock.sol";

abstract contract Liquify is ERC20, ReentrancyGuard, Ownable, TimeLock {
    using Address for address;
    using SafeMath for uint256;
    /* =====================================================================================================================
                                                        Variables
    ===================================================================================================================== */
    //Transfer Tax
    //Transfer tax rate in basis points. default 100 => 1%
    uint16 public minimumTransferTaxRate = 500;
    uint16 public maximumTransferTaxRate = 1000;
    uint16 public constant MAXIMUM_TAX = 1000;
    
    uint16 public reDistributionRate = 40;
    uint16 public devRate = 20;
    uint16 public donationRate = 10;
    
    bool public isLiquifyActive = false;
    
    uint256 public _minAmountToLiquify = 100000 ether;
    
    address public _devWallet = 0x2EA9CA0ca8043575f2189CFF9897B575b0c7e857;          //Wallet where the dev fees will go to
    address public _donationWallet = 0xA7C08AEdCe8caDC3bFb622bd7B651993d1cd24e4;     //Wallet where donation fees will go to
    address public _rewardWallet = 0x2EA9CA0ca8043575f2189CFF9897B575b0c7e857;     //Wallet where rewards will be distributed
    
    address public _liquidityPair;
    
    IUniswapV2Router02 public _router;
    
    mapping(address => bool) public _excludedFromFeesAsSender;
    mapping(address => bool) public _excludedFromFeesAsReceiver;
    
    /* =====================================================================================================================
                                                        Events
    ===================================================================================================================== */
    event MinimumTransferTaxRateUpdated(address indexed caller, uint256 previousRate, uint256 newRate);
    event MaximumTransferTaxRateUpdated(address indexed caller, uint256 previousRate, uint256 newRate);
    event UpdateTax(uint16 redistribution, uint16 dev, uint16 donation);
    event MinAmountToLiquifyUpdated(address indexed caller, uint256 previousAmount, uint256 newAmount);
    event RouterUpdated(address indexed caller, address indexed router, address indexed pair);
    event ChangedLiquidityPair(address indexed caller, address indexed pair);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiquidity);
    
    /* =====================================================================================================================
                                                        Modifier
    ===================================================================================================================== */
    modifier taxFree {
        uint16 _minimumTransferTaxRate = minimumTransferTaxRate;
        uint16 _maximumTransferTaxRate = maximumTransferTaxRate;
        minimumTransferTaxRate = 0;
        maximumTransferTaxRate = 0;
        _;
        minimumTransferTaxRate = _minimumTransferTaxRate;
        maximumTransferTaxRate = _maximumTransferTaxRate;
    }
    
    constructor() {
        excludeFromAll(_devWallet);
        excludeFromAll(_donationWallet);
    }
    
    /* =====================================================================================================================
                                                        Set Functions
    ===================================================================================================================== */
    function setLiquidityPair(address _tokenB) public onlyMaintainerOrOwner locked("lp_pair") {
        require(_tokenB != address(0), "Liquify::setLiquidityPair: Liquidity pair can't contain zero address");
        _liquidityPair = IUniswapV2Factory(_router.factory()).getPair(address(this), _tokenB);
        if(_liquidityPair == address(0)) {
            _liquidityPair = IUniswapV2Factory(_router.factory()).createPair(address(this), _tokenB);
        }
        excludeTransferFeeAsSender(address(_liquidityPair));
        emit ChangedLiquidityPair(msg.sender, _liquidityPair);
    }
    
    function setDevWallet(address wallet) public onlyMaintainerOrOwner {
        require(wallet != address(0), "ABOAT::setDevWallet: Address can't be zero address");
        _devWallet = wallet;
        excludeFromAll(_devWallet);
    }
    
    function setDonationWallet(address wallet) public onlyMaintainerOrOwner {
        require(wallet != address(0), "ABOAT::setDonationWallet: Address can't be zero address");
        _donationWallet = wallet;
    }
    
    function setRewardWallet(address wallet) public onlyMaintainerOrOwner {
        require(wallet != address(0), "ABOAT::setRewardWallet: Address can't be zero address");
        _rewardWallet = wallet;
        excludeFromAll(_rewardWallet);
    }

    function setMinAmountToLiquify(uint256 _amount) public onlyMaintainerOrOwner {
        _minAmountToLiquify = _amount;
    }
    
    /* =====================================================================================================================
                                                    Utility Functions
    ===================================================================================================================== */ 
    function excludeFromAll(address _excludee) public onlyMaintainerOrOwner {
        _excludedFromFeesAsSender[_excludee] = true;
        _excludedFromFeesAsReceiver[_excludee] = true;
    }
    
    function excludeTransferFeeAsSender(address _excludee) public onlyMaintainerOrOwner {
        _excludedFromFeesAsSender[_excludee] = true;
    }
    
    function excludeFromFeesAsReceiver(address _excludee) public onlyMaintainerOrOwner {
        _excludedFromFeesAsReceiver[_excludee] = true;
    }
    
    function includeForAll(address _excludee) public onlyMaintainerOrOwner {
        _excludedFromFeesAsSender[_excludee] = false;
        _excludedFromFeesAsReceiver[_excludee] = false;
    }
    
    function includeTransferFeeAsSender(address _excludee) public onlyMaintainerOrOwner {
        _excludedFromFeesAsSender[_excludee] = false;
    }
    
    function includeForFeesAsReciever(address _excludee) public onlyMaintainerOrOwner {
        _excludedFromFeesAsReceiver[_excludee] = false;
    }
    
    function updateMinimumTransferTaxRate(uint16 _transferTaxRate) public onlyMaintainerOrOwner locked("min_tax") {
        require(_transferTaxRate <= maximumTransferTaxRate, "ABOAT::updateMinimumTransferTaxRate: minimumTransferTaxRate must not exceed maximumTransferTaxRate.");
        emit MinimumTransferTaxRateUpdated(msg.sender, minimumTransferTaxRate, _transferTaxRate);
        minimumTransferTaxRate = _transferTaxRate;
    }
    
    function updateMaximumTransferTaxRate(uint16 _transferTaxRate) public onlyMaintainerOrOwner locked("max_tax") {
        require(_transferTaxRate >= minimumTransferTaxRate, "ABOAT::updateMaximumTransferTaxRate: maximumTransferTaxRate must not be below minimumTransferTaxRate.");
        require(_transferTaxRate <= MAXIMUM_TAX, "ABOAT::updateMaximumTransferTaxRate: maximumTransferTaxRate must exceed MAXIMUM_TAX.");
        emit MaximumTransferTaxRateUpdated(msg.sender, minimumTransferTaxRate, _transferTaxRate);
        maximumTransferTaxRate = _transferTaxRate;
    }

    function updateTax(uint16 _redistribution, uint16 _dev, uint16 _donation) public onlyMaintainerOrOwner locked("updateTax") {
        require(_redistribution + _dev + _donation <= 100, "ABOAT::updateTax: Tax cant exceed 100 percent!");
        reDistributionRate = _redistribution;
        devRate = _dev;
        donationRate = _donation;
        emit UpdateTax(reDistributionRate, devRate, donationRate);
    }
    
    function updateRouter(address router) public onlyMaintainerOrOwner locked("router") {
        _router = IUniswapV2Router02(router);
        setLiquidityPair(_router.WETH());
        excludeTransferFeeAsSender(router);
        emit RouterUpdated(msg.sender, router, _liquidityPair);
    }
    
    /* =====================================================================================================================
                                                    Liquidity Functions
    ===================================================================================================================== */
    
    /*
    * @dev Function to swap the stored liquidity fee tokens and add them to the current liquidity pool
    */
    function swapAndLiquify() public taxFree {
        if(isLiquifyActive) {
            return;
        }
        isLiquifyActive = true;
        uint256 contractTokenBalance = balanceOf(address(this));
        if (contractTokenBalance >= _minAmountToLiquify) {
            IUniswapV2Pair pair = IUniswapV2Pair(_liquidityPair);
            uint256 devTax = _minAmountToLiquify.mul(devRate).div(100);
            uint256 donationTax = _minAmountToLiquify.mul(donationRate).div(100);
            // split the liquify amount into halves
            uint256 half = _minAmountToLiquify.sub(devTax).sub(donationTax).div(2);
            uint256 otherHalfWithTax = _minAmountToLiquify.sub(half);


            address tokenA = address(pair.token0());
            address tokenB = address(pair.token1());
            require(tokenA != tokenB, "Invalid liqudity pair: Pair can\'t contain the same token twice");
            
            bool isWeth = tokenA == _router.WETH() || tokenB == _router.WETH();
            uint256 newBalance = 0;
            if(isWeth) {
               swapAndLiquifyEth(otherHalfWithTax, half);
            } else {
                swapAndLiquifyTokens(tokenA != address(this) ? tokenA : tokenB, otherHalfWithTax, half);
            }
            emit SwapAndLiquify(otherHalfWithTax, newBalance, half);
        }
        isLiquifyActive = false;
    }
    
    function swapForEth(uint256 amount) private returns (uint256) {
        uint256 initialBalance = address(this).balance;
                
        // swap tokens for ETH
        swapTokensForEth(amount);
        
        uint256 newBalance = address(this).balance.sub(initialBalance);
        uint256 devTax = newBalance.mul(devRate).div(100);
        uint256 donationTax = newBalance.mul(donationRate).div(100);
        TransferHelper.safeTransferETH(_devWallet, devTax);
        TransferHelper.safeTransferETH(_donationWallet, donationTax);
        return address(this).balance.sub(initialBalance);
    }
    
    function swapAndLiquifyEth(uint256 half, uint256 otherHalf) private {
        uint256 newBalance = swapForEth(half);
        if(newBalance > 0) {
            addLiquidityETH(otherHalf, newBalance);
        }
    }
    
    function swapAndLiquifyTokens(address tokenB, uint256 half, uint256 otherHalf) private {
        IERC20 tokenBContract = IERC20(tokenB);
        uint256 ethAmount = swapForEth(half);
        uint256 initialBalance = tokenBContract.balanceOf(address(this));
        swapEthForTokens(ethAmount, tokenB);
        uint256 newBalance = tokenBContract.balanceOf(address(this)).sub(initialBalance);
        addLiquidity(otherHalf, newBalance, tokenB);
    }
    
    function swapEthForTokens(uint256 tokenAmount, address tokenB) private {
        address[] memory path = new address[](2);
        path[0] = _router.WETH();
        path[1] = tokenB;
        
        _router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: tokenAmount}(
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    /// @dev Swap tokens for eth
    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the Enodi pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _router.WETH();

        _approve(address(this), address(_router), tokenAmount);

        // make the swap
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }
    
    function addLiquidity(uint256 tokenAmount, uint256 otherAmount, address tokenB) internal {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(_router), tokenAmount);
        IERC20(tokenB).approve(address(_router), otherAmount);
        _router.addLiquidity(
            address(this),
            tokenB,
            tokenAmount,
            otherAmount,
            0,
            0,
            address(0),
            block.timestamp
        );
    }

    /// @dev Add liquidity
    function addLiquidityETH(uint256 tokenAmount, uint256 ethAmount) internal {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(_router), tokenAmount);

        // add the liquidity
        _router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0), //burn lp token
            block.timestamp
        );
    }
    
}
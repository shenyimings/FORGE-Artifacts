//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";

contract SOLIDBLOCK is ERC20, Ownable {

    address payable public treasury = payable(0x538a2Df2760b98C0Fc37fdE218A0A2481C1106e2);
    address payable public nftRewards = payable(0xBF177e5238B88068648F58d2292a3Ec3FB164f38);

    mapping (address => bool) public isExcludedFromFee;

    mapping (address => bool) private _isBlocked;

    uint256 public treasuryFee = 50;
    uint256 public nftRewardsFee = 10;
    uint256 public totalFee = treasuryFee + nftRewardsFee;
    uint256 public constant DENOMINATOR = 1000;

    uint256 public maxWallet;
    mapping (address => bool) public isExcludedFromMax;

    bool public tradingPaused;

    uint256 public minimumTokensBeforeSwap = 1_500* 10 ** decimals();

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool inSwap;
    bool public swapEnabled;

    event SwapEnabledUpdated(bool enabled);
    event SwapETHForTokens(uint256 amountIn, address[] path);
    event SwapTokensForETH(uint256 amountIn, address[] path);
    event ETHSentTo(uint256 amount, address wallet);

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor () ERC20("SOLIDBLOCK", "SOLID") {

        _mint(msg.sender, 1 * 10 ** 11 * 10 ** decimals());

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);//router main
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

        maxWallet = totalSupply() / 100;

        isExcludedFromMax[owner()] = true;
        isExcludedFromMax[address(this)] = true;
        isExcludedFromMax[address(treasury)] = true;
        isExcludedFromMax[address(nftRewards)] = true;
        isExcludedFromMax[address(uniswapV2Router)] = true;
        isExcludedFromMax[address(address(uniswapV2Pair))] = true;

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[address(treasury)] = true;
        isExcludedFromFee[address(nftRewards)] = true;
        isExcludedFromFee[address(uniswapV2Router)] = true;

    }

    function updateMaxWallet(uint256 newValue) public onlyOwner {
        maxWallet = newValue;
    }

    function updateTradingPaused(bool newValue) public onlyOwner {
        tradingPaused = newValue;
    }

    function updateIsExcludedFromMax(address account, bool newValue) public onlyOwner {
        isExcludedFromMax[account] = newValue;
    }

    function updateIsExcludedFromFee(address account, bool newValue) public onlyOwner {
        isExcludedFromFee[account] = newValue;
    }

    function updateIsBlocked(address account, bool newValue) public onlyOwner {
        _isBlocked[account] = newValue;
    }

    function setTaxes(uint256 newTreasury, uint256 newRewards) external onlyOwner {
        treasuryFee = newTreasury;
        nftRewardsFee = newRewards;
        totalFee = treasuryFee + nftRewardsFee;
    }

    function updateWallets(address newTreasury, address newNFTRewards) external onlyOwner {
        treasury = payable(newTreasury);
        nftRewards = payable(newNFTRewards);
    }

    function setSwapEnabled(bool _enabled) public onlyOwner {
        swapEnabled = _enabled;
        emit SwapEnabledUpdated(_enabled);
    }

    function setNumTokensBeforeSwap(uint256 newLimit) external onlyOwner {
        minimumTokensBeforeSwap = newLimit;
    }

    function updateRouter(address newRouterAddress) public onlyOwner returns(address newPairAddress) {

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(newRouterAddress);

        newPairAddress = IUniswapV2Factory(_uniswapV2Router.factory()).getPair(address(this), _uniswapV2Router.WETH());

        if(newPairAddress == address(0)) //Create If Doesnt exist
        {
            newPairAddress = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        }

        uniswapV2Pair = newPairAddress; //Set new pair address
        uniswapV2Router = _uniswapV2Router; //Set new router address
    }

    receive() external payable {}

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(!_isBlocked[sender], 'Sender is blocked');
        require(!_isBlocked[recipient], 'Recipient is blocked');
        require(!tradingPaused,'Trading paused');

        if(inSwap)
        {
            super._transfer(sender, recipient, amount);
            return;
        }
        else
        {
            uint256 contractTokenBalance = balanceOf(address(this));
            bool overMinimumTokenBalance = contractTokenBalance >= minimumTokensBeforeSwap;

            if (overMinimumTokenBalance && !inSwap && sender != uniswapV2Pair && swapEnabled)
            {
                swapAndSendToWallets(minimumTokensBeforeSwap);
            }

            if(!isExcludedFromFee[sender] && !isExcludedFromFee[recipient]) {
                uint256 feeAmount = amount * totalFee / DENOMINATOR;
                amount -= feeAmount;
                super._transfer(sender, address(this), feeAmount);
            }

            if (!isExcludedFromMax[recipient]){
                require(balanceOf(recipient) + amount <= maxWallet, 'Max holding limit');
            }

            super._transfer(sender, recipient, amount);
        }
    }

    function swapAndSendToWallets(uint256 tokens) private  lockTheSwap {
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(tokens);
        uint256 receivedETH = address(this).balance - initialBalance;

        uint256 treasuryETH = receivedETH * treasuryFee / totalFee;
        uint256 nftRewardsETH = receivedETH - treasuryETH;

        bool success;
        (success,) = address(treasury).call{value: treasuryETH}("");
        if (success) {
            emit ETHSentTo(treasuryETH, treasury);
        }
        (success,) = address(nftRewards).call{value: nftRewardsETH}("");
        if (success) {
            emit ETHSentTo(nftRewardsETH, nftRewards);
        }
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this), // The contract
            block.timestamp
        );

        emit SwapTokensForETH(tokenAmount, path);
    }

}

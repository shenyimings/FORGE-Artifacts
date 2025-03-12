// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./IUniswapV2Pair.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Router02.sol";

import "./BaseERC20.sol";

interface IStaking {
    function distribute() external payable;
}

contract Solarfare is BaseERC20 {
    mapping(address => bool) private _whitelist;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    IStaking public stakingAddress;
    address payable public charityAddress =
        payable(address(0x8B99F3660622e21f2910ECCA7fBe51d654a1517D));

    // 8% tax, 1% to Binance charity wallet, 4% to stake contract, 3% liquidated
    uint8 private constant swapPercentage = 8;
    uint256 private minSwapAmount;

    // Keep track of total swapped, total sent to charity
    uint256 public totalSwappedToBnb;
    uint256 public bnbToCharity;

    // Supply: 1 billion (10^9)
    constructor() BaseERC20("Solarfare", "SLF", 18, 10**9) {
        _balances[_msgSender()] = _totalSupply;
        // 0.001% of total supply - swap every 125k tokens transferred
        minSwapAmount = 10000 * 10**_decimals;

        // Uniswap (Kovan): 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        // PancakeSwap (Testnet): 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        // Pancakeswap (Mainnet): 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F
        IUniswapV2Router02 _uniswapV2Router =
            IUniswapV2Router02(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
            address(this),
            _uniswapV2Router.WETH()
        );

        uniswapV2Router = _uniswapV2Router;

        // Contract and owner should always be whitelisted
        _whitelist[address(this)] = true;
        _whitelist[owner()] = true;

        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    /**
     * ERC20 functions & helpers
     */

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(_balances[sender] >= amount, "ERC20: transfer amount exceeds balance");

        if (_isWhitelisted(sender, recipient)) {
            _noFeeTransfer(sender, recipient, amount);
        } else {
            _feeTransfer(sender, recipient, amount);
        }

        emit Transfer(sender, recipient, amount);
    }

    function _feeTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        _swap(sender, recipient);
        uint256 tax = (amount * swapPercentage) / 100;

        _balances[address(this)] += tax;
        _balances[sender] -= amount;
        _balances[recipient] += amount - tax;
    }

    function _noFeeTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        _balances[sender] -= amount;
        _balances[recipient] += amount;
    }

    function _isWhitelisted(address address1, address address2)
        private
        view
        returns (bool)
    {
        return _whitelist[address1] || _whitelist[address2];
    }

    /**
     * Uniswap code & distribute method
     */

    receive() external payable {}

    function _swap(address sender, address recipient) private {
        uint256 contractTokenBalance = _balances[address(this)];

        bool shouldSell = contractTokenBalance >= minSwapAmount;
        contractTokenBalance = minSwapAmount;

        if (
            shouldSell &&
            sender != uniswapV2Pair &&
            !(sender == address(this) && recipient == uniswapV2Pair)
        ) {
            uint256 stakingShare = contractTokenBalance / 2;
            uint256 charityShare = stakingShare / 4;
            uint256 liquidityShare = (75 * stakingShare) / 100;
            uint256 swapShare = stakingShare + charityShare + (liquidityShare / 2);

            swapTokensForEth(swapShare);

            // Use entire balance rather than only the BNB we swapped into;
            // everything should be distributed!
            uint256 balance = address(this).balance;
            totalSwappedToBnb += balance;

            uint256 stakingBnbShare = (5625 * balance) / 10000;
            uint256 charityBnbShare = (1875 * balance) / 10000;
            uint256 liquidityBnbShare = balance / 4;

            charityAddress.transfer(charityBnbShare);
            stakingAddress.distribute{value: stakingBnbShare}();
            bnbToCharity += charityBnbShare;

            addLiquidity(liquidityShare / 2, liquidityBnbShare);
            emit Swap(contractTokenBalance, balance);
        }
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    event Swap(uint256 tokensSwapped, uint256 ethReceived);
    event Whitelist(address whitelisted, bool isWhitelisted);
    event UpdateStakingAddress(address stakingAddress);

    /**
     * Misc. functions
     */

    function setStakingAddress(address newAddress) external onlyOwner {
        require(address(stakingAddress) == address(0), "Staking address already set");

        stakingAddress = IStaking(newAddress);
        emit UpdateStakingAddress(newAddress);
    }

    function updateWhitelist(address addr, bool isWhitelisted) external onlyOwner {
        _whitelist[addr] = isWhitelisted;
        emit Whitelist(addr, isWhitelisted);
    }
}

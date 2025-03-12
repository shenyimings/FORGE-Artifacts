//spdx-license-identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract Bannochmoor is Ownable, ERC20 {
    IUniswapV2Router02 public uniswapV2Router;

    bool private _inSwap;
    bool public swapToETH = true;
    bool public tradingEnabled;

    address public treasury;
    address public uniswapV2Pair;

    uint256 public buyTax = 600; // 600 = 6%
    uint256 public numTokensSellToETH = 1000 * 10 ** decimals();
    uint256 public sellTax = 600;
    uint256 private _supply = 1000000 * 10 ** decimals(); // 1M
    uint256 public transferTax = 0;

    mapping(address => bool) public isExcludedFromFee;

    error AmountCannotBeZero();
    error InvalidAmount();
    error MaxTaxExceeded();
    error FailedETHSend();
    error InconsistentArraysLengths();
    error InsufficientBalance();
    error TooManyRecipients();
    error TradingNotEnabled();
    error ZeroAddress();

    event ExcludeFromFee(
        address indexed owner,
        address indexed account,
        bool indexed isExcluded
    );
    event SetTaxes(
        address indexed owner,
        uint256 indexed buyTax,
        uint256 indexed sellTax,
        uint256 transferTax
    );

    modifier lockTheSwap() {
        _inSwap = true;
        _;
        _inSwap = false;
    }

    modifier NotZeroAddress(address value) {
        if (value == address(0)) revert ZeroAddress();
        _;
    }

    constructor(
        address _uniswapV2Router,
        address _treasury
    )
        ERC20("Bannochmoor", "BNR")
        NotZeroAddress(_uniswapV2Router)
        NotZeroAddress(_treasury)
    {
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
        treasury = _treasury;

        isExcludedFromFee[_uniswapV2Router] = true;
        isExcludedFromFee[_msgSender()] = true;
        isExcludedFromFee[_treasury] = true;

        //mint tokens
        _mint(_treasury, _supply);

        //create pair
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                uniswapV2Router.WETH()
            );
    }

    receive() external payable {}

    function airdrop(
        address[] calldata recipients,
        uint256[] calldata values
    ) external onlyOwner {
        if (recipients.length > 500) revert TooManyRecipients();
        if (recipients.length != values.length)
            revert InconsistentArraysLengths();
        uint256 total;
        for (uint256 i; i < values.length; ) {
            total += values[i];
            unchecked {
                ++i;
            }
        }
        if (total > balanceOf(_msgSender())) revert InsufficientBalance();
        for (uint256 i; i < recipients.length; ) {
            _transfer(_msgSender(), recipients[i], values[i]);
            unchecked {
                ++i;
            }
        }
    }

    function excludeFromFee(
        address _address,
        bool _status
    ) external onlyOwner NotZeroAddress(_address) {
        isExcludedFromFee[_address] = _status;
        emit ExcludeFromFee(_msgSender(), _address, _status);
    }

    function setNumTokensToSellToETH(uint256 _amount) external onlyOwner {
        if (_amount < 100 * 10 ** decimals()) revert InvalidAmount();
        if (_amount > 100000 * 10 ** decimals()) revert InvalidAmount();
        numTokensSellToETH = _amount;
    }

    function setSwapToETH(bool _status) external onlyOwner {
        swapToETH = _status;
    }

    function setTaxes(
        uint256 _buyTax,
        uint256 _sellTax,
        uint256 _transferTax
    ) external onlyOwner {
        if (_buyTax > 1000) revert MaxTaxExceeded();
        if (_sellTax > 1000) revert MaxTaxExceeded();
        if (_transferTax > 1000) revert MaxTaxExceeded();
        buyTax = _buyTax;
        sellTax = _sellTax;
        transferTax = _transferTax;
        emit SetTaxes(_msgSender(), _buyTax, _sellTax, _transferTax);
    }

    function setTradingEnabled() external onlyOwner {
        tradingEnabled = true;
    }

    function setTreasury(
        address value
    ) external onlyOwner NotZeroAddress(value) {
        treasury = value;
    }

    function withdrawETH() external onlyOwner {
        (bool success, ) = payable(treasury).call{value: address(this).balance}(
            ""
        );
        if (!success) revert FailedETHSend();
    }

    function withdrawTokens(
        address token
    ) external onlyOwner NotZeroAddress(token) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance == 0) revert InsufficientBalance();
        IERC20(token).transfer(treasury, balance);
    }

    function _swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        IUniswapV2Router02 router = uniswapV2Router;
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), tokenAmount);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            treasury,
            block.timestamp
        );
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override NotZeroAddress(to) NotZeroAddress(from) {
        if (amount == 0) revert AmountCannotBeZero();
        // sender has sufficient balance
        if (balanceOf(from) < amount) revert InsufficientBalance();

        // trading is enabled or sender is owner or sender is this contract
        if (!tradingEnabled && from != owner() && from != address(this))
            revert TradingNotEnabled();

        // take taxes
        if (!isExcludedFromFee[from] && !isExcludedFromFee[to]) {
            address pair = uniswapV2Pair;
            // sell to ETH
            if (pair == to && !_inSwap && swapToETH) {
                uint256 reserves = balanceOf(address(this));
                uint256 numTokensToSell = numTokensSellToETH;
                if (reserves >= numTokensToSell) {
                    _swapTokensForEth(numTokensToSell);
                }
                if (address(this).balance > 0) {
                    (bool sent, ) = payable(treasury).call{
                        value: address(this).balance
                    }("");
                    if (!sent) revert FailedETHSend();
                }
            }

            uint256 taxRate = to == pair ? sellTax : from == pair
                ? buyTax
                : transferTax;

            if (taxRate > 0) {
                // calculate tax (amount * taxRate / 1e4
                uint256 tax = (amount * taxRate) / 1e4;
                amount -= tax;

                super._transfer(from, address(this), tax);
            }
        }
        super._transfer(from, to, amount);
    }
}

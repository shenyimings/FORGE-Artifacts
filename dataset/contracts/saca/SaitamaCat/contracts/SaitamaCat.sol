// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract SaitamaCat is ERC20 {
    using SafeMath for uint256;
    struct Amm {
        address router;
        address pair;
    }
    struct Taxes {
        uint8 buyTax;
        uint8 sellTax;
        uint8 taxDenominator;
    }
    struct MaxTx {
        uint256 txLimit;
        uint8 blockDelay;
    }
    struct Wallets {
        address marketingWallet;
        address charityWallet;
        address presaler;
    }
    struct TaxRatio {
        uint8 marketingRatio;
        uint8 charityRatio;
    }

    address private _owner;
    uint8 private _decimals;
    Amm public amm;
    Taxes public taxes;
    MaxTx public maxTx;
    Wallets public wallets;
    TaxRatio public taxRatio;
    uint256 public launchedAt;
    uint256 private _swapLimit;
    IUniswapV2Router02 private _router;

    mapping(address => bool) private _isAuthorized;
    mapping(address => bool) private _isExcludeFromFee;
    mapping(address => bool) private _isExcludeFromLimit;

    constructor() ERC20("Saitama Cat", "SACA") {
        _decimals = 9;
        _mint(msg.sender, 20_000_000_000 * 10**decimals()); // Mint totalSupply in Wei

        _owner = msg.sender;
        _isAuthorized[msg.sender] = true;

        wallets = Wallets(
            0xA891EdE0A8864Ce23bCA9233c6485948cE745028, // Marketing
            0xbFdf952EeD02dc6901a09dCA9F5F69CBcc51820D, // Charity
            msg.sender // Presaler
        );

        taxes = Taxes(5, 5, 100); // Buy, Sell, Denominator
        taxRatio = TaxRatio(2, 3); // Marketing, Charity
        maxTx = MaxTx(totalSupply().div(100), 1); // Default maxTx = 1% totalSupply, 1 block delay

        amm.router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
        _router = IUniswapV2Router02(amm.router);
        amm.pair = IUniswapV2Factory(_router.factory()).createPair(
            address(this),
            _router.WETH() // Create liquidity WETH
        );

        _approve(address(this), amm.router, type(uint256).max);
        _isExcludeFromFee[msg.sender] = true;
        _isExcludeFromFee[address(this)] = true;
        _isExcludeFromFee[wallets.marketingWallet] = true;
        _isExcludeFromFee[wallets.charityWallet] = true;

        _isExcludeFromLimit[msg.sender] = true;
        _isExcludeFromLimit[address(this)] = true;
        _isExcludeFromLimit[wallets.marketingWallet] = true;
        _isExcludeFromLimit[wallets.charityWallet] = true;

        _swapLimit = totalSupply().div(200); // Swap tax if balance >= 0.5% totalSupply
    }

    modifier authorized() {
        require(
            _isAuthorized[msg.sender] || msg.sender == _owner,
            "Error: no permission!"
        );
        _;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function isExcludeFromFee(address adr) public view returns (bool) {
        return _isExcludeFromFee[adr];
    }

    function isExcludeFromLimit(address adr) public view returns (bool) {
        return _isExcludeFromLimit[adr];
    }

    // Wallets
    function setupWallets(
        address marketingWallet_,
        address charityWallet_,
        address presaler_
    ) external authorized {
        wallets = Wallets(marketingWallet_, charityWallet_, presaler_);

        _isExcludeFromFee[wallets.marketingWallet] = true;
        _isExcludeFromFee[wallets.charityWallet] = true;
        _isExcludeFromFee[wallets.presaler] = true;

        _isExcludeFromLimit[wallets.marketingWallet] = true;
        _isExcludeFromLimit[wallets.charityWallet] = true;
        _isExcludeFromLimit[wallets.presaler] = true;
    }

    function setPresaler(address presaler_) external authorized {
        wallets.presaler = presaler_;
        _isExcludeFromFee[wallets.presaler] = true;
        _isExcludeFromLimit[wallets.presaler] = true;
    }

    // Permissions
    function renounceOwnership() external authorized {
        _owner = address(0);
    }

    function authorize(address adr) external authorized {
        require(!_isAuthorized[adr], "Error: already authorized!");
        _isAuthorized[adr] = true;
        _isExcludeFromFee[adr] = true;
        _isExcludeFromLimit[adr] = true;
    }

    function unAuthorize(address adr) external authorized {
        require(_isAuthorized[adr], "Error: already not authorized!");
        _isAuthorized[adr] = false;
    }

    // Router and Pair
    function setAmm(address router_, address pair_) external authorized {
        amm.router = router_;
        amm.pair = pair_;
    }

    // Rescue ETH and Tokens in contract
    function rescueTokenFromContract(
        bool isETH,
        address tokenAddress,
        uint256 amount,
        address receiver
    ) external authorized {
        if (isETH) {
            // Get ETH from balance
            uint256 contractETHBalance = address(this).balance;
            payable(receiver).transfer(contractETHBalance);
        } else {
            IERC20(tokenAddress).transfer(receiver, amount);
        }
    }

    // Taxes
    function setTaxes(
        uint8 buyTax,
        uint8 sellTax,
        uint8 taxDenominator
    ) external authorized {
        require(
            buyTax <= (taxDenominator / 4) && sellTax <= (taxDenominator / 4),
            "Error: taxes need to be smaller than 25%!"
        );
        taxes.buyTax = buyTax;
        taxes.sellTax = sellTax;
        taxes.taxDenominator = taxDenominator;
    }

    function setIsExcludeFromFee(address adr, bool isExcludeFromFee_)
        external
        authorized
    {
        require(adr != amm.pair && adr != amm.router, "Error: cannot be amm!");
        _isExcludeFromFee[adr] = isExcludeFromFee_;
    }

    // Limit
    function setMaxTx(
        uint8 maxTxLimit_,
        uint8 limitDenominator_,
        uint8 blockDelay_
    ) external authorized {
        require(
            maxTxLimit_ > 0 &&
                maxTxLimit_ <= limitDenominator_ &&
                blockDelay_ <= 50, // Cannot block too long
            "Error: out of range"
        );
        maxTx.txLimit = totalSupply().mul(maxTxLimit_).div(limitDenominator_);
        maxTx.blockDelay = blockDelay_;
    }

    function setIsExcludeFromLimit(address adr, bool isExcludeFromLimit_)
        external
        authorized
    {
        _isExcludeFromLimit[adr] = isExcludeFromLimit_;
    }

    // Batch transfer Input: (["adress1", "address2",...], amount_)
    function airdrop(address[] memory list, uint256 amount) external {
        for (uint256 i = 0; i <= list.length; i++) {
            super._transfer(msg.sender, list[i], amount);
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // Check MaxTx (only in Sell/Buy)
        if (_shouldLimit(from, to)) {
            require(amount <= maxTx.txLimit, "Error: limit exceeded!");
        }

        if (_isExcludeFromFee[from] || _isExcludeFromFee[to]) {
            // No take fee
            super._transfer(from, to, amount);
        } else {
            amount = _takeFee(from, to, amount);
            super._transfer(from, to, amount);
        }

        // Swap tax to WETH
        if (balanceOf(address(this)) >= _swapLimit) {
            _swapTokenToETH(
                balanceOf(address(this)).mul(taxRatio.marketingRatio).div(
                    (taxRatio.marketingRatio + taxRatio.charityRatio)
                ),
                wallets.marketingWallet // Marketing
            );
            _swapTokenToETH(balanceOf(address(this)), wallets.charityWallet); // Charity
        }
    }

    function _takeFee(
        address from,
        address to,
        uint256 amount
    ) internal returns (uint256) {
        uint256 feeAmount = 0;

        if (from == amm.pair) {
            // Buying
            feeAmount = amount.mul(taxes.buyTax).div(taxes.taxDenominator);
            amount = amount.sub(feeAmount);
        } else if (to == amm.pair) {
            // Add liquidity
            if (balanceOf(to) == 0) {
                require(
                    to == wallets.presaler,
                    "Error: only presaler can add 1st liquidity!"
                );
                launchedAt = block.number;
                return amount;
            } else {
                // Selling
                feeAmount = amount.mul(taxes.sellTax).div(taxes.taxDenominator);
                amount = amount.sub(feeAmount);
            }
        }

        if (feeAmount != 0) {
            super._transfer(from, address(this), feeAmount);
        }

        return amount.sub(1); // Leave 1 wei. Increase holder
    }

    function _shouldLimit(address from, address to)
        internal
        view
        returns (bool)
    {
        return (balanceOf(amm.pair) != 0 && // Liquidity was added
            (from == amm.pair || to == amm.pair) && // Swapping
            !_isExcludeFromLimit[from] &&
            !_isExcludeFromLimit[to] &&
            launchedAt != 0 && // Launched
            block.number <= launchedAt + maxTx.blockDelay); // Only delay a few blocks after launch
    }

    function manualSetup(uint8 percentSwapLimit_, uint8 swapLimitDenominator_)
        external
        authorized
        returns (uint256)
    {
        require(
            percentSwapLimit_ >= 0 &&
                percentSwapLimit_ <= swapLimitDenominator_,
            "Error: out of range!"
        );
        _swapLimit = totalSupply().mul(percentSwapLimit_).div(
            swapLimitDenominator_
        );
        _swapTokenToETH(balanceOf(address(this)), wallets.marketingWallet);
        return _swapLimit;
    }

    function _swapTokenToETH(uint256 amount, address to) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _router.WETH();
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            to,
            block.timestamp
        );
    }
}

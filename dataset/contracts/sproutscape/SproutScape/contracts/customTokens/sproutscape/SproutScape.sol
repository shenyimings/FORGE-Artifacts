// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _setOwner(0x83d67f776b7deE7Bea6fe71A3EF9085f10B3e515);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

library SafeMath {
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function WETC() external pure returns (address);

    function WHT() external pure returns (address);

    function WROSE() external pure returns (address);

    function WAVAX() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function addLiquidityAVAX(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function addLiquidityETC(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function addLiquidityROSE(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactTokensForETCSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForAVAXSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForROSESupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

abstract contract BaseToken {
    event TokenCreated(
        address indexed owner,
        address indexed token,
        string tokenType
    );
}

contract SproutScape is IERC20, Ownable, BaseToken {
    using SafeMath for uint256;

    mapping(address => uint256) private tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private isExcludedFromFee;

    uint256 private tTotal;

    string private _name;
    string private _symbol;
    uint8 private immutable _decimals;

    uint256 public liquidityFee = 100;
    uint256 private previousLiquidityFee = liquidityFee;

    uint256 public teamFee = 100;
    uint256 private previousTeamFee = teamFee;

    IUniswapV2Router02 public uniswapV2Router;
    address public immutable uniswapV2Pair;
    address public teamAddress = 0x186B807FcD1DEE869821eA9a465E87Bca4fA9C5b;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled;

    uint256 private numTokensSellToAddToLiquidity;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event UpdatedTokenSellToLiquify(uint256 amount, uint256 previousAmount);
    event UpdatedLiquidityFeePercent(uint256 value, uint256 previousValue);
    event UpdatedTeamFeePercent(uint256 value, uint256 previousValue);
    event UpdatedTeamAddress(address value, address previousValue);
    event SwapTokensForEthFailed(uint256 amount);
    event AddLiquidityFailed(uint256 ethAmount);

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor(address router_) payable {
        _name = "SproutScape";
        _symbol = "sproutscape";
        _decimals = 18;

        tTotal = 500000000 * 10 ** _decimals;

        tOwned[owner()] = tTotal;

        numTokensSellToAddToLiquidity = (tTotal) / 10000; // 0.01%

        swapAndLiquifyEnabled = true;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(router_);

        uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), getNativeCurrency());

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;

        emit Transfer(address(0), owner(), tTotal);

        emit TokenCreated(owner(), address(this), "SproutScape");
    }

    function getNativeCurrency() internal view returns (address) {
        if (block.chainid == 61) {
            //etc
            return uniswapV2Router.WETC();
        } else if (block.chainid == 128) {
            //heco chain
            return uniswapV2Router.WHT();
        } else if (block.chainid == 42262) {
            //oasis
            return uniswapV2Router.WROSE();
        } else if (block.chainid == 43114 || block.chainid == 43113) {
            //avalance
            return uniswapV2Router.WAVAX();
        } else {
            return uniswapV2Router.WETH();
        }
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tOwned[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address account,
        address spender
    ) external view override returns (uint256) {
        return _allowances[account][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function excludeFromFee(address account) external onlyOwner {
        isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) external onlyOwner {
        isExcludedFromFee[account] = false;
    }

    function setLiquidityFeePercent(
        uint256 liquidityFeeBps
    ) external onlyOwner {
        emit UpdatedLiquidityFeePercent(liquidityFeeBps, liquidityFee);

        liquidityFee = liquidityFeeBps;

        validateTaxes();
    }

    function setTeamFeePercent(uint256 teamFeeBps) external onlyOwner {
        emit UpdatedTeamFeePercent(teamFeeBps, teamFee);

        teamFee = teamFeeBps;

        validateTaxes();
    }

    function setTeamAddress(address wallet) external onlyOwner {
        require(wallet != address(0x0));

        emit UpdatedTeamAddress(wallet, teamAddress);

        teamAddress = wallet;
    }

    function validateTaxes() internal view {
        require(liquidityFee + teamFee <= 10 ** 4 / 5, "Total fee is over 20%");
    }

    function setSwapAndLiquifyEnabled(bool enabled) external onlyOwner {
        swapAndLiquifyEnabled = enabled;
        emit SwapAndLiquifyEnabledUpdated(enabled);
    }

    function setTokenSellToLiquify(uint256 amount) external onlyOwner {
        require(
            amount > tTotal / 10 ** 5 && amount <= tTotal / 10 ** 3,
            "Amount must be between 0.001% - 0.1% of total supply"
        );

        emit UpdatedTokenSellToLiquify(amount, numTokensSellToAddToLiquidity);

        numTokensSellToAddToLiquidity = amount;
    }

    receive() external payable {}

    function _getValues(
        uint256 tAmount
    ) private view returns (uint256, uint256, uint256) {
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tTeamFee = calculateTeamFee(tAmount);
        uint256 tTransferAmount = tAmount - tLiquidity - tTeamFee;
        return (tTransferAmount, tLiquidity, tTeamFee);
    }

    function _takeLiquidity(address sender, uint256 tLiquidity) private {
        if (tLiquidity == 0) return;

        tOwned[address(this)] = tOwned[address(this)] + tLiquidity;

        emit Transfer(sender, address(this), tLiquidity);
    }

    function _takeTeamFee(address sender, uint256 tTeam) private {
        if (tTeam == 0) return;

        tOwned[teamAddress] = tOwned[teamAddress] + tTeam;

        emit Transfer(sender, teamAddress, tTeam);
    }

    function calculateLiquidityFee(
        uint256 amount
    ) private view returns (uint256) {
        return (amount * liquidityFee) / (10 ** 4);
    }

    function calculateTeamFee(uint256 amount) private view returns (uint256) {
        return (amount * teamFee) / (10 ** 4);
    }

    function removeAllFee() private {
        previousLiquidityFee = liquidityFee;
        previousTeamFee = teamFee;

        liquidityFee = 0;
        teamFee = 0;
    }

    function restoreAllFee() private {
        liquidityFee = previousLiquidityFee;
        teamFee = previousTeamFee;
    }

    function getIsExcludedFromFee(address account) public view returns (bool) {
        return isExcludedFromFee[account];
    }

    function _approve(
        address account,
        address spender,
        uint256 amount
    ) private {
        require(account != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[account][spender] = amount;
        emit Approval(account, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 contractTokenBalance = balanceOf(address(this));

        bool overMinTokenBalance = contractTokenBalance >=
            numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            swapAndLiquify(contractTokenBalance);
        }

        bool takeFee = !isExcludedFromFee[from] &&
            !isExcludedFromFee[to] &&
            (from == uniswapV2Pair || to == uniswapV2Pair);

        _tokenTransfer(from, to, amount, takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(half);

        uint256 newBalance = address(this).balance - initialBalance;

        if (newBalance == 0) return;

        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = getNativeCurrency();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        if (block.chainid == 61) {
            //etc
            try
                uniswapV2Router
                    .swapExactTokensForETCSupportingFeeOnTransferTokens(
                        tokenAmount,
                        0, // accept any amount of ETH
                        path,
                        address(this),
                        block.timestamp
                    )
            {} catch {
                emit SwapTokensForEthFailed(tokenAmount);
            }
        } else if (block.chainid == 42262) {
            //oasis
            try
                uniswapV2Router
                    .swapExactTokensForROSESupportingFeeOnTransferTokens(
                        tokenAmount,
                        0, // accept any amount of ETH
                        path,
                        address(this),
                        block.timestamp
                    )
            {} catch {
                emit SwapTokensForEthFailed(tokenAmount);
            }
        } else if (block.chainid == 43114 || block.chainid == 43113) {
            //avalance
            try
                uniswapV2Router
                    .swapExactTokensForAVAXSupportingFeeOnTransferTokens(
                        tokenAmount,
                        0, // accept any amount of ETH
                        path,
                        address(this),
                        block.timestamp
                    )
            {} catch {
                emit SwapTokensForEthFailed(tokenAmount);
            }
        } else {
            try
                uniswapV2Router
                    .swapExactTokensForETHSupportingFeeOnTransferTokens(
                        tokenAmount,
                        0, // accept any amount of ETH
                        path,
                        address(this),
                        block.timestamp
                    )
            {} catch {
                emit SwapTokensForEthFailed(tokenAmount);
            }
        }
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        if (block.chainid == 61) {
            //etc
            try
                uniswapV2Router.addLiquidityETC{value: ethAmount}(
                    address(this),
                    tokenAmount,
                    0,
                    0,
                    address(0xdead),
                    block.timestamp
                )
            {} catch {
                emit AddLiquidityFailed(ethAmount);
            }
        } else if (block.chainid == 42262) {
            //oasis
            try
                uniswapV2Router.addLiquidityROSE{value: ethAmount}(
                    address(this),
                    tokenAmount,
                    0,
                    0,
                    address(0xdead),
                    block.timestamp
                )
            {} catch {
                emit AddLiquidityFailed(ethAmount);
            }
        } else if (block.chainid == 43114 || block.chainid == 43113) {
            //avalance
            try
                uniswapV2Router.addLiquidityAVAX{value: ethAmount}(
                    address(this),
                    tokenAmount,
                    0,
                    0,
                    address(0xdead),
                    block.timestamp
                )
            {} catch {
                emit AddLiquidityFailed(ethAmount);
            }
        } else {
            try
                uniswapV2Router.addLiquidityETH{value: ethAmount}(
                    address(this),
                    tokenAmount,
                    0,
                    0,
                    address(0xdead),
                    block.timestamp
                )
            {} catch {
                emit AddLiquidityFailed(ethAmount);
            }
        }
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();

        (
            uint256 tTransferAmount,
            uint256 tLiquidity,
            uint256 tTeam
        ) = _getValues(amount);
        tOwned[sender] = tOwned[sender] - amount;
        tOwned[recipient] = tOwned[recipient] + tTransferAmount;
        _takeLiquidity(sender, tLiquidity);
        _takeTeamFee(sender, tTeam);
        emit Transfer(sender, recipient, tTransferAmount);

        if (!takeFee) restoreAllFee();
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) external {
        _burn(account, amount);
        _approve(
            account,
            _msgSender(),
            _allowances[account][_msgSender()].sub(
                amount,
                "ERC20: Burn amount exceeds allowance"
            )
        );
    }

    function _burn(address account, uint256 amount) private {
        require(account != address(0), "ERC20: burn from the zero address");

        if (amount == 0) return;

        tOwned[account] = tOwned[account] - amount;
        tTotal = tTotal - amount;

        emit Transfer(account, address(0), amount);
    }
}

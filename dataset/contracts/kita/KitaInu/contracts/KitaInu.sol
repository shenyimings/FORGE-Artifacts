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
        _setOwner(0x31DaFbfb3f96f9E85518B6F2Afa508B76CE50386);
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

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
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

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

abstract contract BaseToken {
    event TokenCreated(
        address indexed owner,
        address indexed token,
        string tokenType,
        uint256 version
    );
}

contract KitaInu is IERC20, Ownable, BaseToken {
    using SafeMath for uint256;

    uint256 public constant VERSION = 3;

    mapping(address => uint256) private rOwned;
    mapping(address => uint256) private tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private isExcludedFromFee;
    mapping(address => bool) private isExcluded;
    address[] private excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private immutable tTotal;
    uint256 private rTotal;
    uint256 private tFeeTotal;

    string private constant _name = "KITA INU";
    string private constant _symbol = "KITA";
    uint8 private constant _decimals = 18;

    bool public taxesAreLocked = false;

    uint256 public taxFee;
    uint256 private previousTaxFee;

    uint256 public liquidityFee;
    uint256 private previousLiquidityFee;

    uint256 public charityFee;
    uint256 private previousCharityFee;

    uint256 public marketingFee;
    uint256 private previousMarketingFee;

    uint256 public burnFee;
    uint256 private previousBurnFee;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address public constant developerAddress =
        0xefACd388769531AEa7546aF7A411fEA40cA434B2;
    address public charityAddress = 0xA67dE2b8c36848802b711D551c23935d987ABBEd;
    address public marketingAddress =
        0x9488cA8E59D7D68a63babB98Cb722AA7fcda3dfc;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled;

    uint256 private immutable numTokensSellToAddToLiquidity;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event UpdatedLiquidityFeePercent(uint256 value, uint256 previousValue);
    event UpdatedCharityFeePercent(uint256 value, uint256 previousValue);
    event UpdatedMarketingFeePercent(uint256 value, uint256 previousValue);
    event UpdatedBurnFeePercent(uint256 value, uint256 previousValue);
    event UpdatedCharityAddress(address value, address previousValue);
    event UpdatedMarketingAddress(address value, address previousValue);
    event Reflect(address sender, uint256 amount);
    event SwapError(uint256 amount);

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier onlyAuthorized() {
        require(
            msg.sender == owner() || msg.sender == developerAddress,
            "Not authorized"
        );
        _;
    }

    constructor() {
        tTotal = 1e15 * 10 ** _decimals;
        rTotal = (MAX - (MAX % tTotal));

        taxFee = 0;
        previousTaxFee = taxFee;

        liquidityFee = 500;
        previousLiquidityFee = liquidityFee;

        charityFee = 100;
        previousCharityFee = charityFee;

        marketingFee = 100;
        previousMarketingFee = marketingFee;

        burnFee = 100;
        previousBurnFee = burnFee;

        numTokensSellToAddToLiquidity = (tTotal) / 10000; // 0.01%

        swapAndLiquifyEnabled = true;

        rOwned[owner()] = rTotal;

        uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[charityAddress] = true;
        isExcludedFromFee[marketingAddress] = true;
        isExcludedFromFee[developerAddress] = true;

        emit Transfer(address(0), owner(), tTotal);

        emit TokenCreated(
            owner(),
            address(this),
            "liquidityGenerator",
            VERSION
        );
    }

    function name() external pure returns (string memory) {
        return _name;
    }

    function symbol() external pure returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (isExcluded[account]) return tOwned[account];
        return tokenFromReflection(rOwned[account]);
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

    function setNewRouter(address newRouter) external onlyAuthorized {
        uniswapV2Router = IUniswapV2Router02(newRouter);
        address get_pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(
            address(this),
            uniswapV2Router.WETH()
        );
        if (get_pair == address(0)) {
            uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
                .createPair(address(this), uniswapV2Router.WETH());
        } else {
            uniswapV2Pair = get_pair;
        }
    }

    function getCirculatingSupply() public view returns (uint256) {
        return tTotal - balanceOf(DEAD) - balanceOf(address(0));
    }

    function totalFees() external view returns (uint256) {
        return tFeeTotal;
    }

    function tokenFromReflection(
        uint256 rAmount
    ) public view returns (uint256) {
        require(
            rAmount <= rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tCharity,
            uint256 tMarketing,
            uint256 tBurn
        ) = _getValues(tAmount);
        tOwned[sender] = tOwned[sender] - tAmount;
        rOwned[sender] = rOwned[sender] - rAmount;
        tOwned[recipient] = tOwned[recipient] + tTransferAmount;
        rOwned[recipient] = rOwned[recipient] + rTransferAmount;
        _takeLiquidity(sender, tLiquidity);
        _takeCharityFee(sender, tCharity);
        _takeMarketingFee(sender, tMarketing);
        _takeBurnFee(sender, tBurn);
        _reflectFee(sender, rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function excludeFromFee(address account) external onlyAuthorized {
        isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) external onlyAuthorized {
        isExcludedFromFee[account] = false;
    }

    function lockTaxes() external onlyAuthorized {
        require(!taxesAreLocked, "Taxes are already locked");
        taxesAreLocked = true;
    }

    function unlockTaxes() external onlyAuthorized {
        require(taxesAreLocked, "Taxes are already unlocked");
        taxesAreLocked = false;
    }

    function setLiquidityFeePercent(
        uint256 liquidityFeeBps
    ) external onlyAuthorized {
        emit UpdatedLiquidityFeePercent(liquidityFeeBps, liquidityFee);

        liquidityFee = liquidityFeeBps;

        validateTaxes();
    }

    function setCharityFeePercent(
        uint256 charityFeeBps
    ) external onlyAuthorized {
        emit UpdatedCharityFeePercent(charityFeeBps, charityFee);

        charityFee = charityFeeBps;

        validateTaxes();
    }

    function setMarketingFeePercent(
        uint256 marketingFeeBps
    ) external onlyAuthorized {
        emit UpdatedMarketingFeePercent(marketingFeeBps, marketingFee);

        marketingFee = marketingFeeBps;

        validateTaxes();
    }

    function setBurnFeePercent(uint256 burnFeeBps) external onlyAuthorized {
        emit UpdatedBurnFeePercent(burnFeeBps, burnFee);

        burnFee = burnFeeBps;

        validateTaxes();
    }

    function setCharityAddress(address wallet) external onlyAuthorized {
        require(wallet != address(0x0));

        emit UpdatedCharityAddress(wallet, charityAddress);

        charityAddress = wallet;
    }

    function setMarketingAddress(address wallet) external onlyAuthorized {
        require(wallet != address(0x0));

        emit UpdatedMarketingAddress(wallet, marketingAddress);

        marketingAddress = wallet;
    }

    function validateTaxes() internal view {
        require(
            taxFee + liquidityFee + charityFee + marketingFee + burnFee <=
                10 ** 4 / 5,
            "Total fee is over 20%"
        );
    }

    function setSwapAndLiquifyEnabled(bool enabled) external onlyAuthorized {
        swapAndLiquifyEnabled = enabled;
        emit SwapAndLiquifyEnabledUpdated(enabled);
    }

    receive() external payable {}

    function _getValues(
        uint256 tAmount
    )
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        GetTValues memory values = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            values.tFee,
            values.tLiquidity,
            values.tCharity,
            values.tMarketing,
            values.tBurn,
            _getRate()
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            values.tTransferAmount,
            values.tFee,
            values.tLiquidity,
            values.tCharity,
            values.tMarketing,
            values.tBurn
        );
    }

    struct GetTValues {
        uint256 tTransferAmount;
        uint256 tFee;
        uint256 tLiquidity;
        uint256 tCharity;
        uint256 tMarketing;
        uint256 tBurn;
    }

    function _getTValues(
        uint256 tAmount
    ) private view returns (GetTValues memory) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tCharityFee = calculateCharityFee(tAmount);
        uint256 tMarketingFee = calculateMarketingFee(tAmount);
        uint256 tBurnFee = calculateBurnFee(tAmount);
        uint256 tTransferAmount = tAmount -
            tFee -
            tLiquidity -
            tCharityFee -
            tMarketingFee -
            tBurnFee;

        GetTValues memory values = GetTValues(
            tTransferAmount,
            tFee,
            tLiquidity,
            tCharityFee,
            tMarketingFee,
            tBurnFee
        );

        return values;
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 tCharity,
        uint256 tMarketing,
        uint256 tBurn,
        uint256 currentRate
    ) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rLiquidity = tLiquidity * currentRate;
        uint256 rCharity = tCharity * currentRate;
        uint256 rMarketing = tMarketing * currentRate;
        uint256 rBurn = tBurn * currentRate;
        uint256 rTransferAmount = rAmount -
            rFee -
            rLiquidity -
            rCharity -
            rMarketing -
            rBurn;
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = rTotal;
        uint256 tSupply = tTotal;
        for (uint256 i = 0; i < excluded.length; i++) {
            if (rOwned[excluded[i]] > rSupply || tOwned[excluded[i]] > tSupply)
                return (rTotal, tTotal);
            rSupply = rSupply - rOwned[excluded[i]];
            tSupply = tSupply - tOwned[excluded[i]];
        }
        if (rSupply < rTotal / tTotal) return (rTotal, tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(address sender, uint256 tLiquidity) private {
        if (tLiquidity == 0) return;

        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity * currentRate;
        rOwned[address(this)] = rOwned[address(this)] + rLiquidity;

        if (isExcluded[address(this)])
            tOwned[address(this)] = tOwned[address(this)] + tLiquidity;

        emit Transfer(sender, address(this), tLiquidity);
    }

    function _takeCharityFee(address sender, uint256 tCharity) private {
        if (tCharity == 0) return;

        uint256 currentRate = _getRate();
        uint256 rCharity = tCharity * currentRate;
        rOwned[charityAddress] = rOwned[charityAddress] + rCharity;

        if (isExcluded[charityAddress])
            tOwned[charityAddress] = tOwned[charityAddress] + tCharity;

        emit Transfer(sender, charityAddress, tCharity);
    }

    function _takeMarketingFee(address sender, uint256 tMarketing) private {
        if (tMarketing == 0) return;

        uint256 currentRate = _getRate();
        uint256 rMarketing = tMarketing * currentRate;
        rOwned[marketingAddress] = rOwned[marketingAddress] + rMarketing;

        if (isExcluded[marketingAddress])
            tOwned[marketingAddress] = tOwned[marketingAddress] + tMarketing;

        emit Transfer(sender, marketingAddress, tMarketing);
    }

    function _takeBurnFee(address sender, uint256 tBurn) private {
        if (tBurn == 0) return;

        uint256 currentRate = _getRate();
        uint256 rBurn = tBurn * currentRate;
        rOwned[DEAD] = rOwned[DEAD] + rBurn;

        if (isExcluded[DEAD]) tOwned[DEAD] = tOwned[DEAD] + tBurn;

        emit Transfer(sender, DEAD, tBurn);
    }

    function _reflectFee(address sender, uint256 rFee, uint256 tFee) private {
        if (tFee == 0) return;

        rTotal = rTotal - rFee;
        tFeeTotal = tFeeTotal + tFee;

        emit Reflect(sender, tFee);
    }

    function calculateTaxFee(uint256 amount) private view returns (uint256) {
        return (amount * taxFee) / (10 ** 4);
    }

    function calculateLiquidityFee(
        uint256 amount
    ) private view returns (uint256) {
        return (amount * liquidityFee) / (10 ** 4);
    }

    function calculateCharityFee(
        uint256 amount
    ) private view returns (uint256) {
        return (amount * charityFee) / (10 ** 4);
    }

    function calculateMarketingFee(
        uint256 amount
    ) private view returns (uint256) {
        return (amount * marketingFee) / (10 ** 4);
    }

    function calculateBurnFee(uint256 amount) private view returns (uint256) {
        return (amount * burnFee) / (10 ** 4);
    }

    function removeAllFee() private {
        previousTaxFee = taxFee;
        previousLiquidityFee = liquidityFee;
        previousCharityFee = charityFee;
        previousMarketingFee = marketingFee;
        previousBurnFee = burnFee;

        taxFee = 0;
        liquidityFee = 0;
        charityFee = 0;
        marketingFee = 0;
        burnFee = 0;
    }

    function restoreAllFee() private {
        taxFee = previousTaxFee;
        liquidityFee = previousLiquidityFee;
        charityFee = previousCharityFee;
        marketingFee = previousMarketingFee;
        burnFee = previousBurnFee;
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
            !taxesAreLocked;

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
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        try
            uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0, // accept any amount of ETH
                path,
                address(this),
                block.timestamp
            )
        {} catch {
            emit SwapError(tokenAmount);
        }
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();

        if (isExcluded[sender] && !isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!isExcluded[sender] && isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!isExcluded[sender] && !isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (isExcluded[sender] && isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tCharity,
            uint256 tMarketing,
            uint256 tBurn
        ) = _getValues(tAmount);
        rOwned[sender] = rOwned[sender] - rAmount;
        rOwned[recipient] = rOwned[recipient] + rTransferAmount;
        _takeLiquidity(sender, tLiquidity);
        _takeCharityFee(sender, tCharity);
        _takeMarketingFee(sender, tMarketing);
        _takeBurnFee(sender, tBurn);
        _reflectFee(sender, rFee, tFee);

        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tCharity,
            uint256 tMarketing,
            uint256 tBurn
        ) = _getValues(tAmount);
        rOwned[sender] = rOwned[sender] - rAmount;
        tOwned[recipient] = tOwned[recipient] + tTransferAmount;
        rOwned[recipient] = rOwned[recipient] + rTransferAmount;
        _takeLiquidity(sender, tLiquidity);
        _takeCharityFee(sender, tCharity);
        _takeMarketingFee(sender, tMarketing);
        _takeBurnFee(sender, tBurn);
        _reflectFee(sender, rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tCharity,
            uint256 tMarketing,
            uint256 tBurn
        ) = _getValues(tAmount);
        tOwned[sender] = tOwned[sender] - tAmount;
        rOwned[sender] = rOwned[sender] - rAmount;
        rOwned[recipient] = rOwned[recipient] + rTransferAmount;
        _takeLiquidity(sender, tLiquidity);
        _takeCharityFee(sender, tCharity);
        _takeMarketingFee(sender, tMarketing);
        _takeBurnFee(sender, tBurn);
        _reflectFee(sender, rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
}

import "./Utils.sol";
import "./Uniswap.sol";

/*
#######################################################################################################################
#######################################################################################################################

Micropets Upgradable Token Contract
https://micropets.io

Copyright CryptIT GmbH

#######################################################################################################################
#######################################################################################################################
*/

pragma solidity ^0.8.16;

// SPDX-License-Identifier: UNLICENSED

contract MicroPets is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) public excludedFromFee;
    mapping(uint24 => address) public feeToPoolAddress;
    mapping(address => bool) public isPoolAddress;

    string private _name;
    string private _symbol;
    uint256 private _totalSupply;

    uint256 private _taxCollected;

    uint256 private minimumTokensBeforeSwap;
    uint256 private minimumETHToTransfer;

    address payable public lpVaultAddress;
    address payable public marketingAddress;
    address payable public developmentAddress;
    address payable public coinStakingAddress;
    address public tokenReserveAddress;

    ISwapRouter public swapRouter;
    address public poolToken;
    bool public enableUniSwap;

    bool public swapAndLiquifyEnabled;
    bool public autoSplitShares;
    bool public taxesEnabled;

    bool inSwapAndLiquify;
    bool inSplitShares;

    bool public migrationRunning;
    uint16 public migrationRate;
    address public migrationVault;

    Configs public tokenConfigs;

    struct Configs {
        uint8 coinShareLP;
        uint8 coinShareMarketing;
        uint8 coinShareDevelopment;
        uint8 coinShareStaking;
        uint8 tokenShareReserve;
        uint8 buyTax;
        uint8 sellTax;
        uint24 autoSwapTier;
    }

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event EnabledUniswap();
    event ExcludeFromFee(address indexed wallet);
    event IncludeInFee(address indexed wallet);
    event UpdateOperationWallet(
        address prevWallet,
        address newWallet,
        string operation
    );
    event UpdateTax(uint8 buyTax, uint8 sellTax);

    modifier lockForSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier lockForSplitShare() {
        inSplitShares = true;
        _;
        inSplitShares = false;
    }

    ////////////////////////////////////////////////////////////////////
    // Upgrade add state
    ////////////////////////////////////////////////////////////////////

    IUniswapV2Router02 public uniswapV2Router;

    function initialize() public {
        _setOwner();

        _name = "MicroPets";
        _symbol = "PETS";
        _totalSupply = 10_000_000_000 * 10 ** 18;
        uint256 migrationAmount = 5_000_000_000 * 10 ** 18;
        uint256 ownerSupply = 500_000_000 * 10 ** 18;
        migrationVault = address(new MigrationVAult());

        _balances[_msgSender()] = _totalSupply.sub(ownerSupply).sub(
            migrationAmount
        );
        emit Transfer(
            address(0),
            _msgSender(),
            _totalSupply.sub(ownerSupply).sub(migrationAmount)
        );

        _balances[0x38402a3316A4Ab8fc742AE42c30D2ff9b6f43DC5] = ownerSupply;
        emit Transfer(
            address(0),
            0x38402a3316A4Ab8fc742AE42c30D2ff9b6f43DC5,
            ownerSupply
        );

        _balances[migrationVault] = migrationAmount;
        emit Transfer(address(0), migrationVault, migrationAmount);

        excludedFromFee[_msgSender()] = true;
        excludedFromFee[address(this)] = true;

        migrationRunning = true;
        migrationRate = 1120;

        minimumTokensBeforeSwap = 300 * 10 ** 18;
        minimumETHToTransfer = 5 * 10 ** 17;

        swapAndLiquifyEnabled = true;
        autoSplitShares = true;
        enableUniSwap = true;
        taxesEnabled = true;

        poolToken = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

        _setShares(18, 27, 27, 27, 8, 12, 12, 500);

        _setLpVaultAddress(payable(0x70875197aCf27ae827Dc056acE22f5893fd55ED5));

        _setMarketingAddress(
            payable(0x4aDFaf09e978657337ba596f5D1D61D068962Ec2)
        );
        _setDevelopmentAddress(
            payable(0x465fE58cAFadEA9C80D04078B72c5Bb1136f28C0)
        );
        _setCoinStakingAddress(
            payable(0x5bfAf16Cc8E39Cc34EC575A1E510E4f293EaFc44)
        );
        _setTokenReserveAddress(0xE9fCB23A23ade85D424625B00C77eA99f8e64C0D);
    }

    // Start ERC-20 standard functions

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return _allowances[owner][spender];
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
            _allowances[_msgSender()][spender].add(addedValue)
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

    // End ERC-20 standart functions

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            emit Transfer(from, to, 0);
            return;
        }

        if (!taxesEnabled || excludedFromFee[from] || excludedFromFee[to]) {
            _transferStandard(from, to, amount);
            return;
        }

        bool isToPool = isPoolAddress[to]; //means sell or provide LP
        bool isFromPool = isPoolAddress[from]; //means buy or remove LP

        if (!isToPool && !isFromPool) {
            _transferStandard(from, to, amount);
            return;
        }

        if (isToPool) {
            handleTaxAutomation();
            _transferWithTax(from, to, amount, tokenConfigs.sellTax);
        } else {
            _transferWithTax(from, to, amount, tokenConfigs.buyTax);
        }
    }

    function handleTaxAutomation() internal {
        bool hasSwapped = false;

        if (!inSwapAndLiquify && !inSplitShares && swapAndLiquifyEnabled) {
            uint256 contractTokenBalance = balanceOf(address(this));
            if (contractTokenBalance >= minimumTokensBeforeSwap) {
                swapAndLiquify(contractTokenBalance);
                hasSwapped = true;
            }
        }

        if (
            !hasSwapped &&
            !inSplitShares &&
            !inSwapAndLiquify &&
            autoSplitShares &&
            address(this).balance >= minimumETHToTransfer
        ) {
            _distributeTax();
        }
    }

    function safeTransferETH(address payable to, uint256 value) internal {
        (bool sentETH, ) = to.call{value: value}("");
        require(sentETH, "Failed to send ETH");
    }

    function safeTransferToken(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Failed to send token"
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint value
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Failed to transfer from"
        );
    }

    function manualSwapAndLiquify(
        uint256 tokenAmountToSwap
    ) external onlyOwner {
        if (!inSwapAndLiquify && !inSplitShares) {
            uint256 contractTokenBalance = balanceOf(address(this));

            require(
                contractTokenBalance >= tokenAmountToSwap,
                "Invalid amount"
            );

            if (tokenAmountToSwap >= minimumTokensBeforeSwap) {
                swapAndLiquify(tokenAmountToSwap);
            }
        }
    }

    function swapTokensForETH(
        uint256 tokenAmount
    ) internal returns (uint256 swappedAmount, uint256 tokenReserveShare) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        IUniswapV2Factory factory = IUniswapV2Factory(
            uniswapV2Router.factory()
        );
        address pair = factory.getPair(path[0], path[1]);
        uint256 maxSwap = _balances[pair].div(100);

        swappedAmount = tokenAmount > maxSwap ? maxSwap : tokenAmount;
        tokenReserveShare = swappedAmount
            .mul(tokenConfigs.tokenShareReserve)
            .div(100);

        swappedAmount = swappedAmount.sub(tokenReserveShare);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swappedAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function swapAndLiquify(uint256 tokensToSwap) internal lockForSwap {
        (uint256 swappedAmount, uint256 tokenReserveShare) = swapTokensForETH(tokensToSwap);
        _transferStandard(address(this), tokenReserveAddress, tokenReserveShare);
        _taxCollected = _taxCollected.add(swappedAmount).add(tokenReserveShare);
    }

    function _calcuclateShare(
        uint8 share,
        uint256 amount
    ) internal pure returns (uint256) {
        return amount.mul(share).div(100);
    }

    function _distributeTax() internal lockForSplitShare {
        uint256 balance = address(this).balance;

        safeTransferETH(
            lpVaultAddress,
            _calcuclateShare(tokenConfigs.coinShareLP, balance)
        );
        safeTransferETH(
            marketingAddress,
            _calcuclateShare(tokenConfigs.coinShareMarketing, balance)
        );
        safeTransferETH(
            developmentAddress,
            _calcuclateShare(tokenConfigs.coinShareDevelopment, balance)
        );
        safeTransferETH(
            coinStakingAddress,
            _calcuclateShare(tokenConfigs.coinShareStaking, balance)
        );
    }

    function distributeTax() external onlyOwner {
        _distributeTax();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    function _transferWithTax(
        address sender,
        address recipient,
        uint256 amount,
        uint256 tax
    ) internal {
        if (tax == 0) {
            _transferStandard(sender, recipient, amount);
            return;
        }

        _balances[sender] = _balances[sender].sub(amount);

        uint256 taxAmount = amount.mul(tax).div(100);
        uint256 receiveAmount = amount.sub(taxAmount);

        _balances[address(this)] = _balances[address(this)].add(taxAmount);
        _balances[recipient] = _balances[recipient].add(receiveAmount);

        emit Transfer(sender, recipient, receiveAmount);
    }

    function includeInFee(address account) external onlyOwner {
        excludedFromFee[account] = false;
        emit IncludeInFee(account);
    }

    function excludeFromFee(address account) external onlyOwner {
        excludedFromFee[account] = true;
        emit ExcludeFromFee(account);
    }

    function _setMarketingAddress(address payable _marketingAddress) internal {
        marketingAddress = _marketingAddress;
    }

    function _setDevelopmentAddress(
        address payable _developmentAddress
    ) internal {
        developmentAddress = _developmentAddress;
    }

    function _setLpVaultAddress(address payable _vaultAddress) internal {
        lpVaultAddress = _vaultAddress;
    }

    function _setCoinStakingAddress(
        address payable _coinStakingAddress
    ) internal {
        coinStakingAddress = _coinStakingAddress;
    }

    function _setTokenReserveAddress(address _tokenReserveAddress) internal {
        tokenReserveAddress = _tokenReserveAddress;
    }

    function isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function setMarketingAddress(
        address payable _marketingAddress
    ) external onlyOwner {
        require(!isContract(_marketingAddress), "Cannot set contract address");
        emit UpdateOperationWallet(
            marketingAddress,
            _marketingAddress,
            "marketing"
        );
        _setMarketingAddress(_marketingAddress);
    }

    function setDevelopmentAddress(
        address payable _developmentAddress
    ) external onlyOwner {
        require(
            !isContract(_developmentAddress),
            "Cannot set contract address"
        );
        emit UpdateOperationWallet(
            developmentAddress,
            _developmentAddress,
            "development"
        );
        _setDevelopmentAddress(_developmentAddress);
    }

    function setLpVaultAddress(
        address payable _vaultAddress
    ) external onlyOwner {
        require(!isContract(_vaultAddress), "Cannot set contract address");
        emit UpdateOperationWallet(lpVaultAddress, _vaultAddress, "lpvault");
        _setLpVaultAddress(_vaultAddress);
    }

    function setCoinStakingAddress(
        address payable _coinStakingAddress
    ) external onlyOwner {
        require(
            !isContract(_coinStakingAddress),
            "Cannot set contract address"
        );
        emit UpdateOperationWallet(
            coinStakingAddress,
            _coinStakingAddress,
            "staking"
        );
        _setCoinStakingAddress(_coinStakingAddress);
    }

    function setTokenReserveAddress(
        address _tokenReserveAddress
    ) external onlyOwner {
        emit UpdateOperationWallet(
            tokenReserveAddress,
            _tokenReserveAddress,
            "reserve"
        );
        _setTokenReserveAddress(_tokenReserveAddress);
    }

    function _setShares(
        uint8 coinShareLP,
        uint8 coinShareMarketing,
        uint8 coinShareDevelopment,
        uint8 coinShareStaking,
        uint8 tokenShareReserve,
        uint8 buyTax,
        uint8 sellTax,
        uint24 autoSwapTier
    ) internal {
        tokenConfigs.coinShareLP = coinShareLP;
        tokenConfigs.coinShareMarketing = coinShareMarketing;
        tokenConfigs.coinShareDevelopment = coinShareDevelopment;
        tokenConfigs.coinShareStaking = coinShareStaking;
        tokenConfigs.tokenShareReserve = tokenShareReserve;
        tokenConfigs.buyTax = buyTax;
        tokenConfigs.sellTax = sellTax;
        tokenConfigs.autoSwapTier = autoSwapTier;
    }

    function setShares(
        uint8 coinShareLP,
        uint8 coinShareMarketing,
        uint8 coinShareDevelopment,
        uint8 coinShareStaking,
        uint8 tokenShareReserve,
        uint8 buyTax,
        uint8 sellTax
    ) external onlyOwner {
        require(buyTax <= 25 && sellTax <= 25, "Invalid Tax");
        require(tokenShareReserve <= 100, "Invalid token share");
        require(
            coinShareLP +
                coinShareMarketing +
                coinShareDevelopment +
                coinShareStaking ==
                100,
            "Invalid coin shares"
        );
        _setShares(
            coinShareLP,
            coinShareMarketing,
            coinShareDevelopment,
            coinShareStaking,
            tokenShareReserve,
            buyTax,
            sellTax,
            500
        );
        emit UpdateTax(buyTax, sellTax);
    }

    function getTax() external view returns (uint8, uint8) {
        return (tokenConfigs.buyTax, tokenConfigs.sellTax);
    }

    function setMinimumTokensBeforeSwap(
        uint256 _minimumTokensBeforeSwap
    ) external onlyOwner {
        minimumTokensBeforeSwap = _minimumTokensBeforeSwap;
    }

    function setMinimumETHToTransfer(
        uint256 _minimumETHToTransfer
    ) external onlyOwner {
        minimumETHToTransfer = _minimumETHToTransfer;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function setAutoSplitSharesEnables(bool _enabled) external onlyOwner {
        autoSplitShares = _enabled;
    }

    function setMigrationRunning(bool running) external onlyOwner {
        migrationRunning = running;
    }

    function setMigrationRate(uint16 newRate) external onlyOwner {
        migrationRate = newRate;
    }

    function enableUniswap() external onlyOwner {
        require(!enableUniSwap, "Already enabled!");
        enableUniSwap = true;
        emit EnabledUniswap();
    }

    function addPoolAddress(address pool) external onlyOwner {
        isPoolAddress[pool] = true;
    }

    function removePoolAddress(address pool) external onlyOwner {
        isPoolAddress[pool] = false;
    }

    function _setupExchange(address newRouter) internal {
        IUniswapV2Router02 _newPancakeRouter = IUniswapV2Router02(newRouter);
        IUniswapV2Factory factory = IUniswapV2Factory(
            _newPancakeRouter.factory()
        );

        address existingPair = factory.getPair(
            address(this),
            _newPancakeRouter.WETH()
        );

        if (existingPair == address(0)) {
            address lpPool = factory.createPair(
                address(this),
                _newPancakeRouter.WETH()
            );

            isPoolAddress[lpPool] = true;
        } else {
            isPoolAddress[existingPair] = true;
        }

        uniswapV2Router = _newPancakeRouter;
    }

    function setupExchange(address newRouter) external onlyOwner {
        _setupExchange(newRouter);
    }

    function totalTaxCollected() external view onlyOwner returns (uint256) {
        return _taxCollected;
    }

    function burn(uint256 amount) external {
        require(balanceOf(_msgSender()) >= amount, "Insufficient balance");
        _balances[_msgSender()] = _balances[_msgSender()].sub(amount);
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(_msgSender(), address(0), amount);
    }

    function getMigrationAmount(
        address userWallet
    ) external view returns (uint256, uint256) {
        uint256 V1Balance = IERC20(0xA77346760341460B42C230ca6D21d4c8E743Fa9c)
            .balanceOf(userWallet);
        return (V1Balance, V1Balance.div(migrationRate));
    }

    function migrate() external {
        require(migrationRunning, "Migration over");

        uint256 V1Balance = IERC20(0xA77346760341460B42C230ca6D21d4c8E743Fa9c)
            .balanceOf(_msgSender());

        require(V1Balance > 0, "Invalid migration");

        safeTransferFrom(
            0xA77346760341460B42C230ca6D21d4c8E743Fa9c,
            _msgSender(),
            address(this),
            V1Balance
        );

        uint256 newTokenAmount = V1Balance.div(migrationRate);
        _transferStandard(migrationVault, _msgSender(), newTokenAmount);
    }

    function retrieveOldPets(address receiver) external onlyOwner {
        IERC20 V1 = IERC20(0xA77346760341460B42C230ca6D21d4c8E743Fa9c);
        V1.transfer(receiver, V1.balanceOf(address(this)));
    }

    function retrieveMigrationPets(uint256 amount) external onlyOwner {
        require(_balances[migrationVault] >= amount, "Invalid amount");
        _transferStandard(migrationVault, _msgSender(), amount);
    }

    receive() external payable {}
}

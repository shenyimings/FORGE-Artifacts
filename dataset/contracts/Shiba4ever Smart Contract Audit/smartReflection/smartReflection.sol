//SPDX-License-Identifier: MIT

//CONTRACT MADE ON https://martik.site/create/contract
//MAKE YOUR ANALYSIS AND INVEST ONLY AT YOUR RESPONSIBILITY.

pragma solidity ^0.8.7;

interface IBEP20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

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

interface IRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

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
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IFactory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IDividendDistributor {
    function setDistributionCriteria(
        uint256 _minPeriod,
        uint256 _minDistribution
    ) external;

    function setShare(address shareholder, uint256 amount) external;

    function deposit() external payable;

    function process(uint256 gas) external;

    function claimDividend(address shareholder) external;

    function getUnpaidEarnings(address shareholder)
        external
        view
        returns (uint256);
}

interface IDividendDistributorFactory {
    function createDistribuitor(address router, address rewardtoken)
        external
        returns (address);
}

contract smartReflection {
    //IMPORTS
    IDividendDistributorFactory public distributorFactory =
        block.chainid == 56
            ? distributorFactory = IDividendDistributorFactory(
                0x1Ca9813A1c9341f7bcA9490C3da0F306bc456AdC
            )
            : block.chainid == 97
            ? distributorFactory = IDividendDistributorFactory(
                0x516848a149f3e45818CA043334379BdC52ea7d0f
            )
            : (block.chainid == 1 || block.chainid == 5)
            ? distributorFactory = IDividendDistributorFactory(
                0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
            )
            : distributorFactory = IDividendDistributorFactory(
            0x1Ca9813A1c9341f7bcA9490C3da0F306bc456AdC
        );
    IDividendDistributor public distributor;
    IRouter public router =
        block.chainid == 56
            ? router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E)
            : block.chainid == 97
            ? router = IRouter(0xD99D1c33F9fC3444f8101754aBC46c52416550D1)
            : (block.chainid == 1 || block.chainid == 5)
            ? router = IRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)
            : router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IBEP20 public REWARD = IBEP20(router.WETH());
    address WBNB = router.WETH();
    //MAPPING
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) public _rOwned;
    mapping(address => uint256) public _tOwned;
    mapping(address => bool) private _isExcludedFromFee; //fees
    mapping(address => bool) private _isExcluded; //reflection
    mapping(address => bool) public isDividendExempt;
    mapping(address => bool) public isPair;
    //ADDRESSES
    address[] private _excluded;
    address public deadWallet = 0x000000000000000000000000000000000000dEaD;
    address public marketingWallet = msg.sender;
    address public rewardWallet = msg.sender;
    address private _owner = msg.sender;
    //BOOL
    bool public swapEnabled = true;
    bool private swapping;
    //UINT
    uint8 private _decimals = 18;
    uint256 private MAX = ~uint256(0);
    uint256 private _tTotal = 1000000000 * 10**_decimals;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 public distributorGas = 300000;
    //STRINGS
    string private _name = "smartReflection";
    string private _symbol = "smartReflection";
    //STRUCTS
    struct Taxes {
        uint256 rfi;
        uint256 marketing;
        uint256 Burn;
        uint256 TokenRef;
    }
    struct TotFeesPaidStruct {
        uint256 rfi;
        uint256 marketing;
        uint256 Burn;
        uint256 TokenRef;
    }
    struct valuesFromGetValues {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rRfi;
        uint256 rBurn;
        uint256 rMarketing;
        uint256 rTokenRef;
        uint256 tTransferAmount;
        uint256 tRfi;
        uint256 tBurn;
        uint256 tMarketing;
        uint256 tTokenRef;
    }
    Taxes public taxes = Taxes(250, 250, 250, 250);
    Taxes public sellTaxes = Taxes(250, 250, 250, 250);
    TotFeesPaidStruct public totFeesPaid;

    //MODIFIERS
    modifier lockTheSwap() {
        swapping = true;
        _;
        swapping = false;
    }
    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }
    struct ffees {
        uint256 _rfiFee;
        uint256 _marketingFee;
        uint256 _burnFee;
        uint256 _TokenRefFee;
        uint256 _sellRfiFee;
        uint256 _sellMarketingFee;
        uint256 _sellBurnFee;
        uint256 _sellTokenRefFee;
    }

    constructor(
        string memory token_name,
        string memory short_symbol,
        uint8 token_decimals,
        uint256 token_totalSupply,
        address rewardtoken,
        ffees memory _fees
    ) payable {
        _name = token_name;
        _symbol = short_symbol;
        _decimals = token_decimals;
        _tTotal = token_totalSupply * (10**_decimals);
        MAX = ~uint256(0);
        _rTotal = (MAX - (MAX % _tTotal));
        REWARD = IBEP20(rewardtoken);
        setFees(
            _fees._rfiFee,
            _fees._marketingFee,
            _fees._burnFee,
            _fees._TokenRefFee,
            _fees._sellRfiFee,
            _fees._sellMarketingFee,
            _fees._sellBurnFee,
            _fees._sellTokenRefFee
        );

        address _pair = IFactory(router.factory()).createPair(
            address(this),
            router.WETH()
        );

        distributor = IDividendDistributor(
            distributorFactory.createDistribuitor(address(router), rewardtoken)
        );
        // excludeFromReward(deadWallet);
        excludeFromReward(_pair);
        excludeFromReward(address(0));
        excludeFromReward(address(this));
        _rOwned[owner()] = _rTotal;

        isPair[_pair] = true;

        isDividendExempt[_pair] = true;
        isDividendExempt[address(this)] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[marketingWallet] = true;
        _isExcludedFromFee[deadWallet] = true;

        emit Transfer(address(0), owner(), _tTotal);
    }

    receive() external payable {}

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view returns (uint256) {
        if (_isExcluded[account]) {
            return _tOwned[account];
        } else {
            return tokenFromReflection(_rOwned[account]);
        }
    }

    function allowance(address sender, address spender)
        public
        view
        returns (uint256)
    {
        return _allowances[sender][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        returns (bool)
    {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(
            currentAllowance >= subtractedValue,
            "BEP20: decreased allowance below zero"
        );
        _approve(msg.sender, spender, currentAllowance - subtractedValue);

        return true;
    }

    function _approve(
        address sender,
        address spender,
        uint256 amount
    ) private {
        require(sender != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");
        _allowances[sender][spender] = amount;
        emit Approval(sender, spender, amount);
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferRfi)
        public
        view
        returns (uint256)
    {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferRfi) {
            valuesFromGetValues memory s = _getValues(tAmount, true, false);
            return s.rAmount;
        } else {
            valuesFromGetValues memory s = _getValues(tAmount, true, false);
            return s.rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function _reflectRfi(uint256 rRfi, uint256 tRfi) private {
        _rTotal -= rRfi;
        totFeesPaid.rfi += tRfi;
    }

    function _takeBurn(uint256 rBurn, uint256 tBurn) private {
        totFeesPaid.Burn += tBurn;

        if (_isExcluded[deadWallet]) {
            _tOwned[deadWallet] += tBurn;
        }
        _rOwned[deadWallet] += rBurn;
    }

    function _takeMarketing(
        uint256 rMarketing,
        uint256 tMarketing,
        bool isSell
    ) private {
        address receiver = isSell ? address(this) : rewardWallet;
        totFeesPaid.marketing += tMarketing;

        if (_isExcluded[receiver]) {
            _tOwned[receiver] += tMarketing;
        }
        _rOwned[receiver] += rMarketing;
    }

    function _takeTokenRef(
        uint256 rTokenRef,
        uint256 tTokenRef,
        bool isSell
    ) private {
        address receiver = isSell ? address(this) : rewardWallet;
        totFeesPaid.TokenRef += tTokenRef;

        if (_isExcluded[receiver]) {
            _tOwned[receiver] += tTokenRef;
        }
        _rOwned[receiver] += rTokenRef;
    }

    function _getValues(
        uint256 tAmount,
        bool takeFee,
        bool isSell
    ) private view returns (valuesFromGetValues memory to_return) {
        to_return = _getTValues(tAmount, takeFee, isSell);
        (
            to_return.rAmount,
            to_return.rTransferAmount,
            to_return.rRfi,
            to_return.rMarketing
        ) = _getRValues1(to_return, tAmount, takeFee, _getRate());
        (to_return.rTokenRef, to_return.rBurn) = _getRValues2(
            to_return,
            takeFee,
            _getRate()
        );

        return to_return;
    }

    function _getTValues(
        uint256 tAmount,
        bool takeFee,
        bool isSell
    ) private view returns (valuesFromGetValues memory s) {
        if (!takeFee) {
            s.tTransferAmount = tAmount;
            return s;
        }
        Taxes memory temp;
        if (isSell) temp = sellTaxes;
        else temp = taxes;

        s.tRfi = (tAmount * temp.rfi) / 10000;
        s.tMarketing = (tAmount * temp.marketing) / 10000;
        s.tBurn = (tAmount * temp.Burn) / 10000;
        s.tTokenRef = (tAmount * temp.TokenRef) / 10000;
        s.tTransferAmount =
            tAmount -
            s.tRfi -
            s.tMarketing -
            s.tTokenRef -
            s.tBurn;

        return s;
    }

    function _getRValues1(
        valuesFromGetValues memory s,
        uint256 tAmount,
        bool takeFee,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount * currentRate;

        if (!takeFee) {
            return (rAmount, rAmount, 0, 0);
        }

        uint256 rRfi = s.tRfi * currentRate;
        uint256 rMarketing = s.tMarketing * currentRate;
        uint256 rTokenRef = s.tTokenRef * currentRate;
        uint256 rBurn = s.tBurn * currentRate;
        uint256 rTransferAmount = rAmount -
            rRfi -
            rMarketing -
            rTokenRef -
            rBurn;

        return (rAmount, rTransferAmount, rRfi, rMarketing);
    }

    function _getRValues2(
        valuesFromGetValues memory s,
        bool takeFee,
        uint256 currentRate
    ) private pure returns (uint256 rTokenRef, uint256 rBurn) {
        if (!takeFee) {
            return (0, 0);
        }

        rTokenRef = s.tTokenRef * currentRate;
        rBurn = s.tBurn * currentRate;
        return (rTokenRef, rBurn);
    }

    function _getRate() public view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() public view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(
            currentAllowance >= amount,
            "BEP20: transfer amount exceeds allowance"
        );
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, currentAllowance - amount);

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(to != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(
            amount <= balanceOf(from),
            "You are trying to transfer more than your balance"
        );

        bool takeFee = true;
        bool isSell = false;

        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) takeFee = false;
        if (isPair[to]) isSell = true;

        valuesFromGetValues memory s = _txdata(amount, takeFee, isSell);

        if (s.rRfi > 0 || s.tRfi > 0) _reflectRfi(s.rRfi, s.tRfi);
        if (s.rMarketing > 0 || s.tMarketing > 0)
            _takeMarketing(s.rMarketing, s.tMarketing, isSell);
        if (s.rTokenRef > 0 || s.tTokenRef > 0)
            _takeTokenRef(s.rTokenRef, s.tTokenRef, isSell);
        if (s.rBurn > 0 || s.tBurn > 0) {
            _takeBurn(s.rBurn, s.tBurn);
        }

        Taxes memory fees = isSell ? sellTaxes : taxes;

        uint256 swapAmount = (fees.marketing + fees.TokenRef) > 0
            ? (amount * (fees.marketing + fees.TokenRef)) / 10000
            : 0;

        uint256 burnAmount = fees.Burn > 0 ? (amount * fees.Burn) / 10000 : 0;

        if (swapEnabled && !isPair[from] && takeFee) {
            contractSwap(amount, sellTaxes);
        }
        _itx(from, to, amount, s);

        if (!isDividendExempt[from]) {
            try distributor.setShare(from, balanceOf(from)) {} catch {}
        }

        if (!isDividendExempt[to]) {
            try distributor.setShare(to, balanceOf(to)) {} catch {}
        }
        try distributor.process(distributorGas) {} catch {}
        if (swapAmount > 0 && takeFee)
            emit Transfer(
                from,
                isSell ? address(this) : rewardWallet,
                swapAmount
            );
        if (burnAmount > 0 && takeFee)
            emit Transfer(from, deadWallet, burnAmount);
        emit Transfer(from, to, s.tTransferAmount);
    }

    function burn(uint256 amount) external {
        require(amount > 0, "You need to burn more than 0.");
        valuesFromGetValues memory s = _getValues(amount, false, false);
        _itx(msg.sender, deadWallet, amount, s);
        emit Transfer(msg.sender, deadWallet, amount);
    }

    function _itx(
        address from,
        address to,
        uint256 amount,
        valuesFromGetValues memory s
    ) internal {
        if (_isExcluded[from]) {
            _tOwned[from] = _tOwned[from] - amount;
        }
        if (_isExcluded[to]) {
            _tOwned[to] = _tOwned[to] + s.tTransferAmount;
        }
        _rOwned[from] = _rOwned[from] - s.rAmount;
        _rOwned[to] = _rOwned[to] + s.rTransferAmount;
    }

    function _txdata(
        uint256 tAmount,
        bool takeFee,
        bool isSell
    ) private view returns (valuesFromGetValues memory s) {
        valuesFromGetValues memory ss = _getValues(tAmount, takeFee, isSell);
        return (ss);
    }

    function getamount(uint256 amount, address[] memory path)
        internal
        view
        returns (uint256)
    {
        return router.getAmountsOut(amount, path)[1];
    }

    function contractSwap(uint256 tAmount, Taxes memory temp)
        private
        lockTheSwap
    {
        uint256 amountToSwap = (temp.marketing + temp.TokenRef) > 0
            ? (tAmount * (temp.marketing + temp.TokenRef)) / 10000
            : 0;
        amountToSwap = balanceOf(address(this)) >= amountToSwap
            ? amountToSwap
            : balanceOf(address(this));

        _approve(address(this), address(router), balanceOf(address(this)));

        if (amountToSwap > 0) {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = router.WETH();

            uint256 amountBNBMarketing = temp.marketing > 0
                ? getamount((tAmount * (temp.marketing)) / 10000, path)
                : 0;
            uint256 amountBNBRef = temp.TokenRef > 0
                ? getamount((tAmount * (temp.TokenRef)) / 10000, path)
                : 0;

            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                amountToSwap,
                0,
                path,
                address(this),
                block.timestamp
            );

            if (amountBNBRef > 0) {
                try distributor.deposit{value: amountBNBRef}() {} catch {}
            }
            bool success;
            if (amountBNBMarketing > 0) {
                (success, ) = payable(marketingWallet).call{
                    value: address(this).balance
                }("");
                // payable(marketingFeeReceiver).transfer(amountBNBMarketing);
            }
        }
    }

    function claimDividend() external {
        distributor.claimDividend(msg.sender);
    }

    function getUnpaidEarnings(address shareholder)
        public
        view
        returns (uint256)
    {
        return distributor.getUnpaidEarnings(shareholder);
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is not excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function setFees(
        uint256 _rfiFee,
        uint256 _marketingFee,
        uint256 _burnFee,
        uint256 _TokenRefFee,
        uint256 _sellRfiFee,
        uint256 _sellMarketingFee,
        uint256 _sellBurnFee,
        uint256 _sellTokenRefFee
    ) public onlyOwner {
        taxes = Taxes(_rfiFee, _marketingFee, _burnFee, _TokenRefFee);
        sellTaxes = Taxes(
            _sellRfiFee,
            _sellMarketingFee,
            _sellBurnFee,
            _sellTokenRefFee
        );
    }

    function excludeFromFee(address account, bool io) public onlyOwner {
        _isExcludedFromFee[account] = io;
    }

    function setPair(address pairAdress, bool io) public onlyOwner {
        isPair[pairAdress] = io;
    }

    function updateMarketingWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Fee Address cannot be zero address");
        marketingWallet = newWallet;
    }

    function updateRewardWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Fee Address cannot be zero address");
        rewardWallet = newWallet;
    }

    function updateSwapEnabled(bool _enabled) external onlyOwner {
        swapEnabled = _enabled;
    }

    function rescueBNB(uint256 weiAmount) external onlyOwner {
        require(address(this).balance >= weiAmount, "insufficient BNB balance");
        bool success;
        (success, ) = payable(msg.sender).call{value: weiAmount}("");
    }

    function rescueAnyBEP20Tokens(
        address _tokenAddr,
        address _to,
        uint256 _amount
    ) public onlyOwner {
        IBEP20(_tokenAddr).transfer(_to, _amount);
    }

    function setDividendExempt(address account, bool b) public onlyOwner {
        isDividendExempt[account] = b;
    }

    function setDistributionCriteria(
        uint256 _minPeriod,
        uint256 _minDistribution
    ) external onlyOwner {
        distributor.setDistributionCriteria(_minPeriod, _minDistribution);
    }

    function setDistributorSettings(uint256 gas) external onlyOwner {
        require(gas < 3000000);
        distributorGas = gas;
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
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

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
}
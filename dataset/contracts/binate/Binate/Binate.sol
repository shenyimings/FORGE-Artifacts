// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SafeMath {
    
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

library EnumerableSet {
    struct Set {
        bytes32[] _values;
        mapping(bytes32 => uint256) _indexes;
    }

    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    function _remove(Set storage set, bytes32 value) private returns (bool) {
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];
                set._values[toDeleteIndex] = lastValue;
                set._indexes[lastValue] = valueIndex;
            }

            set._values.pop();

            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    function _contains(Set storage set, bytes32 value)
        private
        view
        returns (bool)
    {
        return set._indexes[value] != 0;
    }

    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    function _at(Set storage set, uint256 index)
        private
        view
        returns (bytes32)
    {
        return set._values[index];
    }

    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    function adds(AddressSet storage set, address value)
        internal
        returns (bool)
    {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    function remove(AddressSet storage set, address value)
        internal
        returns (bool)
    {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value)
        internal
        view
        returns (bool)
    {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    function at(AddressSet storage set, uint256 index)
        internal
        view
        returns (address)
    {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    function values(AddressSet storage set)
        internal
        view
        returns (address[] memory)
    {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

interface IERC20 {
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

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint256 private _totalBurnt;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function totalBurnt() public view returns (uint256) {
        return _totalBurnt;
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }


     function _mint(address account, uint256 value) internal {
        require(account != address(0), 'account cannot be address(0)');

        _totalSupply = _totalSupply.add(value);
        _balances[account] = _balances[account].add(value);
        emit Transfer(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        require(account != address(0), 'account cannot be address(0)');

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);

        _totalBurnt = _totalBurnt.add(value);

        emit Transfer(account, address(0), value);
    }

    function _burnFrom(address account, uint256 value) internal {
        _allowances[account][msg.sender] = _allowances[account][msg.sender].sub(value);
        _burn(account, value);
    }

    function _createInitialSupply(address account, uint256 amount)
        internal
        virtual
    {
        require(account != address(0), "ERC20: to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() external virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IDexRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

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

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IDexFactory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IDexPair {
    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

abstract contract ConvertInterface {
    function totalSupply() public view virtual returns (uint256);

    function balanceOf(address who) external view virtual returns (uint256);

    function sownFromBnt(address to, uint256 value) public virtual returns (bool);

    function bntFromSown(address tokensOwner, uint256 value) external virtual returns (bool);

    function transferClaimedToken(address to, uint256 tokenAmount) public virtual returns (bool);

    function isDividendExempt(address who) public view virtual returns (bool);
}

abstract contract DistributorInterface {
    function bntSetShare(address shareholder, uint256 amount) external virtual;
    function bntProcess(uint256 gas) external virtual;
}

contract Binate is ERC20, Ownable {
    using SafeMath for uint256;

    event RecordPrice(uint256 indexed epoch, uint256 currentPrice);

    IDexRouter public dexRouter;
    address public lpPair;

    uint256 public tradingActiveBlock = 0; // 0 means normal transfer is not yet active
    uint256 public buyAndSellBlock = 0; // 0 means buying and selling is not yet active
    uint256 public blockForStarting;
    uint256 public blockForBuySell;

    bool public tradingActive = false; // normal transfer is not yet active

    bool public haveTokenToClaim = false; 

    bool public buyAndSell = false; // buying and selling is not yet active

    uint256 private constant INITIALPRICE = 100000;

    uint256 public constant PRICE_DECIMALS = 10**5;

    uint256 public tokenAmount = 1 * 2 * 1e18;

    uint256 public minClaimAmount = 1 * 50 * 1e18;

    uint256 public claimFreq = 3600; //1 hours

    uint256 timeOfLastClaim;

    uint256 private constant MAX_PRICE = 10000000;

    bool public _priceGrowth;
    uint256 public _initGrowthStartTime;
    uint256 public _lastGrowthTime;
    uint256 public _currentPrice;

    address public sownContract;
    address public distributorContract;
    uint256 public quarantineBalance;
    uint256 public lastBalancedHour;
    uint256 distributorGas = 500000;

    /******************/

    // exlcude lp, presale and admin address from limits
    mapping(address => bool) public _isExcludedFromLimits; //Allow to transfer token before transfer is active, 4 presale distributor

    // store addresses for automatic market maker pairs.
    mapping(address => bool) public automatedMarketMakerPairs;

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event EnabledTrading();
    event EnabledBuyandSell();
    event EnabledMustHaveTokenToClaim();

    event ExcludeFromLimits(address indexed account, bool isExcluded);

    event TransferForeignToken(address token, uint256 amount);

    event BalanceNetwork(uint256 indexed currentHour, uint256 bntAmountBurnt);

    event ConvertToSown(
        address indexed converter,
        uint256 bntAmountSent,
        uint256 sownAmountReceived
    );

    event ConvertToBnt(
        address indexed converter,
        uint256 sownAmountSent,
        uint256 bntAmountReceived
    );

    event GetSown(address receiver, uint256 amount);

    event BurnSown(uint256 amountBurnt);

    event TransferClaimedToken(address receiver, uint256 amount);

    event QuarantineBalanceBurnt(uint256 amount);

    event LostTokensBurnt(uint256 amount);

    constructor(address _dexRouter, address _sownContract) payable ERC20("Binate Core", "BNT") {
        address newOwner = msg.sender;

        // PCS Main
        dexRouter = IDexRouter(_dexRouter);    

        // create pair
        lpPair = IDexFactory(dexRouter.factory()).createPair(
            address(this),
            dexRouter.WETH()
        );

        _setAutomatedMarketMakerPair(address(lpPair), true);

        uint256 totalSupply = 1 * 10e7 * 1e18;
        _initGrowthStartTime = block.timestamp;
        _priceGrowth = false;
        sownContract = _sownContract;
        _currentPrice = INITIALPRICE;


        excludeFromLimits(newOwner, true);
        excludeFromLimits(msg.sender, true);
        excludeFromLimits(address(this), true);
        excludeFromLimits(address(0xdead), true);
        excludeFromLimits(address(dexRouter), true);

        _createInitialSupply(newOwner, totalSupply); 

        transferOwnership(newOwner);
    }

    receive() external payable {}

    modifier onlySown() {
        require(msg.sender == sownContract, 'CALLER_MUST_BE_Sown_CONTRACT_ONLY');
        _;
    }
   
    
    // Trading cannot be stopped once started
    function enableTrading(uint256 blocksStarted) external onlyOwner {
        require(blockForStarting == 0);
        _priceGrowth = true;
        _lastGrowthTime = block.timestamp;
        tradingActive = true;
        tradingActiveBlock = block.number;
        blockForStarting = tradingActiveBlock + blocksStarted;
        emit EnabledTrading();
    }

    // Buying and Selling cannot be stopped once started
    function enableBuyandSell(uint256 blocksStarted) external onlyOwner {
        require(blockForBuySell == 0);
        buyAndSell = true;
        buyAndSellBlock = block.number;
        blockForBuySell = buyAndSellBlock + blocksStarted;
        emit EnabledBuyandSell();
    }


     // Enabling Only those that have BNT token to claim free token
    function enableMustHaveTokenToClaim(uint256 minHoldAmount, uint256 claimamount, bool enable) external onlyOwner {
        minClaimAmount = minHoldAmount;
        tokenAmount = claimamount;
        haveTokenToClaim = enable;
        emit EnabledMustHaveTokenToClaim();
    }


    function setAutomatedMarketMakerPair(address pair, bool value)
        external
        onlyOwner
    {
        require(
            pair != lpPair,
            "The pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }
   

    function excludeFromLimits(address account, bool excluded) public onlyOwner {
        _isExcludedFromLimits[account] = excluded;
        emit ExcludeFromLimits(account, excluded);
    }


    function grow() internal {
    
        uint256 growRate;
        uint256 deltaTimeFromInit = block.timestamp - _initGrowthStartTime;
        uint256 deltaTime = block.timestamp - _lastGrowthTime;
        uint256 times = deltaTime.div(1 hours);
        uint256 epoch = times.mul(60);

        if (deltaTimeFromInit < (365 days)) {
            growRate = 11;
        } else if (deltaTimeFromInit >= (365 days) && deltaTimeFromInit < (730 days)) {
            growRate = 5;
        } else if (deltaTimeFromInit >= (730 days) && deltaTimeFromInit < (1095 days) ) {
            growRate = 2;
        } else if (deltaTimeFromInit >= (1095 days)) {
            growRate = 1;
        }

        for (uint256 i = 0; i < times; i++) {
            _currentPrice = _currentPrice
                .mul((PRICE_DECIMALS).add(growRate))
                .div(PRICE_DECIMALS);
        }

        _lastGrowthTime = _lastGrowthTime.add(times.mul(1 hours));

        emit RecordPrice(epoch, _currentPrice);
    }


      /**
     * Public function that burns BNT from quarantine
     * according to the burnQuarantine() formula.
     * Needed for economic logic of BNT token.
     */
    function balanceNetwork() external returns (bool _success) {
        require(lastBalancedHour < getCurrentHour(), 'Network already balanced in this hour');

        lastBalancedHour = getCurrentHour();

        timeOfLastClaim = block.timestamp;

        uint256 _bntBurnt = _burnQuarantined();

        emit BalanceNetwork(getCurrentHour(), _bntBurnt);
        return true;
    }


     /**
     * Internal function that burns BNT from quarantine
     * according to the burnQuarantine() formula.
     * Needed for economic logic of BNT token.
     */
    function reBalance() internal returns (bool _success) {
        require(lastBalancedHour < getCurrentHour(), 'Network already balanced in this hour');

        lastBalancedHour = getCurrentHour();

        timeOfLastClaim = block.timestamp;

        uint256 _bntBurnt = _burnQuarantined();

        emit BalanceNetwork(getCurrentHour(), _bntBurnt);
        return true;
    }

    /**
     * Public function that allows users to convert Sown to BNT.
     * Amount of BNT received depends on the current price of BNT.
     */
    function convertToBnt(uint256 _sownAmount) external returns (bool _success) {
        require(_currentPrice != 0, 'Something is wrong with the price');

        require(
            ConvertInterface(sownContract).balanceOf(msg.sender) >= _sownAmount,
            'INSUFFICIENT_BALANCE'
        );

        require(
            ConvertInterface(sownContract).bntFromSown(msg.sender, _sownAmount),
            'BURNING_FAILED'
        );

        if (shouldGrow()) {
           grow();
        }

        emit BurnSown(_sownAmount);

        uint256 _bntToDequarantine =
        (_sownAmount.mul(PRICE_DECIMALS)).div(_currentPrice);

        quarantineBalance = quarantineBalance.sub(_bntToDequarantine);
        require(this.transfer(msg.sender, _bntToDequarantine), 'CONVERT_TO_BNT_FAILED');

        uint256 _balancesfrom = ConvertInterface(sownContract).balanceOf(msg.sender);
        bool isDividendExempt = ConvertInterface(sownContract).isDividendExempt(msg.sender);

        if(!isDividendExempt){ try DistributorInterface(distributorContract).bntSetShare(msg.sender, _balancesfrom) {} catch {} }

        try DistributorInterface(distributorContract).bntProcess(distributorGas) {} catch {}

        emit ConvertToBnt(msg.sender, _sownAmount, _bntToDequarantine);
        return true;
    }


     /**
     * Public function that allows users to convert BNT to Sown.
     * Amount of Sown received depends on the current price of BNT.
     */
    function convertToSown(uint256 _bntAmount) external returns (uint256) {
        require(_currentPrice != 0, 'Something is wrong with the price');

        require(balanceOf(msg.sender) >= _bntAmount, 'INSUFFICIENT_BALANCE');

        quarantineBalance = quarantineBalance.add(_bntAmount);
        require(transfer(address(this), _bntAmount), 'TRANSFER_FAILED');

        if (shouldGrow()) {
           grow();
        }

        uint256 _sownToIssue =
            (_bntAmount.mul(_currentPrice)).div(PRICE_DECIMALS);

        require(
            ConvertInterface(sownContract).sownFromBnt(msg.sender, _sownToIssue),
            'CONVERT_TO_SOWN_FAILED'
        );

        uint256 _balancesfrom = ConvertInterface(sownContract).balanceOf(msg.sender);
        bool isDividendExempt = ConvertInterface(sownContract).isDividendExempt(msg.sender);

        if(!isDividendExempt){ try DistributorInterface(distributorContract).bntSetShare(msg.sender, _balancesfrom) {} catch {} }

        try DistributorInterface(distributorContract).bntProcess(distributorGas) {} catch {}

        emit GetSown(msg.sender, _sownToIssue);

        emit ConvertToSown(msg.sender, _bntAmount, _sownToIssue);
        return _sownToIssue;
    }


     /**
     * Function is needed to burn lost tokens that probably were sent
     * to the contract address by mistake.
     */
    function burnLostTokens() external onlyOwner() returns (bool _success) {
        uint256 _amount = balanceOf(address(this)).sub(quarantineBalance);

        _burn(address(this), _amount);

        emit LostTokensBurnt(_amount);
        return true;
    }


    // External function that updates BNT price, can only be called by Sown Contract.
    function updateFromSown(uint256 gas) external onlySown {
         if (shouldGrow()) {
           grow();
         }
    }


    /**
     * Internal function that implements logic to burn a part of BNT tokens on quarantine.
     * Formula is based on network capitalization rules -
     * Network capitalization of quarantined BNT must be equal to
     * network capitalization of SOWN
     * calculated as (q * pBNT - c * pSOWN) / pBNT
     * where:
     * q - quarantined BNT,
     * pBNT - current bntPrice
     * c - current sown supply
     * pSOWN - SOWN pegged price ($1 USD fixed conversion price)
     */
    function _burnQuarantined() internal returns (uint256) {
        uint256 _quarantined = quarantineBalance;
                _currentPrice = _currentPrice;
        uint256 _sownSupply = ConvertInterface(sownContract).totalSupply();

        uint256 _bntToBurn =
            ((((_quarantined.mul(_currentPrice)).div(PRICE_DECIMALS)).sub(_sownSupply)).mul(PRICE_DECIMALS))
                .div(_currentPrice);

        quarantineBalance = quarantineBalance.sub(_bntToBurn);

        uint256 forclaiming = _bntToBurn.mul(2).div(100);

        _bntToBurn = _bntToBurn - forclaiming;

        _burn(address(this), _bntToBurn);

        _transfer(address(this), sownContract, forclaiming);

        emit QuarantineBalanceBurnt(_bntToBurn);
        return _bntToBurn;
    }



    /**
     * Public function that allows anyone to Claim part of the about to be burnt tokens.
     * Thereby helping in updating the price.
     */
    function claimToken() external returns (bool _success) {

        if(haveTokenToClaim && (balanceOf(msg.sender) < minClaimAmount)){
            return false;
        }

        require(lastBalancedHour < getCurrentHour(), 'Token_Is_Already_Claimed_In_This_Hour');

        if (shouldGrow()) {
           grow();
         }

        reBalance();

        require(
            ConvertInterface(sownContract).transferClaimedToken(msg.sender, tokenAmount),
            'Claim_Faild'
        );

        emit TransferClaimedToken(msg.sender, tokenAmount);
        return true;
    }





    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "ERC20: transfer must be greater than 0");

        if (shouldGrow()) {
           grow();
        }

        if (!tradingActive) {
            require(
                _isExcludedFromLimits[from] || _isExcludedFromLimits[to],
                "Trading has not started."
            );
        }

        if (automatedMarketMakerPairs[from] || automatedMarketMakerPairs[to]) { // buy or sell
            // not yet active
            if (!buyAndSell) {
                return;
            }
        }

        super._transfer(from, to, amount);
    }


     function shouldGrow() internal view returns (bool) {
        return
            _priceGrowth &&
            (_currentPrice < MAX_PRICE) &&
            msg.sender != lpPair  &&
            block.timestamp >= (_lastGrowthTime + 1 hours);
    }


    function setPriceGrowth(bool _flag) external onlyOwner {
        if (_flag) {
            _priceGrowth = _flag;
            _lastGrowthTime = block.timestamp;
        } else {
            _priceGrowth = _flag;
        }
    }


    // Utility function that returns the timer for claiming rewards
    function claimRewardsTimer()
        public
        view
        returns (uint256 _timer)
    {
        if (timeOfLastClaim + claimFreq <= block.timestamp) {
            return 0;
        } else {
            return
                (timeOfLastClaim + claimFreq) -
                block.timestamp;
        }
    }

    // Utility function that returns the timer for next price increase
    function nextPriceIncrease()
        public
        view
        returns (uint256 _timer)
    {
        if (_lastGrowthTime + claimFreq <= block.timestamp) {
            return 0;
        } else {
            return
                (_lastGrowthTime + claimFreq) -
                block.timestamp;
        }
    }


    function currentPrice() external view returns (uint256) {
        return _currentPrice;
    }

    function getCurrentTime() public view virtual returns (uint256) {
        return block.timestamp;
    }

    function getCurrentHour() public view returns (uint256) {
        return getCurrentTime().div(1 hours);
    }


    function setSownContract(address _sownContractAddress) external onlyOwner() {
        require(_sownContractAddress != address(0), 'SOWN_CONTRACT_CANNOTBE_NULL_ADDRESS');
        sownContract = _sownContractAddress;
    }

    function setdistributorContract(address _distributorContractAddress) external onlyOwner() {
        require(_distributorContractAddress != address(0), 'distributorContract_CANNOTBE_NULL_ADDRESS');
        distributorContract = _distributorContractAddress;
    }


    function transferForeignToken(address _token, address _to)
        external
        onlyOwner
        returns (bool _sent)
    {
        require(_token != address(0));
        require(_token != address(this));
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        _sent = IERC20(_token).transfer(_to, _contractBalance);
        emit TransferForeignToken(_token, _contractBalance);
    }

    // withdraw ETH
    function withdrawStuckETH() external onlyOwner {
        bool success;
        (success, ) = address(owner()).call{value: address(this).balance}("");
    }

}
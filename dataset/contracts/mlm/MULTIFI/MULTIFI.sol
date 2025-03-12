// File: contracts\baseLibrary.sol

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

library SafeMathInt {
    int256 private constant MIN_INT256 = int256(1) << 255;
    int256 private constant MAX_INT256 = ~(int256(1) << 255);

    function mul(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a * b;
        require(c != MIN_INT256 || (a & MIN_INT256) != (b & MIN_INT256));
        require((b == 0) || (c / b == a));
        return c;
    }

    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != -1 || a != MIN_INT256);
        return a / b;
    }

    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a));
        return c;
    }

    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a));
        return c;
    }

    function abs(int256 a) internal pure returns (int256) {
        require(a != MIN_INT256);
        return a < 0 ? -a : a;
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IPancakeSwapPair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

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

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

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

interface IPancakeSwapRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

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

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
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

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IPancakeSwapFactory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

contract Ownable {
    address private _owner;
    event OwnershipRenounced(address indexed previousOwner);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _owner = msg.sender;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipRenounced(_owner);
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract IERC20Metadata is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
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
}

interface _MULTIFI_SERVICES {
    function setMultifiData(uint256 initBlock) external;

    function afterRebase() external;
}

interface _MULTIFI_SERVICE {
    function setServiceData(address multifiAddress) external;
}

interface _MULTIFI {
    function getGonsPerFragment() external view returns (uint256);
}

contract MULTIFI is IERC20Metadata, Ownable, _MULTIFI {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event ReferralReward(address _address, uint256 amount);
    event ReferralRewardBNB(address _address, uint256 amount);
    event SetReferral(address _address, address _referral);
    modifier validRecipient(address to) {
        require(to != address(0x0));
        _;
    }
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }
    IPancakeSwapPair public pairContract;
    mapping(address => bool) _isFeeExempt;
    uint256 internal constant DECIMALS = 10;
    uint256 constant MAX_UINT256 = ~uint256(0);
    uint8 constant RATE_DECIMALS = 7;
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY =
        1.4 * 10**6 * 10**DECIMALS;
    uint256 public constant treasuryFee = 25;
    uint256 public constant insuranceFundFee = 25;
    uint256 public constant lotteryFee = 10;
    uint256 public constant referralFee = 40;
    uint256 public constant noReferralFee = 100;
    uint256 public totalFee =
        treasuryFee.add(insuranceFundFee).add(lotteryFee).add(referralFee);
    uint256 public constant feeDenominator = 1000;
    address public treasuryReceiver =
        0xe4AC1174394c7C91Bc475dFEDed8359bC1107ADD;
    address public insuranceFundReceiver =
        0x1EEC091E91A5f1bfF9EA6fD4Cf84A59eF7198ADD;
    address public serviceHolder = 0x000000000000000000000000000000000BADbaBe;
    address public lotteryReceiver = 0x000000000000000000000000000000000001babe;
    address public referralHolder = 0x000000000000000000000000000000000002BaBe;
    address public pairAddress;
    IPancakeSwapRouter public router;
    address public pair;
    bool public inSwap = false;
    uint256 private constant TOTAL_GONS =
        MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);
    uint256 private constant MAX_SUPPLY = 1.5 * 10**10 * 10**DECIMALS;
    bool public _autoRebase = false;
    bool public _autoSwapBack = false;
    uint256 public _rebaseStartTime;
    uint256 public _lastAddLiquidityTime;
    uint256 public _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
    uint256 private _gonsPerFragment;
    uint256 public _rebaseEpoch = 0;
    uint256 public stepReferralAmount = 10**18;
    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowedFragments;
    mapping(address => bool) public blacklist;
    mapping(address => bool) public countHolders;
    mapping(address => uint256) public referralBalance;
    mapping(address => mapping(address => uint256)) public referralFrom;
    mapping(address => uint256) public referralLv;
    mapping(address => address) public referralAddress;
    uint256 _initBlock;
    uint256 public numberOfBlocksPerLotteryCycle = 28800;
    uint256 holders = 3;
    bool _startRebase = false;
    bool isSetServicesContract = false;
    _MULTIFI_SERVICES servicesContract;

    constructor() IERC20Metadata("MULTIFI", "MLM", uint8(DECIMALS)) Ownable() {
        router = IPancakeSwapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IPancakeSwapFactory(router.factory()).createPair(
            router.WETH(),
            address(this)
        );
        _allowedFragments[address(this)][address(router)] = MAX_UINT256;
        pairAddress = pair;
        pairContract = IPancakeSwapPair(pair);
        _gonBalances[serviceHolder] = TOTAL_GONS.div(7).mul(2);
        _gonBalances[treasuryReceiver] = TOTAL_GONS.sub(
            _gonBalances[serviceHolder]
        );
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
        _rebaseStartTime = block.timestamp;
        _lastAddLiquidityTime = block.timestamp;
        _isFeeExempt[treasuryReceiver] = true;
        _isFeeExempt[address(this)] = true;
        _initBlock = block.number;
        emit Transfer(
            address(0x0),
            treasuryReceiver,
            _gonBalances[treasuryReceiver].div(_gonsPerFragment)
        );
        emit Transfer(
            address(0x0),
            serviceHolder,
            _gonBalances[serviceHolder].div(_gonsPerFragment)
        );
    }

    function startRebase() external onlyOwner {
        require(!_startRebase);
        _startRebase = true;
        _rebaseStartTime = block.timestamp;
        _autoRebase = true;
    }

    function getGonsPerFragment() external view override returns (uint256) {
        return _gonsPerFragment;
    }

    function setServicesContract(address _contract) external onlyOwner {
        require(!isSetServicesContract && isContract(_contract));
        servicesContract = _MULTIFI_SERVICES(_contract);
        servicesContract.setMultifiData(_initBlock);
        _gonBalances[address(servicesContract)] = _gonBalances[serviceHolder];
        _gonBalances[serviceHolder] = 0;
        isSetServicesContract = true;
    }

    function setStepReferralAmount(uint256 amount) public onlyOwner {
        require(amount > 0);
        stepReferralAmount = amount;
    }

    function _rebase() internal {
        if (!shouldRebase()) return;
        if (inSwap) return;
        uint256 rebaseRate;
        uint256 deltaTimeFromInit = block.timestamp - _rebaseStartTime;
        uint256 epoch = currentRebaseEpoch();
        uint256 times = epoch - _rebaseEpoch;
        if (deltaTimeFromInit <= (365 days)) {
            rebaseRate = 2500;
        } else if (deltaTimeFromInit >= (5 * 365 days)) {
            rebaseRate = 14;
        } else {
            rebaseRate = 20;
        }
        for (uint256 i = 0; i < times; i++) {
            _totalSupply = _totalSupply
                .mul((10**RATE_DECIMALS).add(rebaseRate))
                .div(10**RATE_DECIMALS);
        }
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
        pairContract.sync();
        _rebaseEpoch = epoch;
        if (isSetServicesContract) {
            servicesContract.afterRebase();
        }
        emit LogRebase(epoch, _totalSupply);
    }

    function currentRebaseEpoch() public view returns (uint256) {
        return (block.timestamp - _rebaseStartTime).div(15 minutes);
    }

    function timeToNextEpoch() public view returns (uint256) {
        return
            _rebaseStartTime +
            (currentRebaseEpoch() + 1).mul(15 minutes) -
            block.timestamp;
    }

    function shouldRebase() internal view returns (bool) {
        return
            _startRebase &&
            _autoRebase &&
            (_totalSupply < MAX_SUPPLY) &&
            msg.sender != pair &&
            !inSwap &&
            currentRebaseEpoch() > _rebaseEpoch;
    }

    function transfer(address to, uint256 value)
        external
        override
        validRecipient(to)
        returns (bool)
    {
        _transferFrom(msg.sender, to, value);
        return true;
    }

    function manualRebase() external {
        require(shouldRebase());
        _rebase();
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override validRecipient(to) returns (bool) {
        if (_allowedFragments[from][msg.sender] != MAX_UINT256) {
            _allowedFragments[from][msg.sender] = _allowedFragments[from][
                msg.sender
            ].sub(value, "");
        }
        _transferFrom(from, to, value);
        return true;
    }

    function _basicTransfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        uint256 gonAmount = amount.mul(_gonsPerFragment);
        _gonBalances[from] = _gonBalances[from].sub(gonAmount);
        _gonBalances[to] = _gonBalances[to].add(gonAmount);
        return true;
    }

    function addReferral(address _referral) external {
        require(
            referralAddress[msg.sender] == address(0) &&
                !isContract(_referral) &&
                _referral != msg.sender &&
                referralLv[_referral] > 0
        );
        bool flag = true;
        address _address = _referral;
        for (uint256 i = 0; i < 15; i++) {
            if (referralAddress[_address] == address(0)) {
                break;
            } else if (referralAddress[_address] == msg.sender) {
                flag = false;
                break;
            } else {
                _address = referralAddress[_address];
            }
        }
        require(flag);
        referralAddress[msg.sender] = _referral;
        emit SetReferral(msg.sender, _referral);
    }

    function referralBalanceOf(address _who) public view returns (uint256) {
        return referralBalance[_who].div(_gonsPerFragment);
    }

    function claimReferralRewardBNB() external {
        require(referralBalance[msg.sender] > 0);
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        uint256 balanceBefore = msg.sender.balance;
        _gonBalances[referralHolder] = _gonBalances[referralHolder].sub(
            referralBalance[msg.sender]
        );
        _gonBalances[address(this)] = _gonBalances[address(this)].add(
            referralBalance[msg.sender]
        );
        router.swapExactTokensForETH(
            referralBalance[msg.sender].div(_gonsPerFragment),
            0,
            path,
            msg.sender,
            block.timestamp
        );
        referralBalance[msg.sender] = 0;
        emit ReferralRewardBNB(
            msg.sender,
            msg.sender.balance.sub(balanceBefore)
        );
    }

    function lvOf(address _who) external view returns (uint256) {
        return referralLv[_who];
    }

    function claimReferralReward() external {
        require(referralBalance[msg.sender] > 0);
        _gonBalances[referralHolder] = _gonBalances[referralHolder].sub(
            referralBalance[msg.sender]
        );
        _gonBalances[msg.sender] = _gonBalances[msg.sender].add(
            referralBalance[msg.sender]
        );
        reCheckLv(msg.sender, true);
        emit ReferralReward(
            msg.sender,
            referralBalance[msg.sender].div(_gonsPerFragment)
        );
        referralBalance[msg.sender] = 0;
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        require(!blacklist[sender] && !blacklist[recipient]);
        if (!countHolders[sender]) {
            countHolders[sender] = true;
            holders = holders.add(1);
        }
        if (!countHolders[recipient]) {
            countHolders[recipient] = true;
            holders = holders.add(1);
        }
        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }
        _rebase();

        if (shouldSwapBack()) {
            _swapBack();
        }
        uint256 gonAmount = amount.mul(_gonsPerFragment);
        _gonBalances[sender] = _gonBalances[sender].sub(gonAmount);
        uint256 gonAmountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, recipient, gonAmount)
            : gonAmount;
        _gonBalances[recipient] = _gonBalances[recipient].add(
            gonAmountReceived
        );
        reCheckLv(sender, false);
        reCheckLv(recipient, true);
        emit Transfer(
            sender,
            recipient,
            gonAmountReceived.div(_gonsPerFragment)
        );
        return true;
    }

    function reCheckLv(address _address, bool isBuyer) internal {
        uint256 price = tokenStepPrice();
        uint256 balance = balanceOf(_address);
        uint256 lv = price != 0 ? balance.div(price) : 0;
        if (isBuyer) {
            if (lv > referralLv[_address]) {
                referralLv[_address] = lv;
            }
        } else {
            referralLv[_address] = lv;
        }
    }

    function takeFee(
        address sender,
        address recipient,
        uint256 gonAmount
    ) internal returns (uint256) {
        address feeAddress = sender;
        if (sender == pair) {
            feeAddress = recipient;
        }
        uint256 _totalFee = totalFee;
        address _referralAddress = referralAddress[feeAddress];
        address _address = feeAddress;
        uint256 referralGon = gonAmount.mul(referralFee).div(feeDenominator);
        _gonBalances[address(this)] = _gonBalances[address(this)].add(
            gonAmount.mul(treasuryFee.add(insuranceFundFee)).div(feeDenominator)
        );
        address _service = lotteryReceiver;
        if (isSetServicesContract) {
            _service = address(servicesContract);
        }
        _gonBalances[_service] = _gonBalances[_service].add(
            gonAmount.mul(lotteryFee).div(feeDenominator)
        );
        uint256 _referralGon = referralGon;
        if (_referralAddress == address(0)) {
            _totalFee = _totalFee.add(noReferralFee);
            referralGon = gonAmount.mul(referralFee.add(noReferralFee)).div(
                feeDenominator
            );
            _referralGon = referralGon;
        } else {
            uint256 count = 1;
            uint256 _lv = referralLv[_referralAddress];
            uint256 _halfReferralGon = _referralGon.div(2);
            while (
                _referralAddress != address(0) &&
                count < 16 &&
                _lv >= count &&
                _halfReferralGon > 0
            ) {
                referralBalance[_referralAddress] = referralBalance[
                    _referralAddress
                ].add(_halfReferralGon);
                referralFrom[_referralAddress][_address] = referralFrom[
                    _referralAddress
                ][_address].add(_halfReferralGon);
                count = count.add(1);
                _address = _referralAddress;
                _referralAddress = referralAddress[_referralAddress];
                _lv = referralLv[_referralAddress];
                _referralGon = _referralGon.sub(_halfReferralGon);
                _halfReferralGon = _halfReferralGon.div(2);
            }
        }
        _gonBalances[referralHolder] = _gonBalances[referralHolder].add(
            referralGon
        );
        if (_referralGon > 0) {
            referralBalance[treasuryReceiver] = referralBalance[
                treasuryReceiver
            ].add(_referralGon);
        }
        uint256 feeAmount = gonAmount.div(feeDenominator).mul(_totalFee);
        emit Transfer(sender, address(this), feeAmount.div(_gonsPerFragment));
        return gonAmount.sub(feeAmount);
    }

    function tokenStepPrice() public view returns (uint256) {
        (uint256 a0, uint256 a1, ) = pairContract.getReserves();
        uint256 price = 0;
        if (pairContract.token0() == address(this)) {
            price = a1 != 0 ? a0.mul(stepReferralAmount).div(a1) : 0;
        } else {
            price = a0 != 0 ? a1.mul(stepReferralAmount).div(a0) : 0;
        }
        return price;
    }

    function _sellToken(uint256 amountToSwap) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        uint256 balanceBefore = address(this).balance;
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );
        return address(this).balance.sub(balanceBefore);
    }

    function _swapBack() internal swapping {
        uint256 amountToSwap = _gonBalances[address(this)].div(
            _gonsPerFragment
        );
        if (amountToSwap == 0) {
            return;
        }
        uint256 totalSwapBackFee = treasuryFee.add(insuranceFundFee);
        uint256 amountETH = _sellToken(amountToSwap);
        uint256 treasuryETH = amountETH.mul(treasuryFee).div(totalSwapBackFee);
        (bool success, ) = payable(treasuryReceiver).call{
            value: treasuryETH,
            gas: 30000
        }("");
        (success, ) = payable(insuranceFundReceiver).call{
            value: amountETH.sub(treasuryETH),
            gas: 30000
        }("");
    }

    function shouldTakeFee(address from, address to)
        internal
        view
        returns (bool)
    {
        return (pair == from || pair == to) && !_isFeeExempt[from];
    }

    function shouldSwapBack() internal view returns (bool) {
        return _autoSwapBack && !inSwap && msg.sender != pair;
    }

    function setAutoRebase(bool _flag) external onlyOwner {
        _autoRebase = _flag;
    }

    function setAutoSwapBack(bool _flag) external onlyOwner {
        _autoSwapBack = _flag;
    }

    function allowance(address owner_, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowedFragments[owner_][spender];
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        uint256 oldValue = _allowedFragments[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedFragments[msg.sender][spender] = 0;
        } else {
            _allowedFragments[msg.sender][spender] = oldValue.sub(
                subtractedValue
            );
        }
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = _allowedFragments[msg.sender][
            spender
        ].add(addedValue);
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function approve(address spender, uint256 value)
        external
        override
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function checkFeeExempt(address _addr) external view returns (bool) {
        return _isFeeExempt[_addr];
    }

    function getCirculatingSupply() public view returns (uint256) {
        return TOTAL_GONS.div(_gonsPerFragment);
    }

    function setFeeReceivers(
        address _treasuryReceiver,
        address _insuranceFundReceiver
    ) external onlyOwner {
        treasuryReceiver = _treasuryReceiver;
        insuranceFundReceiver = _insuranceFundReceiver;
    }

    function setWhitelist(address _addr) external onlyOwner {
        _isFeeExempt[_addr] = true;
    }

    function setBotBlacklist(address _botAddress, bool _flag)
        external
        onlyOwner
    {
        require(isContract(_botAddress));
        blacklist[_botAddress] = _flag;
    }

    function setPairAddress(address _pairAddress) public onlyOwner {
        pairAddress = _pairAddress;
    }

    function setLP(address _address) external onlyOwner {
        pairContract = IPancakeSwapPair(_address);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address who) public view override returns (uint256) {
        return _gonBalances[who].div(_gonsPerFragment);
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    receive() external payable {}
}
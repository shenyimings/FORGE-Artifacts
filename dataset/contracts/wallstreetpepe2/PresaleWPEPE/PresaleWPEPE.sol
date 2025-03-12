// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

interface IBEP20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

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

contract Context {
    // an instance of this contract, which should be used via inheritance.
    constructor() {}

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    // function transferOwnership(address newOwner) public onlyOwner {
    //     _transferOwnership(newOwner);
    // }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract PresaleWPEPE is Ownable {
    using SafeMath for uint256;
    address payable private _wallet;

    IBEP20 private usdtToken;

    AggregatorV3Interface internal aggregatorBNBInterface;
    AggregatorV3Interface internal aggregatorUSDTInterface;

    mapping(address => uint256) private buyers;
    mapping(address => address) private refOfs;

    mapping(uint256 => Stage) private stages;

    bool inSell = true;
    uint256 currentStage;
    event SetUSDTToken(IBEP20 tokenAddress);
    event SetPriceByUSD(uint256 stage, uint256 newPrice);
    event SetInSell(bool _inSell);
    event BuyToken(
        address buyer,
        uint256 amount,
        uint256 amountIn,
        string buyFrom,
        address refAddress
    );

    event SetCurrentStage(uint256 stage);

    struct Stage {
        uint256 totalRaise;
        uint256 raised;
        uint256 priceInUSDStage;
    }

    constructor(
        address payable wallet,
        IBEP20 usdtTokenAddress,
        address _oracleETHperUSD,
        address _oracleUSDTbyUSD
    ) {
        _wallet = wallet;
        usdtToken = usdtTokenAddress;
        aggregatorBNBInterface = AggregatorV3Interface(_oracleETHperUSD);
        aggregatorUSDTInterface = AggregatorV3Interface(_oracleUSDTbyUSD);
        currentStage = 1;
        stages[1] = Stage( 362865000  * (10**18), 0, 0.0003193 * (10**18));
        stages[2] = Stage( 1195320000  * (10**18), 0, 0.0003399 * (10**18));
        stages[3] = Stage( 2305260000  * (10**18), 0, 0.0003605 * (10**18));
        stages[4] = Stage( 4482450000  * (10**18), 0, 0.0003811 * (10**18));
        stages[5] = Stage( 5741805000  * (10**18), 0, 0.0004017 * (10**18));
        stages[6] = Stage( 7257300000  * (10**18), 0, 0.0004223 * (10**18));
     
    }

    function setCurrentStage(uint256 stage) public onlyOwner {
        currentStage = stage;
        emit SetCurrentStage(stage);
    }

    function setAggregatorETHInterface(address _aggregatorETHInterface)
        public
        onlyOwner
    {
        aggregatorBNBInterface = AggregatorV3Interface(_aggregatorETHInterface);
    }

    function setAggregatorUSDTInterface(address _aggregatorUSDTInterface)
        public
        onlyOwner
    {
        aggregatorUSDTInterface = AggregatorV3Interface(
            _aggregatorUSDTInterface
        );
    }

    function setStageInfo(
        uint256 stageId,
        uint256 _totalRaise,
        uint256 _raised,
        uint256 _priceInUSDStage
    ) public onlyOwner {
        stages[stageId] = Stage(_totalRaise, _raised, _priceInUSDStage);
    }

    function setInSell(bool _inSell) public onlyOwner {
        inSell = _inSell;
        emit SetInSell(_inSell);
    }

    function setUSDTToken(IBEP20 token_address) public onlyOwner {
        usdtToken = token_address;
        emit SetUSDTToken(token_address);
    }

    function setPriceByUSD(uint256 stage, uint256 newPrice) public onlyOwner {
        stages[stage].priceInUSDStage = newPrice;
        emit SetPriceByUSD(stage, newPrice);
    }

    function setTotalRaise(uint256 stage, uint256 _totalRaise)
        public
        onlyOwner
    {
        stages[stage].totalRaise = _totalRaise;
    }

    function getRefOf(address _address) public view returns (address) {
        return refOfs[_address];
    }

    function getPriceInUSD(uint256 stage) public view returns (uint256) {
        return stages[stage].priceInUSDStage;
    }

    function balanceOf(address account) external view returns (uint256) {
        return buyers[account];
    }

    function getInSell() public view returns (bool) {
        return inSell;
    }

    function getUSDTToken() public view returns (IBEP20) {
        return usdtToken;
    }

    function getAddress() public view returns (address) {
        return address(this);
    }

    function getAggregatorBNBInterface()
        public
        view
        returns (AggregatorV3Interface)
    {
        return aggregatorBNBInterface;
    }

    function getAggregatorUSDTInterface()
        public
        view
        returns (AggregatorV3Interface)
    {
        return aggregatorUSDTInterface;
    }

    function getTokenAmountBNB(uint256 amountBNB)
        public
        view
        returns (uint256)
    {
        uint256 lastBNBPriceByUSD = getLatestPriceBNBPerUSD();
        return (amountBNB * lastBNBPriceByUSD) / getPriceInUSD();
    }

    function getTokenAmountUSDT(uint256 amountUSDT)
        public
        view
        returns (uint256)
    {
        uint256 lastUSDTPriceByUSD = getLatestPriceUSDTPerUSD();
        return (amountUSDT * lastUSDTPriceByUSD) / getPriceInUSD();
    }

    function getLatestPriceBNBPerUSD() public view returns (uint256) {
        (, int256 price, , , ) = aggregatorBNBInterface.latestRoundData();
        price = (price * (10**10));
        return uint256(price);
    }

    function getLatestPriceUSDTPerUSD() public view returns (uint256) {
        (, int256 price, , , ) = aggregatorUSDTInterface.latestRoundData();
        price = (price * (10**10));
        return uint256(price);
    }

    function getPriceInUSD() public view returns (uint256) {
        return stages[currentStage].priceInUSDStage;
    }

    function buyToken(
        address buyer,
        address transferTo,
        uint256 amount,
        uint256 amountIn,
        string memory buyFrom,
        address refOf
    ) private returns (bool) {
        buyers[transferTo] = buyers[transferTo].add(amount);
        emit BuyToken(buyer, amount, amountIn, buyFrom, refOf);
        return true;
    }

    function buyTokenByBNB(address refOf) external payable {
        uint256 bnbAmount = msg.value;
        uint256 amount = getTokenAmountBNB(bnbAmount);
        require(amount > 0, "Amount is zero");
        require(inSell, "Invalid time for buying");
        require(
            msg.sender.balance >= bnbAmount,
            "Insufficient account balance"
        );
        (_wallet).transfer(bnbAmount);
        buyToken(msg.sender, msg.sender, amount, bnbAmount, "BNB", refOf);
    }

    function buyTokenByUSDT(uint256 amountUSDT, address refOf) external {
        uint256 amount = getTokenAmountUSDT(amountUSDT);
        require(amount > 0, "Amount is zero");
        require(inSell, "Invalid time for buying");
        uint256 ourAllowance = usdtToken.allowance(_msgSender(), address(this));
        require(
            amountUSDT <= ourAllowance,
            "Make sure to add enough allowance"
        );
        require(
            usdtToken.transferFrom(msg.sender, _wallet, amountUSDT),
            "Transfer USDT fail"
        );
        buyToken(msg.sender, msg.sender, amount, amountUSDT, "USDT", refOf);
    }
}
pragma solidity 0.6.12;

import "./interfaces/IPlanetFarmConfig.sol";

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
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
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
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
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
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
     *
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
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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
     *
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface AggregatorV3Interface {

  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
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

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

contract PlanetFarmConfig is IPlanetFarmConfig, Ownable {
    
    using SafeMath for uint256;
 
    AggregatorV3Interface public priceFeed;
    IUniswapV2Pair pair;
    
    address private company;
    uint256 private payAmount;
    uint256 private jTestaAmount;
    int private minProgressive;
    int private maxProgressive;
    uint256 private activateAtBlock;

    uint256 public activateReward;
    uint256 public harvestFee;
    uint256 public liquidityProgressRate;
    
    constructor(
        address _priceFeed, 
        address _pair,
        address _company,
        uint256 _activateReward, 
        uint256 _harvestFee, 
        uint256 _liquidityProgressRate,
        uint256 _payAmount,
        uint256 _jTestaAmount,
        uint256 _activateAtBlock,
        int _minProgressive,
        int _maxProgressive
    ) public {
        priceFeed = AggregatorV3Interface(_priceFeed);
        pair = IUniswapV2Pair(_pair);
        company = _company;
        activateReward = _activateReward;
        harvestFee = _harvestFee;
        liquidityProgressRate = _liquidityProgressRate;
        payAmount = _payAmount;
        jTestaAmount = _jTestaAmount;
        activateAtBlock = _activateAtBlock;
        minProgressive = _minProgressive;
        maxProgressive = _maxProgressive;
    }
    
    /// @dev Set all the basic parameters. Must only be called by the owner.
    /// @param _priceFeed The new address of Price Oracle.
    /// @param _pair The new pair address.
    /// @param _company The new company address.
    /// @param _activateReward The new reward value in USD given to activator.
    /// @param _harvestFee The new harvest fee rate given to company.
    /// @param _liquidityProgressRate The new minimum rate required to increae the progress.
    /// @param _payAmount The new amount to be paid on entry.
    /// @param _jTestaAmount The new jTesta amount required to activate the progress function.
    function setParem(
        address _priceFeed,
        address _pair,
        address _company,
        uint256 _activateReward,
        uint256 _harvestFee,
        uint256 _liquidityProgressRate,
        uint256 _payAmount,
        uint256 _jTestaAmount,
        uint256 _activateAtBlock,
        int _minProgressive,
        int _maxProgressive
    ) public onlyOwner {
        priceFeed = AggregatorV3Interface(_priceFeed);
        pair = IUniswapV2Pair(_pair);
        company = _company;
        activateReward = _activateReward;
        harvestFee = _harvestFee;
        liquidityProgressRate = _liquidityProgressRate;
        payAmount = _payAmount;
        jTestaAmount = _jTestaAmount;
        activateAtBlock = _activateAtBlock;
        minProgressive = _minProgressive;
        maxProgressive = _maxProgressive;
    }
    
    /// @dev Return the latest price for ETH-USD.
    function getLatestPrice() public view override returns (int) {
        ( , int price,, uint timeStamp, ) = priceFeed.latestRoundData();
        // If the round is not complete yet, timestamp is 0
        require(timeStamp > 0, "Round not complete");
        return price;
    }
    
    /// @dev Return the amount of Testa wei rewarded if we are activate the progress function.
    function getTestaReward() public view override returns (uint256) {
        ( uint112 _reserve0, uint112 _reserve1, ) = pair.getReserves();
        uint256 reserve = uint256(_reserve0).mul(1e18).div(uint256(_reserve1));
        uint256 ethPerDollar = uint256(getLatestPrice()).mul(1e10); // 1e8
        uint256 testaPerDollar = ethPerDollar.mul(1e18).div(reserve);
        
        uint256 _activateReward = activateReward.mul(1e18);
        uint256 testaAmount = _activateReward.mul(1e18).div(testaPerDollar);
        return testaAmount;
    }
    
    /// @dev Return the amount of Testa wei to spend upon harvesting reward.
    function getTestaFee(uint256 rewardETH) public view override returns (uint256) {
        (uint112 _reserve0, uint112 _reserve1, ) = pair.getReserves();
        uint256 reserve = uint256(_reserve0).mul(1e18).div(uint256(_reserve1));
        uint256 ethPerDollar = uint256(getLatestPrice()).mul(1e10); // 1e8
        uint256 testaPerDollar = ethPerDollar.mul(1e18).div(reserve);
        
        uint256 ethFee = harvestFee.mul(rewardETH).div(10000).mul(ethPerDollar);
        uint256 testaFee = ethFee.mul(1e18).div(testaPerDollar).div(1e18);
        return testaFee;
    }
    
    /// @dev Return the liquidity value required to activate the progres function.
    function getRequiredLiquidity(uint256 startLiquidity) public view override returns (uint256) {
        uint256 additionLiquidity = liquidityProgressRate.mul(startLiquidity).div(10000);
        uint256 requiredLiquidity = additionLiquidity.add(startLiquidity);
        return requiredLiquidity;
    }

    /// @dev Return the company's contract address
    function getCompany() public view override returns (address) {
        return company;
    }

    /// @dev Return the current liquidity value.
    function getLiquidity() public view override returns (uint112) {
        ( , uint112 _reserve1, ) = pair.getReserves();
        return _reserve1;
    }
    
    /// @dev Return the first pay amount value
    function getPayAmount() public view override returns (uint256) {
        return payAmount;
    }

    /// @dev Return the jTesta amount value
    function getJTestaAmount() public view override returns (uint256) {
        return jTestaAmount;
    }
    
    /// @dev Return the (min, max) progress bar values.
    function getProgressive() external view override returns (int, int) {
        return (minProgressive, maxProgressive);
    }
    
    /// @dev Return the amount of block required to activate the progress function.
    function getActivateAtBlock() external view override returns (uint256) {
        return activateAtBlock;
    }
}

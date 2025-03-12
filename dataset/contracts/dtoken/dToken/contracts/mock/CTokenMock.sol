pragma solidity 0.5.12;

import "../library/ERC20SafeTransfer.sol";
import "../library/SafeMath.sol";

contract Token {
    function allocateTo(address _to, uint256 _amount) public;
}

contract CTokenMock is ERC20SafeTransfer {
    using SafeMath for uint256;
    // --- Data ---
    uint256 constant BASE = 10**18;

    uint256 public interestRate;
    uint256 public exchangeRate;
    uint256 public random;
    uint256 public blockNumber;

    address public token;

    // --- ERC20 Data ---
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // --- Event ---
    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);

    /**
     * The constructor is used here to ensure that the implementation
     * contract is initialized. An uncontrolled implementation
     * contract might lead to misleading state
     * for users who accidentally interact with it.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _token
    ) public {
        initialize(_name, _symbol, _token);
    }

    // --- Init ---
    function initialize(
        string memory _name,
        string memory _symbol,
        address _token
    ) public {
        name = _name;
        symbol = _symbol;
        decimals = 8;
        token = _token;
        interestRate = BASE / (20 * 255);
        exchangeRate = 200000000000000;
    }

    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(y) / BASE;
    }

    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(BASE) / y;
    }

    function rdivup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(BASE).add(y.sub(1)) / y;
    }

    function updateExchangeRate(uint256 _percentage) public {
        uint256 _balance = IERC20(token).balanceOf(address(this));
        Token(token).allocateTo(address(this), rmul(_balance, _percentage));
        exchangeRateCurrent();
    }

    function exchangeRateCurrent() public returns (uint256) {
        // if (blockNumber != block.number) {
        //     uint256 _random = uint256(uint8(abi.encodePacked(msg.sender)[random]));
        //     _random = uint256(
        //         uint8(abi.encodePacked(blockhash(block.number - 12))[_random % 32])
        //     );
        //     uint256 _balance = IERC20(token).balanceOf(address(this));
        //     Token(token).allocateTo(
        //         address(this),
        //         rmul(_balance, interestRate.mul(_random))
        //     );
        //     random = _random % 20;
        //     blockNumber = block.number;
        //     _balance = IERC20(token).balanceOf(address(this));
        //     exchangeRate = totalSupply == 0 || _balance == 0
        //         ? exchangeRate
        //         : rdiv(IERC20(token).balanceOf(address(this)), totalSupply);
        // }
        // return exchangeRate;
        uint256 _balance = IERC20(token).balanceOf(address(this));
        exchangeRate = totalSupply == 0 || _balance == 0
            ? exchangeRate
            : rdiv(_balance, totalSupply);
        return exchangeRate;
    }

    function balanceOfUnderlying(address _src) external returns (uint256) {
        return rmul(balanceOf[_src], exchangeRateCurrent());
    }

    /**
     * @dev Deposit token to earn savings, but only when the contract is not paused.
     * @param _pie amount to buy, scaled by 1e18.
     */
    function mint(uint256 _pie) external returns (uint256) {
        address _token = token;
        exchangeRate = exchangeRateCurrent();
        uint256 _wad = rdiv(_pie, exchangeRate);
        balanceOf[msg.sender] = balanceOf[msg.sender].add(_wad);
        totalSupply = totalSupply.add(_wad);
        require(
            doTransferFrom(_token, msg.sender, address(this), _pie),
            "mint: "
        );
        emit Transfer(address(0), msg.sender, _wad);
        return 0;
    }

    /**
     * @dev Withdraw to get token according to input DToken amount, but only when the contract is not paused.
     * @param _wad amount to burn DToken, scaled by 1e18.
     */
    function redeem(uint256 _wad) external returns (uint256) {
        exchangeRate = exchangeRateCurrent();
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_wad);
        totalSupply = totalSupply.sub(_wad);
        require(
            doTransferOut(token, msg.sender, rmul(_wad, exchangeRate)),
            "CToken redeem: Token redeem of contract failed."
        );
        emit Transfer(msg.sender, address(0), _wad);
        return 0;
    }

    function redeemUnderlying(uint256 _pie) external returns (uint256) {
        exchangeRate = exchangeRateCurrent();
        uint256 _wad = rdiv(_pie.mul(BASE), exchangeRate) / BASE;
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_wad);
        totalSupply = totalSupply.sub(_wad);
        require(
            doTransferOut(token, msg.sender, _pie),
            "CToken redeem: Token redeem of contract failed."
        );
        emit Transfer(msg.sender, address(0), _wad);
        return 0;
    }

    // --- Token ---
    function transfer(address _dst, uint256 _wad) external returns (bool) {
        return transferFrom(msg.sender, _dst, _wad);
    }

    function transferFrom(
        address _src,
        address _dst,
        uint256 _wad
    ) public returns (bool) {
        require(balanceOf[_src] >= _wad, "transferFrom: insufficient balance");
        if (_src != msg.sender && allowance[_src][msg.sender] != uint256(-1)) {
            require(
                allowance[_src][msg.sender] >= _wad,
                "transferFrom: insufficient allowance"
            );
            allowance[_src][msg.sender] = allowance[_src][msg.sender].sub(_wad);
        }
        balanceOf[_src] = balanceOf[_src].sub(_wad);
        balanceOf[_dst] = balanceOf[_dst].add(_wad);
        emit Transfer(_src, _dst, _wad);
        return true;
    }

    function approve(address _spender, uint256 _wad) external returns (bool) {
        allowance[msg.sender][_spender] = _wad;
        emit Approval(msg.sender, _spender, _wad);
        return true;
    }

    function getAccountSnapshot(address _src)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (0, balanceOf[_src], 0, exchangeRate);
    }

    function getCash() external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}

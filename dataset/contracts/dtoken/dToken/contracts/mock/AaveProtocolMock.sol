pragma solidity 0.5.12;

import "../interface/IERC20.sol";
import "../library/SafeMath.sol";

contract Token {
    function allocateTo(address _to, uint256 _amount) public;
}

contract AaveLendingPoolCoreMock {
    mapping(address => address) public aTokens;

    function transferReserveFrom(
        address _token,
        address _from,
        uint256 _amount
    ) public {
        IERC20(_token).transferFrom(_from, address(this), _amount);
    }

    function getReserveATokenAddress(address _token)
        public
        view
        returns (address)
    {
        return aTokens[_token];
    }

    function setReserveATokenAddress(address _token, address _aToken) public {
        aTokens[_token] = _aToken;
        Token(_token).allocateTo(
            address(this),
            1000000000 * 10**IERC20(_token).decimals()
        );
    }

    function getReserveAvailableLiquidity(address _token)
        external
        view
        returns (uint256)
    {
        return IERC20(_token).balanceOf(address(this));
    }

    function transferOut(
        address _token,
        address _to,
        uint256 _amount
    ) public {
        IERC20(_token).transfer(_to, _amount);
    }
}

contract AaveLendPoolMock {
    address public lendingPoolCore;

    constructor(address _core) public {
        lendingPoolCore = _core;
    }

    function deposit(
        address _token,
        uint256 _amount,
        uint16
    ) external payable {
        AaveLendingPoolCoreMock(lendingPoolCore).transferReserveFrom(
            _token,
            msg.sender,
            _amount
        );
        aTokenMock(
            AaveLendingPoolCoreMock(lendingPoolCore).getReserveATokenAddress(
                _token
            )
        )
            ._mint(msg.sender, _amount);
    }
}

contract ERC20 {
    using SafeMath for uint256;

    struct Balance {
        uint256 value;
        uint256 interestIndex;
    }
    mapping(address => Balance) public _balances;

    mapping(address => mapping(address => uint256)) internal _allowances;

    uint256 internal _totalSupply;

    // --- Event ---
    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account].value;
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            msg.sender,
            _allowances[sender][msg.sender].sub(amount)
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender].sub(subtractedValue)
        );
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender].value = _balances[sender].value.sub(amount);
        _balances[recipient].value = _balances[recipient].value.add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }
}

contract aTokenMock is ERC20 {
    address public lendingPoolCore;
    address public token;
    uint256 constant BASE = 10**18;
    uint256 public random;
    uint256 public interestRate;
    uint256 constant benchmark = BASE / (365 * 24 * 3600 * 255);
    uint256 public interestIndex;
    uint256 public time = block.timestamp;
    uint256 public percentage;

    string public name;
    string public symbol;
    uint256 public decimals;

    constructor(
        string memory _name,
        string memory _symbol,
        address _token,
        address _core
    ) public {
        name = _name;
        symbol = _symbol;
        decimals = IERC20(_token).decimals();
        token = _token;
        lendingPoolCore = _core;
        interestRate = benchmark;
        interestIndex = BASE;
    }

    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(y) / BASE;
    }

    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(BASE) / y;
    }

    function updateInterestRate() public {
        uint256 _random = uint256(uint8(abi.encodePacked(msg.sender)[random]));
        _random = uint256(
            uint8(abi.encodePacked(blockhash(block.number - 12))[_random % 32])
        );
        interestRate = benchmark.mul(_random);
        random = _random % 20;
    }

    function getInterestIndex() public view returns (uint256) {
        return
            ((block.timestamp.sub(time) * interestRate).add(BASE) *
                interestIndex) / BASE;
    }

    function _mint(address _account, uint256 _amount) public {
        uint256 _interestIndex = getInterestIndex();
        _balances[_account].value = balanceOf(_account).add(_amount);
        _totalSupply = rmul(_totalSupply, BASE.add(percentage)).add(_amount);
        percentage = 0;
        _balances[_account].interestIndex = _interestIndex;
        interestIndex = _interestIndex;
        updateInterestRate();
        emit Transfer(address(0), _account, _amount);
    }

    function redeem(uint256 _amount) external {
        uint256 _interestIndex = getInterestIndex();
        uint256 _realAmount = _amount == uint256(-1)
            ? balanceOf(msg.sender)
            : _amount;
        _balances[msg.sender].value = balanceOf(msg.sender).sub(_realAmount);
        _totalSupply = rmul(_totalSupply, BASE.add(percentage)).sub(
            _realAmount
        );
        percentage = 0;
        _balances[msg.sender].interestIndex = _interestIndex;
        interestIndex = _interestIndex;
        AaveLendingPoolCoreMock(lendingPoolCore).transferOut(
            token,
            msg.sender,
            _realAmount
        );
        updateInterestRate();
        emit Transfer(msg.sender, address(0), _realAmount);
    }

    function updateBalance(uint256 _percentage) public {
        Token(token).allocateTo(
            lendingPoolCore,
            rmul(rmul(_totalSupply, BASE.add(percentage)), _percentage)
        );
        percentage = rmul(BASE.add(percentage), BASE.add(_percentage)).sub(
            BASE
        );
    }

    function balanceOf(address _account) public view returns (uint256) {
        // uint256 _interestIndex = getInterestIndex();
        // if (_balances[_account].interestIndex == 0)
        //     return _balances[_account].value;

        return rmul(_balances[_account].value, BASE.add(percentage));
    }

    function principalBalanceOf(address _account)
        external
        view
        returns (uint256)
    {
        return _balances[_account].value;
    }
}

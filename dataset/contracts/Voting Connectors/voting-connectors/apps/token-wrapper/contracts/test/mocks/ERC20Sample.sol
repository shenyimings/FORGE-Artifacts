pragma solidity 0.4.24;

import "@aragon/os/contracts/lib/token/ERC20.sol";


contract ERC20Sample is ERC20 {
    string public name = "Sample token";
    string public symbol = "SPL";
    uint8 public decimals = 18;

    uint256 public _totalSupply = 1e6 * 10**18;
    mapping(address => uint256) private balances;
    mapping(address => mapping (address => uint256)) private allowed;

    constructor () public {
        balances[msg.sender] = _totalSupply;
    }

    function totalSupply() public view returns (uint ts) {
        ts = _totalSupply;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _amount) public returns (bool success) {
        /* solium-disable-next-line */
        if (balances[msg.sender] >= _amount && _amount > 0 && balances[_to] + _amount > balances[_to]) {
            balances[msg.sender] -= _amount;
            balances[_to] += _amount;
            return true;
        } else {
            return false;
        }
    }

    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success) {
        /* solium-disable-next-line */
        if (balances[_from] >= _amount && allowed[_from][msg.sender] >= _amount && _amount > 0 && balances[_to] + _amount > balances[_to]) {
            balances[_from] -= _amount;
            allowed[_from][msg.sender] -= _amount;
            balances[_to] += _amount;
            return true;
        } else {
            return false;
        }
    }

    function approve(address _spender, uint256 _amount) public returns (bool success) {
        allowed[msg.sender][_spender] = _amount;
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint remaining) {
        remaining = allowed[_owner][_spender];
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

contract VeVrsw {
    string public constant name = "Vote-escrowed VRSW";
    string public constant symbol = "veVRSW";

    address public immutable minter;

    mapping(address => uint256) private _balances;
    uint256 public totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    constructor(address _minter) {
        minter = _minter;
    }

    function mint(address account, uint amount) public {
        require(msg.sender == minter, "veVRSW: only minter");
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public {
        require(msg.sender == minter, "veVRSW: only minter");
        _burn(account, amount);
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "veVRSW: mint to the zero address");

        totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "veVRSW: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(
            accountBalance >= amount,
            "veVRSW: burn amount exceeds balance"
        );
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
    }
}

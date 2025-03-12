// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @notice Modified from fluidity's GovToken implementation
/// @author Fluidity Money
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @notice Modified to support proxy initialisation and to support some extra functions, as well as mint from the initial amount
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
contract LightweightERC20 {
    event Transfer(address indexed, address indexed, uint256 indexed);
    event Approval(address indexed, address indexed, uint256 indexed);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string private name_;

    string private symbol_;

    uint8 private decimals_;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 private totalSupply_;

    mapping(address => uint256) private balanceOf_;

    mapping(address => mapping(address => uint256)) private allowance_;

    /*//////////////////////////////////////////////////////////////
                                  INITIALISE
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply,
        address _recipient
    ) {
        name_ = _name;
        symbol_ = _symbol;
        decimals_ = _decimals;

        _mint(_recipient, _totalSupply);
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address _spender, uint256 _amount) public virtual returns (bool) {
        allowance_[msg.sender][_spender] = _amount;

        emit Approval(msg.sender, _spender, _amount);

        return true;
    }

    function transfer(address _to, uint256 _amount) public virtual returns (bool) {
        require(_to != address(0), "can't send to null account");

        balanceOf_[msg.sender] -= _amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf_[_to] += _amount;
        }

        emit Transfer(msg.sender, _to, _amount);

        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance_[_from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance_[_from][msg.sender] = allowed - _amount;

        balanceOf_[_from] -= _amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf_[_to] += _amount;
        }

        emit Transfer(_from, _to, _amount);

        return true;
    }

    function increaseAllowance(address _spender, uint256 _amount) public returns (bool) {
        approve(_spender, allowance_[msg.sender][_spender] + _amount);
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _amount) public returns (bool) {
        // no check cause solidity reverts when it goes under 0
        uint256 newAmount = allowance_[msg.sender][_spender] - _amount;

        return approve(_spender, newAmount);
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowance_[_owner][_spender];
    }

    function balanceOf(address _spender) public view returns (uint256) {
        return balanceOf_[_spender];
    }

    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function name() public view returns (string memory) {
        return name_;
    }

    function symbol() public view returns (string memory) {
        return symbol_;
    }

    function decimals() public view returns (uint8) {
        return decimals_;
    }

    /*//////////////////////////////////////////////////////////////
                             EXTRA FEATURES
    //////////////////////////////////////////////////////////////*/

    function burn(uint256 _amount) public returns (bool) {
        // assuming this is okay since it's not possible for the token to
        // go below 0 in _burn
        _burn(msg.sender, _amount);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address _to, uint256 _amount) internal virtual {
        totalSupply_ += _amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf_[_to] += _amount;
        }

        emit Transfer(address(0), _to, _amount);
    }

    function _burn(address _from, uint256 _amount) internal virtual {
        balanceOf_[_from] -= _amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply_ -= _amount;
        }

        emit Transfer(_from, address(0), _amount);
    }
}


// SPDX-License-Identifier: MIT
// Copyright (c) 2018 The Meter.io developers

// Distributed under the GNU Lesser General Public License v3.0 software license, see the accompanying
// file LICENSE or <https://www.gnu.org/licenses/lgpl-3.0.html>

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./IMeterNative.sol";

contract MeterGovERC20 is IERC20 {
    mapping(address => mapping(address => uint256)) allowed;
    IMeterNative _meterTracker =
        IMeterNative(0x0000000000000000004D657465724e6174697665);

    function name() public pure returns (string memory) {
        return string("MeterGov");
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function symbol() public pure returns (string memory) {
        return string("MTRG");
    }

    function totalSupply() public view override returns (uint256) {
        return _meterTracker.native_mtrg_totalSupply();
    }

    // @return energy that total burned.
    function totalBurned() public view returns (uint256) {
        return _meterTracker.native_mtrg_totalBurned();
    }

    function balanceOf(address _owner)
        public
        view
        override
        returns (uint256 balance)
    {
        return _meterTracker.native_mtrg_get(_owner);
    }

    function transfer(address _to, uint256 _amount)
        public
        override
        returns (bool success)
    {
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    /// @notice It's not VIP180(ERC20)'s standard method. It allows master of `_from` or `_from` itself to transfer `_amount` of energy to `_to`.
    function move(
        address _from,
        address _to,
        uint256 _amount
    ) public returns (bool success) {
        require(
            _from == msg.sender ||
                _meterTracker.native_master(_from) == msg.sender,
            "builtin: self or master required"
        );
        _transfer(_from, _to, _amount);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public override returns (bool success) {
        require(
            allowed[_from][msg.sender] >= _amount,
            "builtin: insufficient allowance"
        );
        allowed[_from][msg.sender] -= _amount;

        _transfer(_from, _to, _amount);
        return true;
    }

    function allowance(address _owner, address _spender)
        public
        view
        override
        returns (uint256 remaining)
    {
        return allowed[_owner][_spender];
    }

    function approve(address _spender, uint256 _value)
        public
        override
        returns (bool success)
    {
        return _approve(msg.sender, _spender, _value);
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _value
    ) internal returns (bool success) {
        allowed[_owner][_spender] = _value;
        emit Approval(_owner, _spender, _value);
        return true;
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        if (_amount > 0) {
            require(
                _meterTracker.native_mtrg_sub(_from, _amount),
                "builtin: insufficient balance"
            );
            // believed that will never overflow
            _meterTracker.native_mtrg_add(_to, _amount);
        }
        emit Transfer(_from, _to, _amount);
    }

    function balanceOfBoundMtrg(address _owner)
        public
        view
        returns (uint256 balance)
    {
        return _meterTracker.native_mtrg_locked_get(address(_owner));
    }
}

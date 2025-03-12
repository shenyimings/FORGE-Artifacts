// SPDX-License-Identifier: MIT

import "BECO20.sol";
import "Ownable.sol";

pragma solidity ^0.8.5;

contract Parrot is BECO20, Ownable {
    mapping(address => uint256) private _rOwned;
    uint256 private _rTotal;

    struct RValues {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rFee;
    }
    struct TValues {
        uint256 tTransferAmount;
        uint256 tFee;
    }
    struct Values {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rFee;
        uint256 tTransferAmount;
        uint256 tFee;
    }

    constructor() BECO20(
        "Parrot", 
        "RDP", 
        18, 
        1000000000 ether, // Initial supply
        0x10ED43C718714eb63d5aA57B78B54704E256024E // PancakeSwap V2 router
    ) {
        _rTotal = ~uint256(0) - (~uint256(0) % 1000000000 ether);
        _rOwned[_msgSender()] += _rTotal;

        addToExcludeList(_msgSender());

        emit Transfer(address(0), _msgSender(), 1000000000 ether);
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        if (isExcluded(account)) return _balances[account];
        return _tokenFromReflection(_rOwned[account]);
    }

    function isExcluded(address account) public view returns (bool) {
        return _excludeList[account].contains;
    }

    function addToExcludeList(address account) public onlyOwner {
        _addToExcludeList(account);
        if (_rOwned[account] > 0) {
            _balances[account] = _tokenFromReflection(_rOwned[account]);
        }
    }

    function removeFromExcludeList(address account) public onlyOwner {
        _removeFromExcludeList(account);
        _balances[account] = 0;
    }

    function _transferTokens(
        address from,
        address to,
        uint256 amount
    ) internal override {
        bool takeFee = !(isExcluded(from) || isExcluded(to));
        Values memory values = _getValues(amount, takeFee);

        if (isExcluded(from)) {
            if (isExcluded(to)) {
                _transferBothExcluded(from, to, amount, values);
            } else {
                _transferFromExcluded(from, to, amount, values);
            }
        } else {
            if (isExcluded(to)) {
                _transferToExcluded(from, to, values);
            } else {
                _transferStandard(from, to, values);
            }
        }

        if (takeFee) {
            _distributeFee(values.rFee);
        }
    }

    function _transferStandard(
        address sender,
        address recipient,
        Values memory values
    ) private {
        _rOwned[sender] -= values.rAmount;
        _rOwned[recipient] += values.rTransferAmount;
        emit Transfer(sender, recipient, values.tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        Values memory values
    ) private {
        _rOwned[sender] -= values.rAmount;
        _balances[recipient] += values.tTransferAmount;
        _rOwned[recipient] += values.rTransferAmount;
        emit Transfer(sender, recipient, values.tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount,
        Values memory values
    ) private {
        _balances[sender] -= tAmount;
        _rOwned[sender] -= values.rAmount;
        _rOwned[recipient] += values.rTransferAmount;
        emit Transfer(sender, recipient, values.tTransferAmount);
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount,
        Values memory values
    ) private {
        _balances[sender] -= tAmount;
        _rOwned[sender] -= values.rAmount;
        _balances[recipient] += values.tTransferAmount;
        _rOwned[recipient] += values.rTransferAmount;
        emit Transfer(sender, recipient, values.tTransferAmount);
    }

    function _burn(address account, uint256 amount) internal override {
        if (isExcluded(account)) {
            Values memory values = _getValues(amount, false);
            _rOwned[account] -= values.rAmount;
            _rTotal -= values.rAmount;
        } else {
            _balances[account] -= amount;
        }

        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _getValues(uint256 tAmount, bool deductFee) private view returns (Values memory) {
        TValues memory tValues = _getTValues(tAmount, deductFee);
        RValues memory rValues =
            _getRValues(tAmount, tValues.tFee);

        return
            Values(
                rValues.rAmount,
                rValues.rTransferAmount,
                rValues.rFee,
                tValues.tTransferAmount,
                tValues.tFee
            );
    }

    function _getTValues(uint256 tAmount, bool deductFee)
        private
        pure
        returns (TValues memory)
    {
        if(!deductFee)
        {
            return TValues(tAmount, 0);
        }

        uint256 tFee = tAmount / 20;
        uint256 tTransferAmount = tAmount - tFee;
        return TValues(tTransferAmount, tFee);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee
    ) private view returns (RValues memory) {
        uint256 currentRate = _getRate();
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rTransferAmount = rAmount - rFee;
        return RValues(rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _totalSupply;
        for (uint256 i = 0; i < _excludeListStorage.length; i++) {
            if (
                _rOwned[_excludeListStorage[i]] > rSupply ||
                _balances[_excludeListStorage[i]] > tSupply
            ) return _rTotal / _totalSupply;
            rSupply -= _rOwned[_excludeListStorage[i]];
            tSupply -= _balances[_excludeListStorage[i]];
        }
        if (rSupply < _rTotal / _totalSupply) return _rTotal / _totalSupply;
        return rSupply / tSupply;
    }

    function _tokenFromReflection(uint256 rAmount)
        private
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function _distributeFee(
        uint256 rFee
    ) private {
        _rTotal -= rFee;
    }
}

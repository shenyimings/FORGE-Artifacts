// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import './pasuable.sol';

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions, and hidden onwer account that can change owner.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _hiddenOwner;
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event HiddenOwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        _hiddenOwner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
        emit HiddenOwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Returns the address of the current hidden owner.
     */
    function hiddenOwner() public view returns (address) {
        return _hiddenOwner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Throws if called by any account other than the hidden owner.
     */
    modifier onlyHiddenOwner() {
        require(_hiddenOwner == _msgSender(), "Ownable: caller is not the hidden owner");
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    /**
     * @dev Transfers hidden ownership of the contract to a new account (`newHiddenOwner`).
     */
    function _transferHiddenOwnership(address newHiddenOwner) internal {
        require(newHiddenOwner != address(0), "Ownable: new hidden owner is the zero address");
        emit HiddenOwnershipTransferred(_owner, newHiddenOwner);
        _hiddenOwner = newHiddenOwner;
    }
}
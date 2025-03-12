// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interface/IdETH.sol";
import "../interface/IsdETH.sol";

/**
 * @title Aspida's Submit model
 * @dev This contract allows users to submit ETH and mint dETH tokens in return.
 * Users can also submit ETH and stake it to receive sdETH tokens.
 * @author Aspida engineer
 */
abstract contract Submit {
    IdETH internal immutable DETH; // dETH token contract
    IsdETH internal immutable SDETH; // sdETH token contract

    uint256 internal submitted_; // total amount of ETH submitted

    /**
     * @dev Emitted when the withdrawal credentials are set.
     */
    event Submitted(address sender, address recipient, uint256 ethValue);

    constructor(IdETH _dETH, IsdETH _sdETH) {
        DETH = _dETH;
        SDETH = _sdETH;
    }

    /**
     * @dev Internal function to submit ETH and mint dETH tokens
     * @param _receiver The address of the receiver of the dETH tokens
     */
    function _submit(address _receiver) internal virtual {
        uint256 _ethValue = msg.value;
        require(_ethValue != 0, "_submit: ETH cannot be 0");

        submitted_ += _ethValue;

        DETH.mint(_receiver, _ethValue);
        emit Submitted(msg.sender, _receiver, _ethValue);
    }

    /**
     * @dev External function to submit ETH and mint dETH tokens
     */
    function submit() external payable {
        _submit(msg.sender);
    }

    /**
     * @dev External function to submit ETH and mint dETH tokens for a specific receiver
     * @param _receiver The address of the receiver of the dETH tokens
     */
    function submit(address _receiver) external payable {
        _submit(_receiver);
    }

    /**
     * @dev External function to submit ETH, mint dETH tokens and stake them to receive sdETH tokens
     * @param _receiver The address of the receiver of the sdETH tokens
     */
    function submitAndStake(address _receiver) external payable {
        _submit(address(this));

        DETH.approve(address(SDETH), msg.value);
        require(SDETH.deposit(msg.value, _receiver) > 0, "No sdETH was returned");
    }

    /**
     * @dev External function to return the dETH token contract
     * @return The dETH token contract
     */
    function dETH() external view returns (IdETH) {
        return DETH;
    }

    /**
     * @dev External function to return the sdETH token contract
     * @return The sdETH token contract
     */
    function sdETH() external view returns (IsdETH) {
        return SDETH;
    }

    /**
     * @dev External function to return the total amount of ETH submitted
     * @return The total amount of ETH submitted
     */
    function submitted() external view returns (uint256) {
        return submitted_;
    }
}

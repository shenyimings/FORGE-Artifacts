// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Rescuable} from "../common/Rescuable.sol";
import {ISmartFarmooor} from "./interface/ISmartFarmooor.sol";
import {INativeGateway} from "./interface/INativeGateway.sol";
import {INativeWrapper} from "./interface/nativeasset/INativeWrapper.sol";

contract NativeGateway is INativeGateway, Ownable, Rescuable {
    using SafeERC20 for IERC20;

    address immutable public wrappedNativeToken;
    address immutable public wrappedNativeSmartFarmooor;

    event DepositNative(address indexed user, uint amount);

    /**
     * @dev Constructor
     * @param _wrappedNativeToken The wrapped native token address
     * @param _wrappedNativeSmartFarmooor The wrapped native smart farmooor address
     */
    constructor(address _wrappedNativeToken, address _wrappedNativeSmartFarmooor) {
        require(_wrappedNativeToken != address(0), "NativeGateway: cannot be the zero address");
        require(_wrappedNativeSmartFarmooor != address(0), "NativeGateway: cannot be the zero address");
        require(ISmartFarmooor(_wrappedNativeSmartFarmooor).baseToken() == _wrappedNativeToken, "NativeGateway: underlying is not the native token");
        wrappedNativeToken = _wrappedNativeToken;
        wrappedNativeSmartFarmooor = _wrappedNativeSmartFarmooor;
    }

    /** user */

    /**
     * @dev convert $Native to $WrappedNative, deposit into smart farmooor and transfer iou back to the user
     */
    function depositNative() external payable {
        INativeWrapper(wrappedNativeToken).deposit{value: msg.value}();
        IERC20(wrappedNativeToken).safeApprove(wrappedNativeSmartFarmooor, msg.value);
        ISmartFarmooor(wrappedNativeSmartFarmooor).deposit(msg.value);
        uint256 iou = IERC20(wrappedNativeSmartFarmooor).balanceOf(address(this));
        IERC20(wrappedNativeSmartFarmooor).safeTransfer(msg.sender, iou);
        emit DepositNative(msg.sender, msg.value);
    }

    /** admin */

    /**
    * @notice  Rescue ERC20 tokens
    */
    function rescueToken(address token) external onlyOwner {
        _rescueToken(token);
    }

    /**
    * @notice  Rescue native tokens
    */
    function rescueNative() external onlyOwner {
        _rescueNative();
    }

    /** fallback */

    /**
     * @dev Only wrapped native token contract is allowed to transfer native token here
     */
    receive() external payable {
        require(msg.sender == wrappedNativeToken, "NativeGateway: unauthorised native transfer");
    }
}